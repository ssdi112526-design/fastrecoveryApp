import 'dart:convert';
import 'package:fastrecovery/Screen/Banker_page.dart' hide AppColors;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../Model_class/Proffile_model.dart';
import '../../theme/app_theme.dart';
import '../Auth/Login/Login_page.dart';
import '../Service/Location_tracking_permission.dart';
import '../Service/SharedPreferenceService.dart';
import '../main.dart';
import 'Find_vehicle.dart';
import 'ID_card.dart';
import 'Profile_page.dart';
import 'Setting_page.dart';
import 'Total_Seized.dart';

class AgencyDashboardPage extends StatefulWidget {
  const AgencyDashboardPage({super.key});

  @override
  State<AgencyDashboardPage> createState() => _AgencyDashboardPageState();
}

class _AgencyDashboardPageState extends State<AgencyDashboardPage>
    with SingleTickerProviderStateMixin {
  static const String _baseUrl = 'https://www.fastrecovery.in';
  static const String _kProfileCache = 'dashboard_profile_cache';

  bool _loading = true;
  bool _userDataLoading = true;

  // Profile/company data — same typed model jo Profile screen use karti hai.
  UserModel? _user;

  String _companyName = 'Company';
  String _location = '';
  List<String> _phones = [];
  String _displayPhone = '';

  // Local values
  String _syncCode = '----';
  String _agencyTag = '';
  int _remainingDays = 0;
  int _offlineRecords = 0;

  int _drawerIndex = 0;

  // API stats (future use, abhi screen par nahi dikh rahe)
  int _totalCases = 0;
  int _todayActivity = 0;
  int _pendingConfirmations = 0;
  int _inventoryConfirmed = 0;
  int _totalConfirmations = 0;
  int _confirmedConfirmations = 0;

  late final AnimationController _pageAnimationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  // =========================================================
  // LIFECYCLE
  // =========================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocationTrackingService.instance.start(context);
    });

    _pageAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _pageAnimationController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(_fadeAnimation);

    _pageAnimationController.forward(); // turant, API ka wait nahi
    _loadDashboardData();
  }

  @override
  void dispose() {
    _pageAnimationController.dispose();
    super.dispose();
  }

  // =========================================================
  // LOGOUT + SETTINGS
  // =========================================================

  Future<void> _logout(BuildContext context) async {
    await LocationTrackingService.instance.stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // saara saved data clear (token, role, name, etc.)

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

  // =========================================================
  // SMALL HELPERS
  // =========================================================

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

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> toggleTheme(bool isDark) async {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

    await SharedPreferenceService.setString(
      'theme_mode',
      isDark ? 'dark' : 'light',
    );
  }

  // =========================================================
  // PROFILE API — Profile screen wala hi endpoint / model
  //
  // GET /api/auth/profile  ->  ProfileResponse -> UserModel
  // =========================================================

  void _applyUser(UserModel? user) {
    _user = user;
    _userDataLoading = false;
    _companyName = _extractCompanyName(user);
    _phones = _extractPhones(user);
    _displayPhone = _phones.join('  •  ');
    _location = _extractLocation(user);
  }

  Future<void> _loadDashboardData() async {
    final prefs = await SharedPreferences.getInstance();

    // 1) Local data + saved profile turant dikhao
    UserModel? cached;
    final raw = prefs.getString(_kProfileCache);
    if (raw != null) {
      try {
        cached = ProfileResponse.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        ).user;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _remainingDays = prefs.getInt('remainingDays') ?? 0;
        _offlineRecords = prefs.getInt('offlineRecords') ?? 0;
        _syncCode = prefs.getString('syncCode') ?? '----';
        _agencyTag = prefs.getString('agencyTag') ?? '';

        if (cached != null) {
          _applyUser(cached);
          _loading = false;
        } else {
          _loading = true;
        }
      });
    }

    // 2) Profile API, background mein refresh
    try {
      final token = prefs.getString('token');
      if (token == null || token.trim().isEmpty) {
        throw Exception('Authentication token not found');
      }

      final user = await _getProfile(
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token.trim()}',
        },
        prefs,
      );

      if (!mounted) return;
      setState(() {
        _applyUser(user);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Agency dashboard error: $e');
      if (!mounted) return;

      setState(() => _loading = false);

      // Saved data pehle se dikh raha ho to error mat dikhao
      if (cached == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('Session expired')
                  ? 'Session expired. Please login again.'
                  : 'Unable to load dashboard data.',
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      }
    }
  }

  Future<UserModel?> _getProfile(
      Map<String, String> headers,
      SharedPreferences prefs,
      ) async {
    final response = await http
        .get(Uri.parse('$_baseUrl/api/auth/profile'), headers: headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Profile API failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    final profileResponse = ProfileResponse.fromJson(map);

    if (!profileResponse.success) {
      throw Exception('Profile API returned success=false');
    }

    // Agli baar turant dikhane ke liye save karo
    await prefs.setString(_kProfileCache, response.body);

    return profileResponse.user;
  }

  // Priority: company.companyName -> user.agencyName -> fallback
  String _extractCompanyName(UserModel? user) {
    final companyName = user?.company?.companyName.trim() ?? '';
    if (companyName.isNotEmpty) return companyName;

    final agencyName = user?.agencyName.trim() ?? '';
    if (agencyName.isNotEmpty) return agencyName;

    return 'Your Agency';
  }

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

  // Priority: user.address -> user.city -> company.address
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
  // STATS APIs (future use)
  // =========================================================

  Future<Map<String, dynamic>> _getStats(
      String path,
      String name,
      Map<String, String> headers,
      ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$path'),
      headers: headers,
    );

    if (response.statusCode == 401) {
      throw Exception('Session expired');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$name API failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);

    if (body['success'] != true) {
      throw Exception('$name API returned success=false');
    }

    return Map<String, dynamic>.from(body['data'] ?? {});
  }

  Future<Map<String, dynamic>> _getOverviewStats(Map<String, String> h) =>
      _getStats('/api/repo-cases/stats/overview', 'Overview', h);

  Future<Map<String, dynamic>> _getPendingConfirmations(
      Map<String, String> h) =>
      _getStats('/api/confirmations/stats/pending-count', 'Pending', h);

  Future<Map<String, dynamic>> _getInventoryConfirmed(Map<String, String> h) =>
      _getStats(
        '/api/confirmations/stats/inventory-confirmed-count',
        'Inventory',
        h,
      );

  Future<Map<String, dynamic>> _getConfirmationCount(Map<String, String> h) =>
      _getStats('/api/confirmations/stats/count', 'Confirmation count', h);

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xff080D18) : const Color(0xffF5F7FB),
      drawer: _buildDrawer(),
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
                    const SizedBox(height: 34),
                    _buildHero(isDark),
                    const SizedBox(height: 26),
                    _buildApiStats(isDark),
                    const SizedBox(height: 16),
                    _buildActionsRow(isDark),
                    const SizedBox(height: 16),
                    _buildControlPanel(isDark),
                    const SizedBox(height: 100),
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
  // DRAWER
  // =========================================================

  Widget _buildDrawer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final background =
    isDark ? const Color(0xff0A1220) : const Color(0xffF8FAFC);
    final primaryText = isDark ? Colors.white : const Color(0xff0F172A);
    final secondaryText =
    isDark ? const Color(0xff8F9DB5) : const Color(0xff64748B);


    final drawerItems = [
      (icon: Icons.dashboard_rounded, title: 'Dashboard', color: Colors.blue, ),
      (icon: Icons.directions_car_filled_rounded, title: 'Find Vehicle', color: Colors.orange, ),
      (icon: Icons.badge_rounded, title: 'ID Card', color: Colors.purple, ),
      (icon: Icons.person_rounded, title: 'Profile', color: Colors.teal,),
      (icon: Icons.car_crash_rounded, title: 'Total Seized Vehicle', color: Colors.red, ),
      (icon: Icons.account_balance_rounded, title: 'Bank / NBFC Repo', color: Colors.indigo, ),
      (icon: Icons.settings_rounded, title: 'Setting', color: Colors.blueGrey,
      ),
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
                  final active = index == _drawerIndex;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: () {
                          setState(() => _drawerIndex = index);
                          Navigator.of(itemContext).pop(); // drawer band

                          switch (item.title) {
                            case 'Profile':
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ProfileScreen(),
                                ),
                              );
                              break;
                            case 'ID Card':
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const IdCardPage(),
                                ),
                              );
                              break;
                            case 'Find Vehicle':
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => HomeScreen()),
                              );

                              case 'Total Seized Vehicle':
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => SeizedSuccessfullyScreen()),
                              );
                              break;

                            case 'Bank / NBFC Repo':
                              final token = SharedPreferenceService.getToken();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => BankRepoListPage(token: token,)),
                            );
                            break;

                            case 'Setting':
                              _openSettings();
                              break;
                            default:
                              break; // Dashboard: already yahin hain
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.blue600
                                .withOpacity(isDark ? .16 : .08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: active
                                  ? AppColors.blue600
                                  .withOpacity(isDark ? .35 : .18)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.blue600.withOpacity(.12)
                                      : (isDark
                                      ? Colors.white.withOpacity(.045)
                                      : const Color(0xffF1F5F9)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  item.icon,
                                  size: 20,
                                  color: active
                                      ? (isDark
                                      ? AppColors.gold400
                                      : AppColors.blue600)
                                      : secondaryText,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: active
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color:
                                    active ? primaryText : secondaryText,
                                  ),
                                ),
                              ),
                              if (active)
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.gold400
                                        : AppColors.blue600,
                                    shape: BoxShape.circle,
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

            // ── BOTTOM: Terms & Conditions, Privacy Policy, App version ──
            const DrawerFooter(),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // TOP BAR
  // =========================================================

  Widget _buildTopBar(bool isDark) {
    final border = isDark ? const Color(0xff263550) : const Color(0xffE5EAF2);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .22 : .045),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // MENU
          Builder(
            builder: (menuContext) {
              return Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Scaffold.of(menuContext).openDrawer(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xffF3F6FA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.menu_rounded,
                      size: 22,
                      color: Colors.black,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 12),

          // LOGO + TITLE
          Expanded(
            child: Row(
              children: [
                Image.asset(
                  'assets/images/fastrecovery_logo-2.png',
                  width: 125,
                  height: 38,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 27, color: Colors.black),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Dashboard',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.2,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // HERO
  // =========================================================

  Widget _buildHero(bool isDark) {
    final cardColor = isDark ? const Color(0xff10182A) : Colors.white;
    final borderColor =
    isDark ? const Color(0xff25314B) : const Color(0xffE5EAF2);
    final mainText = isDark ? Colors.white : const Color(0xff0F172A);
    final mutedText =
    isDark ? const Color(0xff8996AF) : const Color(0xff64748B);

    // Logo photo — pehle company photo, phir user photo.
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
          // Logo — company/user photo, na ho to initials
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
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.blue600,
                        ),
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
                    fit: BoxFit.contain,
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

          // Company name
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
            'Team Leader',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: .3,
              color: mutedText,
            ),
          ),

          // _user login ke turant baad null ho sakta hai -> `!` nahi lagana
          Text(
            _user?.name ?? '',
            key: ValueKey(_user?.name),
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

          if (!_loading && _displayPhone.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.phone_rounded,
                  size: 14,
                  color: AppColors.blue600,
                ),
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
  // =========================================================

  Widget _buildApiStats(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _infoCard(
            isDark: isDark,
            icon: Icons.calendar_month_rounded,
            label: 'Remaining Days',
            subtitle: 'Days',
            value: _loading ? 0 : _remainingDays,
            onTap: () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _infoCard(
            isDark: isDark,
            icon: Icons.cloud_off_rounded,
            label: 'Offline Records',
            subtitle: 'Record',
            value: _loading ? 0 : _offlineRecords,
            onTap: () {},
          ),
        ),
      ],
    );
  }

  // =========================================================
  // CARDS
  // =========================================================

  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xff10182A) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark ? const Color(0xff24304A) : const Color(0xffE5EAF2),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? .23 : .04),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _iconBadge(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.blue600.withOpacity(.11),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: AppColors.blue600, size: 21),
    );
  }

  /// Icon + label + subtitle (+ optional animated number).
  Widget _infoCard({
    required bool isDark,
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    int? value,
    bool center = false,
  }) {
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
          decoration: _cardDecoration(isDark),
          child: Row(
            mainAxisAlignment:
            center ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              _iconBadge(icon),
              SizedBox(width: center ? 10 : 11),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                    ),
                    if (value != null)
                      _AnimatedNumber(
                        value: value,
                        color: textColor,
                        fontSize: 15,
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
  // ACTIONS
  // =========================================================

  Widget _buildActionsRow(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _infoCard(
            isDark: isDark,
            icon: Icons.person_rounded,
            label: 'My Account',
            subtitle: 'Profile',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _infoCard(
            isDark: isDark,
            icon: Icons.directions_car_rounded,
            label: 'V. Confirmed',
            subtitle: 'Vehicles',
            onTap: () {},
          ),
        ),
      ],
    );
  }

  // =========================================================
  // CONTROL PANEL
  // =========================================================

  Widget _buildControlPanel(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _infoCard(
            isDark: isDark,
            icon: Icons.admin_panel_settings_rounded,
            label: 'Control Panel',
            subtitle: 'Manage agency settings',
            center: true,
            onTap: () {},
          ),
        ),
      ],
    );
  }

  // =========================================================
  // PAGE FOOTER
  // =========================================================

  Future<void> _launchUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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

  Widget _buildFooter(bool isDark) {
    final mutedText =
    isDark ? const Color(0xff6B7893) : const Color(0xff94A3B8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Image.asset(
          isDark
              ? 'assets/images/fastrecovery_logo_2dark.png'
              : 'assets/images/fastrecovery_logo-2.png',
          height: 30,
        ),
        Text(
          'Developed By: Software Solutions Development India',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14,
          runSpacing: 4,
          children: [
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
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Copyright © ${DateTime.now().year} SSDI All rights reserved.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: mutedText,
          ),
        ),
      ],
    );
  }
}

// =============================================================
// DRAWER FOOTER (Terms & Conditions, Privacy Policy, App version)
// =============================================================

class DrawerFooter extends StatefulWidget {
  const DrawerFooter({super.key});

  @override
  State<DrawerFooter> createState() => _DrawerFooterState();
}

class _DrawerFooterState extends State<DrawerFooter> {
  static const String _termsUrl = 'https://www.fastrecovery.in/terms';

  // '...' = padh raha hai, '—' = padhne me error aaya (debug console dekho)
  String _version = '...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = 'v${info.version}');
    } catch (e) {
      // Aam wajah: plugin ke baad sirf hot reload kiya, full restart nahi.
      debugPrint('APP VERSION ERROR: $e');
      if (!mounted) return;
      setState(() => _version = '—');
    }
  }

  Future<void> _open(String url) async {
    bool opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }

    if (!opened && mounted) {
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedText =
    isDark ? const Color(0xff6B7893) : const Color(0xff94A3B8);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Divider(
            height: 1,
            thickness: 1.2,
            color: isDark ? const Color(0xff3A4A6B) : const Color(0xffA9B6C8),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _open(_termsUrl),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.open_in_new_rounded,
                    size: 16, color: AppColors.blue600),
                SizedBox(width: 6),
                Text(
                  'Terms & Conditions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blue600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.blue600,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 16),
          child: Text(
            'App Version $_version',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: mutedText,
            ),
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

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          _formatNumber(animatedValue.round()),
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
}

// =============================================================
// SHIMMER CHIP (hero card mein, dashboard load hote waqt)
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
// SHIMMER BOX (drawer header mein)
// =============================================================

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