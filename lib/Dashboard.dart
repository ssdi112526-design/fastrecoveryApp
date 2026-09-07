import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kartikrepoagency/Screen/Profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Model_class/Proffile_model.dart';
import '../theme/app_theme.dart';

class AgencyDashboardPage extends StatefulWidget {
  const AgencyDashboardPage({super.key});

  @override
  State<AgencyDashboardPage> createState() => _AgencyDashboardPageState();
}

class _AgencyDashboardPageState extends State<AgencyDashboardPage>
    with SingleTickerProviderStateMixin {
  static const String _baseUrl = 'https://www.fastrecovery.in';

  bool _loading = true;
  bool _isOnline = true;

  // Dynamic profile/company data — now sourced from UserModel/CompanyModel
  // (the same typed model used on the Profile screen) instead of a raw map.
  UserModel? _user;

  String _companyName = '';
  String _location = '';
  List<String> _phones = [];
  String _displayPhone = '';

  // Existing local values
  String _syncCode = '----';
  String _agencyTag = '';
  int _remainingDays = 0;
  int _offlineRecords = 0;

  // API stats (kept for future use, not shown right now)
  int _totalCases = 0;
  int _todayActivity = 0;
  int _pendingConfirmations = 0;
  int _inventoryConfirmed = 0;
  int _totalConfirmations = 0;
  int _confirmedConfirmations = 0;

  late final AnimationController _pageAnimationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _pageAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _pageAnimationController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pageAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _loadDashboardData();
  }

  @override
  void dispose() {
    _pageAnimationController.dispose();
    super.dispose();
  }

  // =========================================================
  // LOAD ALL DASHBOARD DATA
  // =========================================================

  Future<void> _loadDashboardData() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token');

      if (token == null || token.trim().isEmpty) {
        throw Exception('Authentication token not found');
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${token.trim()}',
      };

      // Local fallback data.
      final remainingDays = prefs.getInt('remainingDays') ?? 0;
      final offlineRecords = prefs.getInt('offlineRecords') ?? 0;
      final syncCode = prefs.getString('syncCode') ?? '----';
      final agencyTag = prefs.getString('agencyTag') ?? '';
      final isOnline = prefs.getBool('isOnline') ?? true;

      // All backend calls.
      final results = await Future.wait([
        _getProfile(headers),
        _getOverviewStats(headers),
        _getPendingConfirmations(headers),
        _getInventoryConfirmed(headers),
        _getConfirmationCount(headers),
      ]);

      final user = results[0] as UserModel?;
      final overview = results[1] as Map<String, dynamic>;
      final pending = results[2] as Map<String, dynamic>;
      final inventory = results[3] as Map<String, dynamic>;
      final confirmationCount = results[4] as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        // -----------------------------------------------------
        // COMPANY / AGENCY NAME — now dynamic from UserModel/CompanyModel
        // -----------------------------------------------------
        _user = user;
        _companyName = _extractCompanyName(user);

        _phones = _extractPhones(user);

        // Agar koi real number nahi hai, ek fallback number generate karo
        _displayPhone =
        _phones.isNotEmpty ? _phones.join('  •  ') : _generateRandomPhone();

        _location = _extractLocation(user);
        _remainingDays = remainingDays;
        _offlineRecords = offlineRecords;
        _syncCode = syncCode;
        _agencyTag = agencyTag;
        _isOnline = isOnline;

        // -----------------------------------------------------
        // API STATS
        // -----------------------------------------------------
        _totalCases = _toInt(overview['cases']);
        _todayActivity = _toInt(overview['todayActivity']);
        _pendingConfirmations = _toInt(pending['pendingConfirmations']);
        _inventoryConfirmed = _toInt(inventory['inventoryConfirmed']);
        _totalConfirmations = _toInt(confirmationCount['totalConfirmations']);
        _confirmedConfirmations =
            _toInt(confirmationCount['confirmedConfirmations']);

        _loading = false;
      });

      _pageAnimationController.forward(from: 0);
    } catch (e) {
      debugPrint('Agency dashboard error: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to load dashboard data.'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }

  // =========================================================
  // SEARCH — opens the premium bottom sheet, which handles its
  // own loading state, fetching and result rendering.
  // =========================================================

  void _searchCases(String query) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xff121A2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return _SearchResultsSheet(
              query: query,
              isDark: isDark,
            );
          },
        );
      },
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================

  String _generateRandomPhone() {
    final random =
        DateTime.now().millisecondsSinceEpoch % 900000000 + 6000000000;
    final digits = random.toString();
    return '+91 ${digits.substring(0, 5)} ${digits.substring(5, 10)}';
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'RA';

    final words =
    trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (words.length == 1) {
      return words[0]
          .substring(0, words[0].length >= 2 ? 2 : 1)
          .toUpperCase();
    }

    return (words[0][0] + words[1][0]).toUpperCase();
  }

  // =========================================================
  // PROFILE API — same endpoint/model used on the Profile screen
  //
  // GET /api/auth/profile  →  ProfileResponse -> UserModel
  // =========================================================

  Future<UserModel?> _getProfile(Map<String, String> headers) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/auth/profile'),
      headers: headers,
    );

    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Profile API failed: ${response.statusCode}');
    }

    dynamic decodedBody;
    try {
      decodedBody = jsonDecode(response.body);
    } catch (_) {
      decodedBody = null;
    }

    final decodedMap =
    decodedBody is Map<String, dynamic> ? decodedBody : <String, dynamic>{};

    final profileResponse = ProfileResponse.fromJson(decodedMap);

    if (!profileResponse.success) {
      throw Exception('Profile API returned success=false');
    }

    return profileResponse.user;
  }

  // =========================================================
  // EXTRACT AGENCY / COMPANY NAME FROM UserModel
  //
  // Priority: company.companyName -> user.agencyName -> fallback
  // =========================================================

  String _extractCompanyName(UserModel? user) {
    final companyName = user?.company?.companyName.trim() ?? '';
    if (companyName.isNotEmpty) return companyName;

    final agencyName = user?.agencyName.trim() ?? '';
    if (agencyName.isNotEmpty) return agencyName;

    return 'Your Agency';
  }

  // =========================================================
  // EXTRACT PHONES FROM UserModel
  // =========================================================

  List<String> _extractPhones(UserModel? user) {
    final phones = <String>[];

    final userPhone = user?.phone.trim() ?? '';
    if (userPhone.isNotEmpty) phones.add(userPhone);

    final secondNumber = user?.secondAgencyNumber.trim() ?? '';
    if (secondNumber.isNotEmpty && secondNumber != userPhone) {
      phones.add(secondNumber);
    }

    final companyPhone = user?.company?.phone.trim() ?? '';
    if (companyPhone.isNotEmpty && !phones.contains(companyPhone)) {
      phones.add(companyPhone);
    }

    return phones;
  }

  // =========================================================
  // EXTRACT LOCATION FROM UserModel
  //
  // Priority: user.address -> user.city -> company.address
  // =========================================================

  String _extractLocation(UserModel? user) {
    final address = user?.address.trim() ?? '';
    if (address.isNotEmpty) return address;

    final city = user?.city.trim() ?? '';
    if (city.isNotEmpty) return city;

    final companyAddress = user?.company?.address.trim() ?? '';
    if (companyAddress.isNotEmpty) return companyAddress;

    return '';
  }

  // =========================================================
  // API 1 — CASE OVERVIEW
  // =========================================================

  Future<Map<String, dynamic>> _getOverviewStats(
      Map<String, String> headers,
      ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/repo-cases/stats/overview'),
      headers: headers,
    );

    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Overview API failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);

    if (body['success'] != true) {
      throw Exception('Overview API returned success=false');
    }

    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  // =========================================================
  // API 2 — PENDING CONFIRMATIONS
  // =========================================================

  Future<Map<String, dynamic>> _getPendingConfirmations(
      Map<String, String> headers,
      ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/confirmations/stats/pending-count'),
      headers: headers,
    );

    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Pending API failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);

    if (body['success'] != true) {
      throw Exception('Pending API returned success=false');
    }

    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  // =========================================================
  // API 3 — INVENTORY CONFIRMED
  // =========================================================

  Future<Map<String, dynamic>> _getInventoryConfirmed(
      Map<String, String> headers,
      ) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/api/confirmations/stats/inventory-confirmed-count',
      ),
      headers: headers,
    );

    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Inventory API failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);

    if (body['success'] != true) {
      throw Exception('Inventory API returned success=false');
    }

    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  // =========================================================
  // API 4 — CONFIRMATION COUNT
  // =========================================================

  Future<Map<String, dynamic>> _getConfirmationCount(
      Map<String, String> headers,
      ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/confirmations/stats/count'),
      headers: headers,
    );

    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Confirmation count API failed: ${response.statusCode}',
      );
    }

    final body = jsonDecode(response.body);

    if (body['success'] != true) {
      throw Exception('Confirmation count API returned success=false');
    }

    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  // =========================================================
  // INTEGER HELPER
  // =========================================================

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  // =========================================================
  // NUMBER FORMAT
  // =========================================================

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xff080D18) : const Color(0xffF5F7FB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: AppColors.blue600,
          backgroundColor: isDark ? const Color(0xff121A2E) : Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopBar(isDark),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildOnlineBadge(isDark),
                    ),
                    const SizedBox(height: 22),
                    _buildHero(isDark),
                    const SizedBox(height: 26),
                    _buildApiStats(isDark),
                    const SizedBox(height: 16),
                    _buildActionsRow(isDark),
                    const SizedBox(height: 16),
                    _buildControlPanel(isDark),
                    const SizedBox(height: 26),
                    _buildFooter(isDark),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // ICON BUTTON
  // =========================================================

  Widget _iconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }

  // =========================================================
  // ONLINE
  // =========================================================

  Widget _buildOnlineBadge(bool isDark) {
    final color =
    _isOnline ? const Color(0xff10B981) : const Color(0xff94A3B8);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withOpacity(.45), blurRadius: 7),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // PREMIUM HERO
  // =========================================================

  Widget _buildHero(bool isDark) {
    final cardColor = isDark ? const Color(0xff10182A) : Colors.white;
    final borderColor =
    isDark ? const Color(0xff25314B) : const Color(0xffE5EAF2);
    final mainText = isDark ? Colors.white : const Color(0xff0F172A);
    final mutedText =
    isDark ? const Color(0xff8996AF) : const Color(0xff64748B);

    // Dynamic logo photo — company photo first, then user photo.
    final companyPhotoUrl = _user?.company?.photoUrl.trim() ?? '';
    final userPhotoUrl = _user?.photoUrl.trim() ?? '';
    final resolvedPhotoUrl =
    companyPhotoUrl.isNotEmpty ? companyPhotoUrl : userPhotoUrl;
    final hasNetworkPhoto = resolvedPhotoUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .30 : .055),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo — dynamic company/user photo, falls back to initials
          TweenAnimationBuilder<double>(
            tween: Tween(begin: .82, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.blueGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.blue600.withOpacity(.24),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cardColor,
                ),
                child: ClipOval(
                  child: _loading
                      ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(
                            AppColors.blue600),
                      ),
                    ),
                  )
                      : hasNetworkPhoto
                      ? Image.network(
                    resolvedPhotoUrl.startsWith('http')
                        ? resolvedPhotoUrl
                        : '$_baseUrl$resolvedPhotoUrl',
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _logoInitials();
                    },
                  )
                      : _logoInitials(),
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Backend company name — dynamic from UserModel/CompanyModel
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _loading
                ? const _ShimmerChip(
              key: ValueKey('loading'),
              width: 210,
              height: 22,
            )
                : Text(
              _companyName.toUpperCase(),
              key: ValueKey(_companyName),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: .35,
                color: mainText,
              ),
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'Agency Account',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: .3,
              color: mutedText,
            ),
          ),

          if (!_loading) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_rounded, size: 14, color: AppColors.blue600),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _displayPhone,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: mutedText,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (_location.isNotEmpty) ...[
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 14,
                  color: AppColors.gold400,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    _location,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: mutedText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _logoInitials() {
    return Center(
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: AppColors.blueGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          _initials(_companyName),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // STATS — Remaining Days & Offline Records
  // (Total Cases / Today Activity / Pending / V. Confirmed
  //  are kept in state but not displayed here right now)
  // =========================================================

  Widget _buildApiStats(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _premiumStatCard(
            isDark: isDark,
            label: 'Remaining Days',
            value: _remainingDays,
            accent: AppColors.blue600,
            icon: Icons.calendar_month_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _premiumStatCard(
            isDark: isDark,
            label: 'Offline Records',
            value: _offlineRecords,
            accent: AppColors.gold400,
            icon: Icons.cloud_off_rounded,
          ),
        ),
      ],
    );
  }

  Widget _premiumStatCard({
    required bool isDark,
    required String label,
    required int value,
    required Color accent,
    required IconData icon,
  }) {
    final bg = isDark ? const Color(0xff10182A) : Colors.white;
    final border = isDark ? const Color(0xff24304A) : const Color(0xffE5EAF2);
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
          Row(
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
              const Spacer(),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: accent.withOpacity(.45), blurRadius: 6),
                  ],
                ),
              ),
            ],
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
          _AnimatedNumber(
            value: _loading ? 0 : value,
            color: valueColor,
            fontSize: 25,
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ACTIONS
  // =========================================================

  Widget _buildActionsRow(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _premiumActionCard(
            isDark: isDark,
            icon: Icons.person_rounded,
            label: 'My Account',
            subtitle: 'Profile',
            color: AppColors.blue600,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _premiumActionCard(
            isDark: isDark,
            icon: Icons.directions_car_rounded,
            label: 'V. Confirmed',
            subtitle: 'Vehicles',
            color: const Color(0xff059669),
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _premiumActionCard({
    required bool isDark,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bg = isDark ? const Color(0xff10182A) : Colors.white;
    final border = isDark ? const Color(0xff24304A) : const Color(0xffE5EAF2);
    final textColor = isDark ? Colors.white : const Color(0xff0F172A);
    final muted = isDark ? const Color(0xff7F8BA4) : const Color(0xff64748B);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? .23 : .04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // CONTROL PANEL
  // =========================================================

  Widget _buildControlPanel(bool isDark) {
    final bg = isDark ? const Color(0xff10182A) : Colors.white;
    final border = isDark ? const Color(0xff24304A) : const Color(0xffE5EAF2);
    final textColor = isDark ? Colors.white : const Color(0xff0F172A);
    final muted = isDark ? const Color(0xff7F8BA4) : const Color(0xff64748B);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(20),
        splashColor: AppColors.gold400.withOpacity(.10),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? .23 : .04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.gold400.withOpacity(.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: AppColors.gold400,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Control Panel',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage agency settings',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: muted),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // FOOTER
  // =========================================================

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open link'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }

  Widget _footerLink({
    required IconData icon,
    required String label,
    required String url,
    required bool isDark,
  }) {
    final textColor =
    isDark ? const Color(0xff9CAAC4) : const Color(0xff64748B);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _launchUrl(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.blue600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // TOP BAR — includes the search icon that opens the sheet
  // =========================================================

  Widget _buildTopBar(bool isDark) {
    final bg = isDark ? const Color(0xff11182A) : Colors.white;
    final border = isDark ? const Color(0xff222D46) : const Color(0xffE5EAF2);
    final textColor = isDark ? Colors.white : const Color(0xff0F172A);

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .28 : .055),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _iconButton(
            icon: Icons.arrow_back_rounded,
            color: textColor,
            onTap: () {
              Navigator.of(context).maybePop();
            },
          ),
          const SizedBox(width: 20),

          Text(
            "Dashboard",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),

          const Spacer(),

          _iconButton(
            icon: Icons.search,
            color: textColor,
            onTap: () async {
              final query = await showDialog<String>(
                context: context,
                builder: (context) {
                  final controller = TextEditingController();
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    backgroundColor:
                    isDark ? const Color(0xff10182A) : Colors.white,
                    title: const Text(
                      "🔍 Premium Search",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    content: TextField(
                      controller: controller,
                      maxLength: 4, // सिर्फ 4 digit
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: "Enter last 4 digits",
                        counterText: "",
                        prefixIcon: Icon(Icons.dialpad),
                      ),
                    ),
                    actions: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () =>
                            Navigator.pop(context, controller.text.trim()),
                        child: const Text("Search"),
                      ),
                    ],
                  );
                },
              );

              if (query != null && query.isNotEmpty && query.length == 4) {
                _searchCases(query);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter 4 digits")),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    final mutedText =
    isDark ? const Color(0xff6B7893) : const Color(0xff94A3B8);
    final brandColor = isDark ? Colors.white : const Color(0xff0F172A);
    final currentYear = DateTime.now().year;

    return Column(
      children: [
        Text(
          'Developed By: Software Solutions Development India',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: mutedText,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 2,
          children: [
            _footerLink(
              icon: Icons.language_rounded,
              label: 'www.ssdi.co.in',
              url: 'https://www.ssdi.co.in/',
              isDark: isDark,
            ),
            _footerLink(
              icon: Icons.call_rounded,
              label: '+91 8796814100',
              url: 'tel:+918796814100',
              isDark: isDark,
            ),
            _footerLink(
              icon: Icons.call_rounded,
              label: '+91 8796824100',
              url: 'tel:+918796824100',
              isDark: isDark,
            ),
            // _footerLink(
            //   icon: Icons.mail_outline_rounded,
            //   label: 'fastrecovery26@gmail.com',
            //   url: 'mailto:fastrecovery26@gmail.com',
            //   isDark: isDark,
            // ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '© $currentYear '
          //'FastRecovery.'
              ' All rights reserved.',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: mutedText,
          ),
        ),
      ],
    );
  }
}

// =============================================================
// ANIMATED NUMBER
// =============================================================

class _AnimatedNumber extends StatelessWidget {
  final int value;
  final Color color;
  final double fontSize;

  const _AnimatedNumber({
    required this.value,
    required this.color,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        final number = animatedValue.round();

        return Text(
          _formatNumber(number),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -.4,
            color: color,
          ),
        );
      },
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }
}

// =============================================================
// SHIMMER CHIP (used inside the hero card while dashboard loads)
// =============================================================

class _ShimmerChip extends StatefulWidget {
  final double width;
  final double height;

  const _ShimmerChip({
    required this.width,
    required this.height,
    super.key,
  });

  @override
  State<_ShimmerChip> createState() => _ShimmerChipState();
}

class _ShimmerChipState extends State<_ShimmerChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white : Colors.black;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: base.withOpacity(.05 + (_controller.value * .07)),
            borderRadius: BorderRadius.circular(7),
          ),
        );
      },
    );
  }
}

// =============================================================
// SEARCH RESULTS BOTTOM SHEET
//
// Self-contained: fetches data, shows a shimmer skeleton grid
// while loading, then a premium grid of result cards sorted
// A → Z by customer name. Tapping a card opens a details popup.
// =============================================================

class _SearchResultsSheet extends StatefulWidget {
  final String query;
  final bool isDark;

  const _SearchResultsSheet({
    required this.query,
    required this.isDark,
  });

  @override
  State<_SearchResultsSheet> createState() => _SearchResultsSheetState();
}

class _SearchResultsSheetState extends State<_SearchResultsSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${token ?? ''}',
      };

      final url = Uri.parse(
        'https://www.fastrecovery.in/api/repo-cases?search=${widget
            .query}&type=vehicleNumber&page=1&limit=50',
      );

      final response = await http.get(url, headers: headers);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = (data['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        setState(() {
          _items = items;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Search sheet error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openDetails(Map<String, dynamic> item) {
    Navigator.of(context).pop(); // close sheet first
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(.55),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 30),
          child: _VehicleDetailsPopupMini(item: item),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    // A → Z sort by customerName (empty/null names go to the end)
    final sorted = List<Map<String, dynamic>>.from(_items)
      ..sort((a, b) {
        final nameA = (a['customerName']?.toString().trim() ?? '');
        final nameB = (b['customerName']?.toString().trim() ?? '');
        if (nameA.isEmpty && nameB.isEmpty) return 0;
        if (nameA.isEmpty) return 1;
        if (nameB.isEmpty) return -1;
        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Row(
            children: [
              Icon(Icons.search_rounded, size: 18, color: AppColors.blue600),
              const SizedBox(width: 8),
              Text(
                _loading
                    ? 'SEARCHING...'
                    : '${sorted.length} MATCH${sorted.length == 1
                    ? ''
                    : 'ES'} FOUND  •  A–Z',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                  color: isDark ? Colors.white54 : const Color(0xff64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? _buildSkeletonGrid(isDark)
                : sorted.isEmpty
                ? _buildEmpty(isDark)
                : GridView.builder(
              itemCount: sorted.length,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.86,
              ),
              itemBuilder: (context, index) {
                final item = sorted[index];

                final vehicleNumber =
                item['vehicleNumber']?.toString().trim();
                final chassisNumber =
                item['chassisNumber']?.toString().trim();
                final customerName =
                item['customerName']?.toString().trim();
                final bankName = item['bankName']?.toString().trim();
                final status = item['repoStatus']?.toString().trim();

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: sorted.map((item) {
                    final vehicleNumber =
                        item['vehicleNumber']?.toString().trim() ?? '';

                    final chassisNumber =
                        item['chassisNumber']?.toString().trim() ?? '';

                    final number = vehicleNumber.isNotEmpty
                        ? vehicleNumber
                        : chassisNumber.isNotEmpty
                        ? chassisNumber
                        : '—';

                    return _resultCard(
                      isDark: isDark,
                      number: number,
                      onTap: () => _openDetails(item),
                    );
                  }).toList(),
                );

              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 40, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 10),
          Text(
            'No matches found',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : const Color(0xff64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid(bool isDark) {
    return GridView.builder(
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.86,
      ),
      itemBuilder: (context, index) => _SkeletonMiniCard(isDark: isDark),
    );
  }

  Widget _resultCard({
    required bool isDark,
    required String number,
    required VoidCallback onTap,
  }) {
    final bg = isDark ? const Color(0xff151F32) : Colors.white;
    final border =
    isDark ? const Color(0xff273449) : const Color(0xffE5EAF2);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                number,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blue600,
                  letterSpacing: .3,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: isDark
                    ? Colors.white38
                    : const Color(0xff94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// =============================================================
// SKELETON MINI CARD — used inside the search bottom sheet
// while results are loading.
// =============================================================

class _SkeletonMiniCard extends StatefulWidget {
  final bool isDark;
  const _SkeletonMiniCard({required this.isDark});

  @override
  State<_SkeletonMiniCard> createState() => _SkeletonMiniCardState();
}

class _SkeletonMiniCardState extends State<_SkeletonMiniCard>
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
    final isDark = widget.isDark;
    final base = isDark ? const Color(0xff151F32) : Colors.white;
    final border = isDark ? const Color(0xff273449) : const Color(0xffE9EEF4);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
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
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white12
                            : const Color(0xffE9EEF4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 44,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white12
                            : const Color(0xffE9EEF4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: 90,
                  height: 12,
                  decoration: BoxDecoration(
                    color:
                    isDark ? Colors.white12 : const Color(0xffE9EEF4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 60,
                  height: 12,
                  decoration: BoxDecoration(
                    color:
                    isDark ? Colors.white12 : const Color(0xffE9EEF4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const Spacer(),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================
// MINI VEHICLE DETAILS POPUP — opened from a search result card.
// =============================================================

class _VehicleDetailsPopupMini extends StatelessWidget {
  final Map<String, dynamic> item;
  const _VehicleDetailsPopupMini({required this.item});

  String _value(String key) {
    final value = item[key];
    if (value == null) return '-';
    final text = value.toString();
    if (text.isEmpty || text == 'null') return '-';
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * .94,
      constraints:
      BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .8),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(24),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_value('vehicleNumber'),
                style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(_value('customerName'),
                style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const Divider(height: 24),
            _row('Chassis', _value('chassisNumber')),
            _row('Bank', _value('bankName')),
            _row('Loan Account', _value('loanAccountNumber')),
            _row('Status', _value('repoStatus')),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.black54)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}