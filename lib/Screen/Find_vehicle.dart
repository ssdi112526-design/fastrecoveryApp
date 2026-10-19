import 'dart:async';
import 'dart:convert';
import 'package:fastrecovery/Screen/Setting_page/Setting_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login/login_page.dart';
import '../Model_class/profile_model.dart';
import '../Model_class/vehicle_detail_model.dart';
import '../Service/Location_tracking_permission.dart';
import '../Service/Offline_sync_service.dart';
import '../Widget/Offline_sync_card.dart';
import '../db_helper/Offline_DB_helper.dart';
import '../theme/app_theme.dart';
import 'dashboard.dart';
import 'ID_card.dart';
import 'Profile_page.dart';
import 'Total_Seized.dart';
import 'Vehicle_Details.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ============================================================
  // CONSTANTS
  // ============================================================
  static const String _baseUrl = 'https://www.fastrecovery.in';
  static const String _searchUrl = '$_baseUrl/api/repo-cases';
  static const String _profileUrl = '$_baseUrl/api/Auth/profile';
  static const String _loginUrl = '$_baseUrl/api/Auth/login';
  static const String _verifyPanelUrl =
      '$_baseUrl/api/repo-admin/verify-agent-panel';

  // Dashboard ek baar unlock hone ke baad true. Logout par prefs.clear() isse hata deta hai.
  static const String _kDashboardUnlocked = 'dashboard_unlocked';

  static const String _typeVehicle = 'vehicleNumber';
  static const String _typeChassis = 'chassisNumber';

  static const int _vehicleDigits = 4;
  static const int _chassisDigits = 6;
  static const int _pageLimit = 500;

  // ============================================================
  // STATE
  // ============================================================
  final _vehicleController = TextEditingController();
  final _chassisController = TextEditingController();
  final _vehicleFocus = FocusNode();
  final _chassisFocus = FocusNode();
  final _scrollController = ScrollController();

  Timer? _debounce;

  // User / company
  String _userName = 'User';
  String _userPhone = '';
  String _userId = '';
  String _userEmail = '';
  String _companyName = 'Company';
  String _companyCode = '';
  bool _userDataLoading = true;

  // Dashboard stats
  bool _statsLoading = true;
  int _companyTotalRecords = 0;
  int _pendingConfirmations = 0;
  int _confirmedConfirmations = 0;
  int _inventoryConfirmed = 0;

  // Search + pagination
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _lastSearchType;
  String _lastSearchValue = '';
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // ============================================================
  // LIFECYCLE
  // ============================================================
  @override
  void initState() {
    super.initState();

    _vehicleController.addListener(_onVehicleChanged);
    _chassisController.addListener(_onChassisChanged);

    // Rebuild on focus change so the field border updates live.
    _vehicleFocus.addListener(() => setState(() {}));
    _chassisFocus.addListener(() => setState(() {}));

    _scrollController.addListener(_onScroll);

    _loadDashboardStats();
    _loadUserData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _vehicleController.dispose();
    _chassisController.dispose();
    _vehicleFocus.dispose();
    _chassisFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Page ke end tak scroll hone par agla page load karo.
  void _onScroll() {
    if (!_hasSearched || _isLoadingMore || !_hasMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 250) {
      _loadMoreResults();
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return (token != null && token.isNotEmpty) ? token : null;
  }

  Future<Map<String, String>> _buildHeaders() async {
    final token = await _getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 95),
          backgroundColor:
          isError ? const Color(0xff991B1B) : const Color(0xff0F3D68),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isError
                      ? Icons.search_off_rounded
                      : Icons.hourglass_top_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _logout(BuildContext context) async {
    await LocationTrackingService.instance.stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // saara saved data clear (token, role, name, unlock flag, etc.)
    await OfflineSyncService.instance.reset(); // DB + cursor saaf

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPage(onLogout: () => _logout(context)),
      ),
    );
  }

  void _handleUnauthorized() {
    if (!mounted) return;
    setState(() {
      _isSearching = false;
      _isLoadingMore = false;
    });
    _showMessage('Session expired. Please login again.');
  }

  // ============================================================
  // DASHBOARD LOCK (password ek baar)
  // ============================================================

  /// Dashboard kholo. Pehli baar login password maango, uske baad seedha khulega.
  Future<void> _openDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    var unlocked = prefs.getBool(_kDashboardUnlocked) ?? false;

    if (!unlocked) {
      if (!mounted) return;
      unlocked = await _askDashboardPassword();
      if (unlocked) await prefs.setBool(_kDashboardUnlocked, true);
    }

    if (!unlocked || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AgencyDashboardPage()),
    );
  }

  Future<bool> _askDashboardPassword() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DashboardPasswordDialog(onVerify: _verifyPassword),
    );
    return ok == true;
  }

  /// login API se password check karta hai (response ka token use nahi karte).
  /// Agent panel unlock API se password verify karta hai.
  Future<_VerifyResult> _verifyPassword(String password) async {
    try {
      final headers = await _buildHeaders(); // Bearer token ke saath

      final res = await http
          .post(
        Uri.parse(_verifyPanelUrl),
        headers: headers,
        body: jsonEncode({'password': password}),
      )
          .timeout(const Duration(seconds: 15));

      debugPrint('VERIFY PANEL -> ${res.statusCode} | ${res.body}');

      dynamic body;
      try {
        body = jsonDecode(res.body);
      } catch (_) {}

      final serverMsg =
      body is Map ? (body['message'] ?? body['error'])?.toString() : null;
      final is2xx = res.statusCode >= 200 && res.statusCode < 300;

      if (is2xx && body is Map && body['success'] == true) {
        return const _VerifyResult.ok();
      }

      if (res.statusCode == 401) {
        // 401 = ya to token expire ya password galat; message server se aayega
        return _VerifyResult.fail(serverMsg ?? 'Incorrect password');
      }
      if (res.statusCode == 403) {
        return _VerifyResult.fail(serverMsg ?? 'Incorrect password');
      }
      return _VerifyResult.fail(
        serverMsg ?? 'Verification failed (${res.statusCode})',
      );
    } on TimeoutException {
      return const _VerifyResult.fail('Request timed out. Please try again.');
    }
    // baaki network errors dialog ka catch handle kar leta hai
  }

  // ============================================================
  // USER / COMPANY
  // ============================================================

  /// Profile response se raw user map nikalta hai (model ke field names par depend nahi).
  Map<String, dynamic> _rawUserMap(dynamic decoded) {
    if (decoded is! Map) return {};
    final data = decoded['data'];
    final candidates = [
      decoded['user'],
      if (data is Map) data['user'],
      data,
    ];
    for (final c in candidates) {
      if (c is Map) return Map<String, dynamic>.from(c);
    }
    return {};
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _userDataLoading = true);

    final prefs = await SharedPreferences.getInstance();

    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token — using cached values');

      final response = await http.get(
        Uri.parse(_profileUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      final profile = ProfileResponse.fromJson(
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{},
      );

      if (response.statusCode != 200 || !profile.success) {
        throw Exception('Profile API failed: ${response.statusCode}');
      }

      final user = profile.user;
      final name = (user?.name.trim().isNotEmpty ?? false)
          ? user!.name.trim()
          : 'User';
      final companyName = _extractCompanyName(user);
      final companyCode = user?.company?.companyCode.trim() ?? '';
      final phone = user?.phone.trim() ?? '';

      final rawUser = _rawUserMap(decoded);
      final userId =
          '${rawUser['id'] ?? rawUser['_id'] ?? rawUser['userId'] ?? ''}';
      final email = '${rawUser['email'] ?? ''}'.trim();

      if (!mounted) return;
      setState(() {
        _userName = name;
        _companyName = companyName;
        _companyCode = companyCode;
        _userPhone = phone;
        _userId = userId;
        _userEmail = email;
        _userDataLoading = false;
      });

      await prefs.setString('userName', name);
      await prefs.setString('companyName', companyName);
      await prefs.setString('companyCode', companyCode);
      await prefs.setString('userPhone', phone);
      await prefs.setString('userId', userId);
      await prefs.setString('userEmail', email);
    } catch (e) {
      debugPrint('LOAD USER DATA — falling back to cache: $e');
      if (!mounted) return;

      String cached(String key, String fallback) {
        final v = prefs.getString(key);
        return (v != null && v.trim().isNotEmpty) ? v : fallback;
      }

      setState(() {
        _userName = cached('userName', 'User');
        _companyName = cached('companyName', 'Your Agency');
        _companyCode = prefs.getString('companyCode') ?? '';
        _userPhone = prefs.getString('userPhone') ?? '';
        _userId = prefs.getString('userId') ?? '';
        _userEmail = prefs.getString('userEmail') ?? '';
        _userDataLoading = false;
      });
    }
  }

  String _extractCompanyName(UserModel? user) {
    final companyName = user?.company?.companyName.trim() ?? '';
    if (companyName.isNotEmpty) return companyName;

    final agencyName = user?.agencyName.trim() ?? '';
    if (agencyName.isNotEmpty) return agencyName;

    return 'Your Agency';
  }

  // ============================================================
  // DASHBOARD STATS
  // ============================================================

  /// Ek stats endpoint call karta hai. Fail hone par null return karta hai,
  /// baaki APIs par koi asar nahi padta.
  Future<Map<String, dynamic>?> _fetchStat(
      String path,
      Map<String, String> headers,
      ) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl$path'), headers: headers)
          .timeout(const Duration(seconds: 20));

      debugPrint('[STATS] $path -> ${res.statusCode} | ${res.body}');

      if (res.statusCode == 401) {
        _handleUnauthorized();
        return null;
      }
      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final body = jsonDecode(res.body);
      if (body is Map && body['success'] == true && body['data'] is Map) {
        return Map<String, dynamic>.from(body['data'] as Map);
      }
    } catch (e) {
      debugPrint('[STATS] $path ERROR: $e');
    }
    return null;
  }

  Future<void> _loadDashboardStats() async {
    if (!mounted) return;
    setState(() => _statsLoading = true);

    final token = await _getToken();
    if (token == null) {
      if (mounted) setState(() => _statsLoading = false);
      return;
    }

    final headers = await _buildHeaders();

    final results = await Future.wait([
      _fetchStat('/api/confirmations/stats/pending-count', headers),
      _fetchStat('/api/confirmations/stats/inventory-confirmed-count', headers),
      _fetchStat('/api/repo-cases/stats/linked-upload-agencies', headers),
      _fetchStat('/api/confirmations/stats/count', headers),
    ]);

    final pending = results[0];
    final inventory = results[1];
    final company = results[2];
    final confCount = results[3];

    final companyInfo = company?['company'] is Map
        ? Map<String, dynamic>.from(company!['company'] as Map)
        : <String, dynamic>{};

    if (!mounted) return;
    setState(() {
      _pendingConfirmations = _toInt(pending?['pendingConfirmations']);
      _inventoryConfirmed = _toInt(inventory?['inventoryConfirmed']);
      _confirmedConfirmations = _toInt(confCount?['confirmedConfirmations']);
      _companyTotalRecords = _toInt(
        company?['companyTotalRecords'] ?? companyInfo['totalRecords'],
      );
      _statsLoading = false;
    });

    OfflineSyncService.instance.totalEstimate = _companyTotalRecords;
  }

  // ============================================================
  // INPUT HANDLING
  // ============================================================
  void _onVehicleChanged() =>
      _handleInput(_vehicleController, _vehicleDigits, _typeVehicle);

  void _onChassisChanged() =>
      _handleInput(_chassisController, _chassisDigits, _typeChassis);

  void _handleInput(
      TextEditingController controller,
      int requiredLength,
      String type,
      ) {
    final value = controller.text.trim();
    _debounce?.cancel();

    if (value.isEmpty) {
      if (mounted) setState(_resetSearchState);
      return;
    }

    if (value.length == requiredLength) {
      _debounce = Timer(
        const Duration(milliseconds: 350),
            () => _search(type, value),
      );
    }
  }

  void _resetSearchState() {
    _searchResults = [];
    _hasSearched = false;
    _isSearching = false;
    _lastSearchType = null;
    _lastSearchValue = '';
    _currentPage = 1;
    _hasMore = true;
    _isLoadingMore = false;
  }

  /// Search complete hone ke baad field clear karo, bina listener trigger kiye.
  void _silentlyClear(TextEditingController controller, VoidCallback listener) {
    controller.removeListener(listener);
    controller.clear();
    controller.addListener(listener);
  }

  void _clearSearch({
    required TextEditingController controller,
    required FocusNode focusNode,
  }) {
    _debounce?.cancel();
    if (controller.text.isNotEmpty) controller.clear();

    if (!mounted) return;
    setState(_resetSearchState);
    FocusScope.of(context).requestFocus(focusNode);
  }

  void _openVehicleDetails(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleDetailsPopup(
          item: VehicleItem.fromJson(item),
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH (vehicle + chassis share one implementation)
  // ============================================================
  Future<http.Response> _fetchPage(String type, String value, int page) async {
    final uri = Uri.parse(_searchUrl).replace(
      queryParameters: {
        'search': value,
        'type': type,
        'page': '$page',
        'limit': '$_pageLimit',
      },
    );

    debugPrint('SEARCH -> type=$type value=$value page=$page url=$uri');

    final headers = await _buildHeaders();
    return http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 30));
  }

  Future<void> _search(String type, String value) async {
    if (!mounted) return;

    final isVehicle = type == _typeVehicle;
    final label = isVehicle ? 'vehicle' : 'chassis';

    _debounce?.cancel();
    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
      _searchResults = [];
      _hasSearched = true;
      _lastSearchType = type;
      _lastSearchValue = value;
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      final sync = OfflineSyncService.instance;
      if (sync.useOffline) {
        await _searchOffline(type, value);
        return;
      }
      final response = await _fetchPage(type, value, 1);
      debugPrint('STATUS: ${response.statusCode}');

      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (e) {
        debugPrint('JSON ERROR: $e');
        _showMessage('Invalid response from server');
        return;
      }

      if (response.statusCode == 401) {
        _handleUnauthorized();
        return;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = (body is Map && body['message'] != null)
            ? body['message'].toString()
            : 'Search failed';
        _showMessage(message);
        return;
      }

      final results = _extractResults(body);
      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _hasMore = results.length >= _pageLimit;
      });

      if (results.isEmpty) {
        final masked = '*' * (isVehicle ? _vehicleDigits : _chassisDigits);
        _showMessage('No $label records found for $masked$value');
      }

      if (isVehicle) {
        _silentlyClear(_vehicleController, _onVehicleChanged);
      } else {
        _silentlyClear(_chassisController, _onChassisChanged);
      }
    } on TimeoutException {
      _showMessage('Search is taking too long. Please try again.');
    } catch (e, stack) {
      debugPrint('SEARCH ERROR: $e\n$stack');
      _showMessage('Unable to search $label right now');

    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _searchOffline(String type, String value) async {
    final isVehicle = type == _typeVehicle;
    final label = isVehicle ? 'vehicle' : 'chassis';
    final sync = OfflineSyncService.instance;

    try {
      final results = await OfflineDb.instance
          .search(isVehicle: isVehicle, digits: value);
      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _hasMore = false; // local mein pagination nahi
      });
      if (results.isEmpty) {
        final masked = '*' * (isVehicle ? _vehicleDigits : _chassisDigits);
        _showMessage(
          sync.hasData
              ? 'No $label records found for $masked$value (offline)'
              : 'Offline data not downloaded yet. Connect to internet and sync once.',
        );
      }
      if (isVehicle) {
        _silentlyClear(_vehicleController, _onVehicleChanged);
      } else {
        _silentlyClear(_chassisController, _onChassisChanged);
      }
    } catch (e) {
      debugPrint('OFFLINE SEARCH ERROR: $e');
      _showMessage('Unable to search offline data');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ============================================================
  // LOAD MORE (PAGINATION)
  // ============================================================
  Future<void> _loadMoreResults() async {
    if (!_hasMore || _isLoadingMore) return;
    if (_lastSearchType == null || _lastSearchValue.isEmpty) return;

    setState(() => _isLoadingMore = true);
    final nextPage = _currentPage + 1;

    try {
      final response =
      await _fetchPage(_lastSearchType!, _lastSearchValue, nextPage);

      if (response.statusCode == 401) {
        _handleUnauthorized();
        return;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (mounted) setState(() => _hasMore = false);
        return;
      }

      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        if (mounted) setState(() => _hasMore = false);
        return;
      }

      final results = _extractResults(body);
      if (!mounted) return;

      setState(() {
        _currentPage = nextPage;
        _searchResults.addAll(results);
        _hasMore = results.length >= _pageLimit;
      });
    } catch (e) {
      debugPrint('LOAD MORE ERROR: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  List<Map<String, dynamic>> _extractResults(dynamic body) {

    if (body is! Map) return [];

    const keys = ['items', 'data', 'results', 'cases', 'records'];
    for (final key in keys) {
      final value = body[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return [];
  }

  /// Result item par woh number dikhao jo user ne search kiya (vehicle ya chassis).
  String _displayNumberFor(Map<String, dynamic> item) {
    final value = item[_lastSearchType ?? _typeVehicle]?.toString().trim();
    return (value != null && value.isNotEmpty) ? value : '—';
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xff0B1220) : AppColors.paper,
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Transform.translate(
              offset: const Offset(0, -26),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _buildFindCard(),
              ),
            ),
            // OfflineBanner(),
            Transform.translate(
              offset: const Offset(0, -10),
              child: _isSearching
                  ? _buildSkeletonGrid()
                  : _hasSearched
                  ? _buildSearchResults()
                  : Column(
                children: [
                  const SizedBox(height: 12),
                  const OfflineSyncCard(),
                  _buildStatsCards(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DRAWER
  // ============================================================

  Widget _buildDrawer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final background =
    isDark ? const Color(0xff0A1220) : const Color(0xffF8FAFC);
    final primaryText = isDark ? Colors.white : const Color(0xff0F172A);
    final secondaryText =
    isDark ? const Color(0xff8F9DB5) : const Color(0xff64748B);

    // Find Vehicle yahi screen hai, isliye menu mein nahi.

    final drawerItems = [
      (icon: Icons.dashboard_rounded, title: 'Dashboard'),
      (icon: Icons.badge_rounded, title: 'ID Card'),
      (icon: Icons.person_rounded, title: 'Profile'),
      // (icon: Icons.car_crash_rounded, title: 'Total Seized Vehicle'),
      (icon: Icons.settings_rounded, title: 'Setting'),
    ];

    return Drawer(
      width: 292,
      backgroundColor: background,
      elevation: 20,
      child: SafeArea(
        child: Column(
          children: [
            // ── HEADER ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xff13294B), const Color(0xff0E1A31)]
                        : [const Color(0xffEEF5FF), Colors.white],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(.08)
                        : const Color(0xffDDE7F3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.blueGradient,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.blue600.withOpacity(.25),
                            blurRadius: 14,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.business_center_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _userDataLoading
                          ? const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ShimmerBox(width: 130, height: 13),
                          SizedBox(height: 7),
                          _ShimmerBox(width: 80, height: 10),
                        ],
                      )
                          : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _companyName.isNotEmpty
                                ? _companyName
                                : 'Your Agency',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Agency Workspace',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── MENU TITLE ──
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 9),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MAIN MENU',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: secondaryText,
                  ),
                ),
              ),
            ),

            // ── MENU ITEMS ──
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: drawerItems.length,
                itemBuilder: (itemContext, index) {
                  final item = drawerItems[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: () {
                          Navigator.of(itemContext).pop(); // drawer band

                          switch (item.title) {
                            case 'Dashboard':
                              _openDashboard(); // pehli baar password, phir seedha
                              break;
                            case 'ID Card':
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const IdCardPage(),
                                ),
                              );
                              break;
                            case 'Profile':
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ProfileScreen(),
                                ),
                              );
                              break;
                            case 'Total Seized Vehicle':
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SeizedSuccessfullyScreen(),
                                ),
                              );
                              break;
                            case 'Setting':
                              _openSettings();
                              break;
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(.045)
                                      : const Color(0xffF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  item.icon,
                                  size: 20,
                                  color: secondaryText,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: secondaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── BOTTOM: Terms & Conditions, App version ──
            const DrawerFooter(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18, MediaQuery.of(context).padding.top + 16, 22, 50,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Builder(
                builder: (menuContext) => GestureDetector(
                  onTap: () => Scaffold.of(menuContext).openDrawer(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.menu_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: _userDataLoading
                    ? const _ShimmerBox(width: 140, height: 14)
                    : RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.white.withOpacity(.72),
                      fontSize: 12,
                    ),
                    children: [
                      const TextSpan(text: 'Welcome,\n'),
                      TextSpan(
                        text: _companyName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_userDataLoading)
                const _ShimmerBox(
                  width: 60,
                  height: 24,
                  radius: BorderRadius.all(Radius.circular(9)),
                ),
              const SizedBox(width: 8),
              const OfflineModeToggle(),
              // else if (_companyCode.isNotEmpty)
              //   Container(
              //     padding:
              //     const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              //     decoration: BoxDecoration(
              //       color: Colors.white.withOpacity(.15),
              //       borderRadius: BorderRadius.circular(9),
              //     ),
              //     child: Text(
              //       _companyCode,
              //       style: AppTextStyles.mono(
              //         size: 11,
              //         weight: FontWeight.w700,
              //         color: Colors.white,
              //       ),
              //     ),
              //   ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Hi,',
            style: AppTextStyles.body(
              size: 14,
              color: Colors.white.withOpacity(.72),
            ),
          ),
          const SizedBox(height: 4),
          _userDataLoading
              ? const _ShimmerBox(width: 160, height: 26)
              : Text(
            _userName,
            style: AppTextStyles.display(
              size: 25,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              _userDataLoading
                  ? SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.gold400),
                ),
              )
                  : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold400,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                _userDataLoading
                    ? 'Loading your profile...'
                    : 'Search vehicles instantly',
                style: AppTextStyles.mono(
                  size: 11.5,
                  color: Colors.white.withOpacity(.78),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FIND CARD
  // ============================================================
  Widget _buildFindCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff111827) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .30 : .14),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.blue600.withOpacity(.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: AppColors.blue600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find Vehicle',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.navy950,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enter last digits to search automatically',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.white60 : AppColors.slate600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _findField(
                  label: 'Vehicle Number',
                  hint: 'Enter vehicle number',
                  icon: Icons.directions_car_outlined,
                  controller: _vehicleController,
                  focusNode: _vehicleFocus,
                  maxLength: _vehicleDigits,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _findField(
                  label: 'Chassis Number',
                  hint: 'Enter chassis number',
                  icon: Icons.confirmation_number_outlined,
                  controller: _chassisController,
                  focusNode: _chassisFocus,
                  maxLength: _chassisDigits,
                  alphanumeric: true, // ← NEW
                ),
              ),
            ],
          ),
          if (_isSearching) ...[
            const SizedBox(height: 26),
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.blue600.withOpacity(.10),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.blue600.withOpacity(.25)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'Searching records... this may take a moment',
                      style: AppTextStyles.body(
                        size: 12,
                        weight: FontWeight.w600,
                        color: AppColors.blue600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _findField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required FocusNode focusNode,
    required int maxLength,
    bool alphanumeric = false, // ← NEW
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.body(
            size: 10,
            weight: FontWeight.w800,
            color: isDark ? Colors.white60 : AppColors.slate600,
          ).copyWith(letterSpacing: .8),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xff0F172A) : const Color(0xffFCFDFE),
            border: Border.all(
              color: focusNode.hasFocus
                  ? AppColors.blue500
                  : isDark
                  ? const Color(0xff334155)
                  : AppColors.slate200,
              width: 1.4,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isDark ? Colors.white54 : AppColors.slate400,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLength: maxLength,
                  keyboardType: alphanumeric ? TextInputType.visiblePassword : TextInputType.number,
                  inputFormatters: [
                    if (alphanumeric)
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]'))
                    else
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(maxLength),
                  ],
                  textCapitalization: TextCapitalization.characters,
                  style: AppTextStyles.mono(
                    size: 14,
                    weight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.navy950,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTextStyles.body(
                      size: 12.5,
                      color: isDark ? Colors.white38 : AppColors.slate400,
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  if (_statsLoading) {
                    return const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }

                  if (value.text.isEmpty) {
                    return const SizedBox(width: 20, height: 20);
                  }

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _clearSearch(
                        controller: controller,
                        focusNode: focusNode,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: Icon(
                          Icons.close_rounded,
                          size: 19,
                          color: isDark ? Colors.white70 : AppColors.slate600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATS CARDS
  // ============================================================
  Widget _buildStatsCards() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget card(String label, int value, Color accent, IconData icon) =>
        _homeStatCard(
          isDark: isDark,
          label: label,
          value: value,
          accent: accent,
          icon: icon,
        );

    final cards = <Widget>[
      card('Total Records', _companyTotalRecords, AppColors.blue600,
          Icons.inventory_2_rounded),
      card('Pending Confirmations', _pendingConfirmations,
          const Color(0xffF59E0B), Icons.pending_actions_rounded),
      card('Confirmation cases', _confirmedConfirmations, AppColors.gold400,
          Icons.insights_rounded),
      card('Total Seized vehicles', _inventoryConfirmed,
          const Color(0xff059669), Icons.verified_rounded),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          const SizedBox(height: 12),
          ..._pairRows(cards),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  List<Widget> _pairRows(List<Widget> cards) {
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 12));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[i]),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < cards.length ? cards[i + 1] : const SizedBox(),
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  Widget _homeStatCard({
    required bool isDark,
    required String label,
    required int value,
    required Color accent,
    required IconData icon,
  }) {
    final bg = isDark ? const Color(0xff111827) : Colors.white;
    final border = isDark ? const Color(0xff334155) : const Color(0xffE5EAF2);
    final labelColor =
    isDark ? const Color(0xff8A97B0) : const Color(0xff64748B);
    final valueColor = isDark ? Colors.white : const Color(0xff0F172A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .24 : .045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(.11),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 5),
          _statsLoading
              ? const _ShimmerBox(width: 50, height: 22)
              : Text(
            value.toString(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESULTS
  // ============================================================
  Widget _buildSkeletonGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.86,
        ),
        itemBuilder: (context, index) => const _SkeletonResultCard(),
      ),
    );
  }

  /// Result count wala card. Empty hone par red style use hota hai.
  Widget _buildResultSummary({
    required bool isDark,
    required int count,
  }) {
    final isEmpty = count == 0;
    final accent = isEmpty ? Colors.redAccent : AppColors.blue600;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 8, 18, isEmpty ? 0 : 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xff111827) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xff334155) : const Color(0xffE2E8F0),
          ),
          boxShadow: isEmpty
              ? null
              : [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? .20 : .04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withOpacity(.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEmpty ? Icons.search_off_rounded : Icons.search_rounded,
                size: 18,
                color: accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search Results',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : AppColors.slate600,
                    ),
                  ),
                  if (!isEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      count == 1 ? '1 record found' : '$count records found',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : AppColors.slate400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isEmpty)
              Text(
                '0',
                style: AppTextStyles.mono(
                  size: 20,
                  weight: FontWeight.w900,
                  color: Colors.redAccent,
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(minWidth: 44),
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.blue600,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberColumn(
      List<Map<String, dynamic>> items,
      bool isDark,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: items.map((item) {
        return GestureDetector(
          onTap: () => _openVehicleDetails(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(
              _displayNumberFor(item),
              style: AppTextStyles.mono(
                size: 24,
                weight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.slate600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchResults() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resultCount = _searchResults.length;

    if (_searchResults.isEmpty) {
      return Column(
        children: [
          _buildResultSummary(isDark: isDark, count: 0),
          _buildEmptyResults(isDark),
        ],
      );
    }

    // Jis field par search kiya, usi ke prefix + number se sort karo.
    final sortField = _lastSearchType ?? _typeVehicle;
    final prefixRegex = RegExp(r'^[A-Z]+');

    final sorted = List<Map<String, dynamic>>.from(_searchResults)
      ..sort((a, b) {
        final numberA = (a[sortField]?.toString().trim() ?? '').toUpperCase();
        final numberB = (b[sortField]?.toString().trim() ?? '').toUpperCase();

        final prefixA = prefixRegex.firstMatch(numberA)?.group(0) ?? '';
        final prefixB = prefixRegex.firstMatch(numberB)?.group(0) ?? '';

        final prefixCompare = prefixA.compareTo(prefixB);
        return prefixCompare != 0 ? prefixCompare : numberA.compareTo(numberB);
      });

    final half = (sorted.length / 2).ceil();
    final firstColumn = sorted.take(half).toList();
    final secondColumn = sorted.skip(half).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResultSummary(isDark: isDark, count: resultCount),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildNumberColumn(firstColumn, isDark)),
              const SizedBox(width: 20),
              Expanded(child: _buildNumberColumn(secondColumn, isDark)),
            ],
          ),
        ),
        if (_isLoadingMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue600),
                ),
              ),
            ),
          ),
        if (!_hasMore && !_isLoadingMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'End of results',
                style: AppTextStyles.body(
                  size: 11,
                  weight: FontWeight.w600,
                  color: isDark ? Colors.white38 : AppColors.slate400,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyResults(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 40,
            color: isDark ? Colors.white24 : AppColors.slate400,
          ),
          const SizedBox(height: 10),
          Text(
            'No matches found',
            style: AppTextStyles.body(
              size: 13,
              weight: FontWeight.w600,
              color: isDark ? Colors.white54 : AppColors.slate600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DASHBOARD PASSWORD DIALOG
// ============================================================
class _VerifyResult {
  final bool ok;
  final String? message;

  const _VerifyResult.ok()
      : ok = true,
        message = null;

  const _VerifyResult.fail(this.message) : ok = false;
}

class _DashboardPasswordDialog extends StatefulWidget {
  final Future<_VerifyResult> Function(String password) onVerify;

  const _DashboardPasswordDialog({required this.onVerify});

  @override
  State<_DashboardPasswordDialog> createState() =>
      _DashboardPasswordDialogState();
}

class _DashboardPasswordDialogState extends State<_DashboardPasswordDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _controller.text;
    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.onVerify(password);
      if (!mounted) return;
      if (result.ok) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _loading = false;
          _error = result.message ?? 'Incorrect password';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not verify. Check your internet and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xff111827) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xff0F172A);
    final mutedColor =
    isDark ? const Color(0xff8A97B0) : const Color(0xff64748B);
    final fieldBg = isDark ? const Color(0xff0F172A) : const Color(0xffF8FAFC);
    final fieldBorder =
    isDark ? const Color(0xff334155) : const Color(0xffE2E8F0);

    OutlineInputBorder border(Color c, [double w = 1.2]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );

    return Dialog(
      backgroundColor: bg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.blueGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.blue600.withOpacity(.28),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Dashboard Locked',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter your login password to continue.\nYou will be asked only once.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.4, color: mutedColor),
            ),
            const SizedBox(height: 20),

            // Password field
            TextField(
              controller: _controller,
              obscureText: _obscure,
              autofocus: true,
              enabled: !_loading,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              style: TextStyle(
                color: titleColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: TextStyle(color: mutedColor, fontSize: 14),
                filled: true,
                fillColor: fieldBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                prefixIcon: Icon(Icons.lock_outline_rounded, color: mutedColor),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: mutedColor,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                border: border(fieldBorder),
                enabledBorder: border(fieldBorder),
                disabledBorder: border(fieldBorder),
                focusedBorder: border(AppColors.blue600, 1.6),
              ),
            ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(.30)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 22),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed:
                      _loading ? null : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: mutedColor,
                        side: BorderSide(color: fieldBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Opacity(
                    opacity: _loading ? .7 : 1,
                    child: Material(
                      color: Colors.transparent,
                      child: Ink(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: AppColors.blueGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _loading ? null : _submit,
                          child: Center(
                            child: _loading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                                : const Text(
                              'Unlock',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SKELETON CARD
// ============================================================
class _SkeletonResultCard extends StatefulWidget {
  const _SkeletonResultCard();

  @override
  State<_SkeletonResultCard> createState() => _SkeletonResultCardState();
}

class _SkeletonResultCardState extends State<_SkeletonResultCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    final sync = OfflineSyncService.instance;
    sync.init().then((_) {
      // Online hai aur sync pura nahi hua / update chahiye -> auto start
      if (sync.isOnline) sync.start();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xff151F32) : Colors.white;
    final border = isDark ? const Color(0xff273449) : const Color(0xffE9EEF4);
    final barColor = isDark ? Colors.white12 : const Color(0xffE9EEF4);

    Widget bar(double w, double h, double radius) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .30 : .05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return ShaderMask(
            shaderCallback: (bounds) {
              final t = _controller.value;
              return LinearGradient(
                begin: Alignment(-1 + 3 * t, 0),
                end: Alignment(0 + 3 * t, 0),
                colors: isDark
                    ? [
                  Colors.white.withOpacity(.05),
                  Colors.white.withOpacity(.22),
                  Colors.white.withOpacity(.05),
                ]
                    : [
                  Colors.black.withOpacity(.05),
                  Colors.black.withOpacity(.14),
                  Colors.black.withOpacity(.05),
                ],
                stops: const [0.35, 0.5, 0.65],
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    bar(38, 38, 12),
                    const Spacer(),
                    bar(44, 16, 20),
                  ],
                ),
                const SizedBox(height: 14),
                bar(90, 12, 6),
                const SizedBox(height: 8),
                bar(60, 12, 6),
                const SizedBox(height: 12),
                bar(70, 9, 6),
                const Spacer(),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// SHIMMER BOX
// ============================================================
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10 + (_controller.value * 0.14)),
            borderRadius: widget.radius ?? BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}