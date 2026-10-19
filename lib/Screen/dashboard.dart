import 'dart:convert';
import 'package:fastrecovery/Screen/Confimation_cases/update_inventory.dart'hide ConfirmedCases;
import 'package:fastrecovery/Service/SharedPreferenceService.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../Model_class/profile_model.dart';
import '../Service/Location_tracking_permission.dart';
import 'Confimation_cases/ConfirmedCases.dart';
import 'Pending_confirmed.dart';
import 'Total_Seized.dart';

// =============================================================
// AGENCY DASHBOARD
// =============================================================

class AgencyDashboardPage extends StatefulWidget {
  const AgencyDashboardPage({super.key});

  @override
  State<AgencyDashboardPage> createState() => _AgencyDashboardPageState();
}

class _AgencyDashboardPageState extends State<AgencyDashboardPage>
    with SingleTickerProviderStateMixin {
  static const String _baseUrl = 'https://www.fastrecovery.in';
  static const String _kProfileCache = 'dashboard_profile_cache';

  // ── Loading flags ──
  bool _loading = true; // profile
  bool _statsLoading = true; // confirmation stats

  // ── Profile / company ──
  UserModel? _user;
  String _companyName = 'Company';
  String _location = '';
  String _displayPhone = '';

  // ── Local values (SharedPreferences) ──
  int _remainingDays = 0;
  int _offlineRecords = 0;

  // ── API stats ──
  int _pendingConfirmations = 0;
  int _companyTotalRecords =0;
  int _inventoryConfirmed = 0;
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
      if (mounted) LocationTrackingService.instance.start(context);
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
  // HELPERS
  // =========================================================

  String _initials(String name) {
    final words =
    name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (words.isEmpty) return 'RA';
    if (words.length == 1) {
      final w = words[0];
      return w.substring(0, w.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  /// Screen kholo. [refreshOnReturn] true ho to wapas aane par counts reload.
  Future<void> _goTo(Widget page, {bool refreshOnReturn = false}) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (refreshOnReturn && mounted) _loadDashboardData();
  }

  // =========================================================
  // DATA LOADING
  // =========================================================

  void _applyUser(UserModel? user) {
    _user = user;
    _companyName = _extractCompanyName(user);
    _displayPhone = _extractPhones(user).join('  •  ');
    _location = _extractLocation(user);
  }

  Future<void> _loadDashboardData() async {
    final prefs = await SharedPreferences.getInstance();

    // 1) Local values + saved profile turant dikhao
    UserModel? cached;
    final raw = prefs.getString(_kProfileCache);
    if (raw != null) {
      try {
        cached = ProfileResponse.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        ).user;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _remainingDays = prefs.getInt('remainingDays') ?? 0;
      _offlineRecords = prefs.getInt('offlineRecords') ?? 0;

      if (cached != null) {
        _applyUser(cached);
        _loading = false;
      }
    });

    // 2) Token check
    final token = (prefs.getString('token') ?? '').trim();
    if (token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statsLoading = false;
      });
      if (cached == null) _showSnack('Session expired. Please login again.');
      return;
    }

    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    // 3) Profile + stats parallel mein
    await Future.wait([
      _refreshProfile(headers, prefs, hadCache: cached != null),
      _loadStats(headers),
    ]);
  }

  Future<void> _refreshProfile(
      Map<String, String> headers,
      SharedPreferences prefs, {
        required bool hadCache,
      }) async {
    try {
      final user = await _getProfile(headers, prefs);
      if (!mounted) return;
      setState(() {
        _applyUser(user);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Agency dashboard profile error: $e');
      if (!mounted) return;
      setState(() => _loading = false);

      // Saved data pehle se dikh raha ho to error mat dikhao
      if (!hadCache) {
        _showSnack(
          e.toString().contains('Session expired')
              ? 'Session expired. Please login again.'
              : 'Unable to load dashboard data.',
        );
      }
    }
  }

  /// GET /api/Auth/profile -> ProfileResponse -> UserModel
  Future<UserModel?> _getProfile(
      Map<String, String> headers,
      SharedPreferences prefs,
      ) async {
    final response = await http
        .get(Uri.parse('$_baseUrl/api/Auth/profile'), headers: headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401) throw Exception('Session expired');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Profile API failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    final profile = ProfileResponse.fromJson(map);

    if (!profile.success) {
      throw Exception('Profile API returned success=false');
    }

    // Agli baar turant dikhane ke liye save karo
    await prefs.setString(_kProfileCache, response.body);
    return profile.user;
  }

  // ── Stats ────────────────────────────────────────────────

  /// Ek stats endpoint. Fail hone par null — baaki cards par asar nahi.
  Future<Map<String, dynamic>?> _fetchStat(
      String path,
      Map<String, String> headers,
      ) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl$path'), headers: headers)
          .timeout(const Duration(seconds: 20));

      debugPrint('[DASHBOARD STATS] $path -> ${res.statusCode} | ${res.body}');

      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final body = jsonDecode(res.body);
      if (body is Map && body['success'] == true && body['data'] is Map) {
        return Map<String, dynamic>.from(body['data'] as Map);
      }
    } catch (e) {
      debugPrint('[DASHBOARD STATS] $path ERROR: $e');
    }
    return null;
  }
  Future<void> _loadStats(Map<String, String> headers) async {
    final results = await Future.wait([
      _fetchStat('/api/confirmations/stats/pending-count', headers),
      _fetchStat('/api/confirmations/stats/inventory-confirmed-count', headers),
      _fetchStat('/api/confirmations/stats/count', headers),
      _fetchStat('/api/repo-cases/stats/linked-upload-agencies', headers),
    ]);

    final pending = results[0];
    final inventory = results[1];
    final count = results[2];
    final records = results[3];

    if (!mounted) return;
    setState(() {
      // Fail hone par purani value rakho
      if (pending != null) {
        _pendingConfirmations = _toInt(pending['pendingConfirmations']);
      }
      if (inventory != null) {
        _inventoryConfirmed = _toInt(inventory['inventoryConfirmed']);
      }
      if (count != null) {
        _confirmedConfirmations = _toInt(
          count['confirmedConfirmations'] ??
              count['confirmed'] ??
              count['confirmedCount'] ??
              count['CONFIRMED'],
        );
      }
      if (records != null) {
        _companyTotalRecords = _toInt(records['companyTotalRecords']);
      }
      _statsLoading = false;
    });
  }

  // ── Extractors ───────────────────────────────────────────

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

    void add(String? value) {
      final v = value?.trim() ?? '';
      if (v.isNotEmpty && !phones.contains(v)) phones.add(v);
    }

    add(user?.phone);
    add(user?.secondAgencyNumber);
    add(user?.company?.phone);

    return phones;
  }

  // Priority: user.address -> user.city -> company.address
  String _extractLocation(UserModel? user) {
    final address = user?.address.trim() ?? '';
    if (address.isNotEmpty) return address;

    final city = user?.city.trim() ?? '';
    if (city.isNotEmpty) return city;

    return user?.company?.address.trim() ?? '';
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
                    const SizedBox(height: 34),
                    _buildHero(isDark),
                    const SizedBox(height: 26),
                    _buildLocalStats(isDark),
                    const SizedBox(height: 16),
                    _buildActionsRow(isDark),
                    const SizedBox(height: 16),
                    _buildSeizedCard(isDark),
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
  // TOP BAR
  // =========================================================

  Widget _buildTopBar(bool isDark) {
    final canPop = Navigator.of(context).canPop();
    final barColor = isDark ? const Color(0xff10182A) : Colors.white;
    final border = isDark ? const Color(0xff263550) : const Color(0xffE5EAF2);
    final textColor = isDark ? Colors.white : Colors.black;
    final backBg =
    isDark ? Colors.white.withOpacity(.08) : const Color(0xffF3F6FA);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: barColor,
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
          // BACK (peeche koi screen ho tabhi dikhao)
          if (canPop) ...[
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration:
                  BoxDecoration(color: backBg, shape: BoxShape.circle),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: textColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ] else
            const SizedBox(width: 8),

          // LOGO + TITLE
          Expanded(
            child: Row(
              children: [
                Image.asset(
                  isDark
                      ? 'assets/images/fastrecovery_logo_2dark.png'
                      : 'assets/images/fastrecovery_logo-2.png',
                  width: 125,
                  height: 38,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 27, color: textColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dashboard',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.2,
                      color: textColor,
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
    final photoUrl =
    companyPhotoUrl.isNotEmpty ? companyPhotoUrl : userPhotoUrl;

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
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
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
                decoration:
                BoxDecoration(shape: BoxShape.circle, color: cardColor),
                child: ClipOval(child: _buildLogo(photoUrl)),
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

          // _user login ke turant baad null ho sakta hai
          Text(
            _user?.name ?? '',
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
            _heroLine(
              icon: Icons.phone_rounded,
              iconColor: AppColors.blue600,
              text: _displayPhone,
              fontSize: 12,
              weight: FontWeight.w600,
              color: mutedText,
            ),
          ],

          if (_location.isNotEmpty) ...[
            const SizedBox(height: 7),
            _heroLine(
              icon: Icons.location_on_rounded,
              iconColor: AppColors.gold400,
              text: _location,
              fontSize: 11.5,
              weight: FontWeight.w500,
              color: mutedText,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogo(String photoUrl) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue600),
          ),
        ),
      );
    }

    if (photoUrl.isEmpty) return _logoInitials();

    return Image.network(
      photoUrl.startsWith('http') ? photoUrl : '$_baseUrl$photoUrl',
      width: 92,
      height: 92,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _logoInitials(),
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

  Widget _heroLine({
    required IconData icon,
    required Color iconColor,
    required String text,
    required double fontSize,
    required FontWeight weight,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: weight,
              color: color,
            ),
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
            children: [
              _iconBadge(icon),
              const SizedBox(width: 11),
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

  /// Do cards ek row mein, beech mein gap.
  Widget _cardRow(Widget left, Widget right) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  // Total Records & Remaining Days (local values)
  Widget _buildLocalStats(bool isDark) {
    return _cardRow(
      _infoCard(
        isDark: isDark,
        icon: Icons.list_sharp,
        label: 'Total Records',
        subtitle: 'Record',
        value: _loading ? 0 : _companyTotalRecords,
        onTap: () {},
      ),
      _infoCard(
        isDark: isDark,
        icon: Icons.calendar_month_rounded,
        label: 'Remaining Days',
        subtitle: 'Days',
        value: _loading ? 0 : _remainingDays,
        onTap: () {},
      ),
    );
  }

  // Pending Confirmation & Confirmed Cases
  Widget _buildActionsRow(bool isDark) {
    return _cardRow(
      _infoCard(
        isDark: isDark,
        icon: Icons.pending_actions_rounded,
        label: 'Pending Confirmation',
        subtitle: 'Requests',
        value: _statsLoading ? 0 : _pendingConfirmations,
        onTap: () => _goTo(
          const PendingConfirmationPage(),
          refreshOnReturn: true,
        ),
      ),
      _infoCard(
        isDark: isDark,
        icon: Icons.directions_car_rounded,
        label: 'Confirmed Cases',
        subtitle: 'Vehicles',
        value: _statsLoading ? 0 : _confirmedConfirmations,
        onTap: () {
          final token = SharedPreferenceService.getToken();
          Navigator.push(
              context, MaterialPageRoute(
              builder: (context) => ConfirmedCases(token: token,)));
        },
      ),
        // onTap: () => _goTo(
        //   ConfirmedCasesScreen(api: ConfirmationApi()),
        //   refreshOnReturn: true,
      );
      }

  Widget _buildSeizedCard(bool isDark) {
    return _infoCard(
      isDark: isDark,
      icon: Icons.car_crash_rounded,
      label: 'Total Seized',
      subtitle: 'Seized',
      value: _statsLoading ? 0 : _inventoryConfirmed,
      onTap: () => _goTo(const SeizedSuccessfullyScreen()),
    );
  }

  // =========================================================
  // PAGE FOOTER
  // =========================================================

  Future<void> _launchUrl(String url) async {
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) _showSnack('Could not open link');
    } catch (_) {
      _showSnack('Could not open link');
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
// DRAWER FOOTER (Terms & Conditions, App version)
// HomeScreen ke drawer mein use hota hai — hataana mat.
// =============================================================

class DrawerFooter extends StatefulWidget {
  const DrawerFooter({super.key});

  @override
  State<DrawerFooter> createState() => _DrawerFooterState();
}

class _DrawerFooterState extends State<DrawerFooter> {
  static const String _termsUrl = 'https://www.fastrecovery.in/terms';

  // '...' = padh raha hai, '—' = padhne me error aaya
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
    var opened = false;
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
                Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: AppColors.blue600,
                ),
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
    super.key,
    required this.width,
    required this.height,
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