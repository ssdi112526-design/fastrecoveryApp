import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../Model_class/Proffile_model.dart';
import '../Model_class/vehcial_detail_model.dart';
import '../theme/app_theme.dart';
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
  static const String _profileUrl = '$_baseUrl/api/auth/profile';

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

  void _handleUnauthorized() {
    if (!mounted) return;
    setState(() {
      _isSearching = false;
      _isLoadingMore = false;
    });
    _showMessage('Session expired. Please login again.');
  }

  // ============================================================
  // USER / COMPANY
  // ============================================================
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

      if (!mounted) return;
      setState(() {
        _userName = name;
        _companyName = companyName;
        _companyCode = companyCode;
        _userDataLoading = false;
      });

      await prefs.setString('userName', name);
      await prefs.setString('companyName', companyName);
      await prefs.setString('companyCode', companyCode);
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
            Transform.translate(
              offset: const Offset(0, -10),
              child: _isSearching
                  ? _buildSkeletonGrid()
                  : _hasSearched
                  ? _buildSearchResults()
                  : _buildStatsCards(),
            ),
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
        18,
        MediaQuery.of(context).padding.top + 16,
        22,
        50,
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
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 22,
                    color: Colors.white,
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
                      const TextSpan(text: 'Welcome, '),
                      TextSpan(
                        text: _companyName,
                        style: const TextStyle(
                          color: Colors.white,
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
                )
              else if (_companyCode.isNotEmpty)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    _companyCode,
                    style: AppTextStyles.mono(
                      size: 11,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
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
                  keyboardType: TextInputType.number,
                  inputFormatters: [
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