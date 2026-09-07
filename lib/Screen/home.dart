  import 'dart:async';
  import 'dart:convert';
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:http/http.dart' as http;
  import 'package:kartikrepoagency/Dashboard.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import '../Auth/Login/Login_page.dart';
  import '../Model_class/Proffile_model.dart';
  import '../main.dart';
  import '../theme/app_theme.dart';
  import 'ID_card.dart';
  import 'package:url_launcher/url_launcher.dart';
  import 'Profile_page.dart';

  class HomeScreen extends StatefulWidget {
    const HomeScreen({super.key});

    @override
    State<HomeScreen> createState() => _HomeScreenState();
  }

  class _HomeScreenState extends State<HomeScreen> {
    static const String baseUrl = 'https://www.fastrecovery.in';

    static const String searchUrl = '$baseUrl/api/repo-cases';

    static const String _profileUrl = '$baseUrl/api/auth/profile';

    final _vehicleController = TextEditingController();
    final _chassisController = TextEditingController();

    final _vehicleFocus = FocusNode();
    final _chassisFocus = FocusNode();

    Timer? _vehicleDebounce;
    Timer? _chassisDebounce;

    bool _searchingVehicle = false;
    bool _searchingChassis = false;

    List<Map<String, dynamic>> _searchResults = [];

    String _userName = 'User';
    String _companyName = 'Company';
    String _companyCode = '';

    int _drawerIndex = 0;
    bool _userDataLoading = true;

    bool _hasSearched = false;

    bool _statsLoading = true;
    int _totalCases = 0;
    int _todayActivity = 0;
    int _pendingConfirmations = 0;
    int _inventoryConfirmed = 0;

    @override
    void initState() {
      super.initState();

      _vehicleController.addListener(_onVehicleChanged);
      _chassisController.addListener(_onChassisChanged);

      // Rebuild on focus change so the field border updates live.
      _vehicleFocus.addListener(() => setState(() {}));
      _chassisFocus.addListener(() => setState(() {}));
      _loadDashboardStats();
      _loadUserData();
    }

    @override
    void dispose() {
      _vehicleDebounce?.cancel();
      _chassisDebounce?.cancel();

      _vehicleController.dispose();
      _chassisController.dispose();

      _vehicleFocus.dispose();
      _chassisFocus.dispose();

      super.dispose();
    }

    // ============================================================
    // LOGOUT
    // ============================================================

    Future<void> _launchUrl(String url) async {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $url');
      }
    }

    Future<void> _logout(BuildContext context) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // sara saved data clear (token, role, name, etc.)

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false, // pichla saara stack hata do
      );
    }

    void _showLogoutDialog(BuildContext context) {
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(.55),
        builder: (dialogContext) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.25),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with icon
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xff06162D), Color(0xff123B78)],
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.redAccent.withOpacity(.3),
                                ),
                              ),
                              child: const Icon(
                                Icons.logout_rounded,
                                color: Colors.redAccent,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Log Out',
                              style: AppTextStyles.display(
                                size: 19,
                                weight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Are you sure you want to log out\nof your agency workspace?',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body(
                                size: 12.5,
                                color: Colors.white.withOpacity(.65),
                              ).copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      ),

                      // Actions
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(color: AppColors.slate200),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () => Navigator.of(dialogContext).pop(),
                                child: Text(
                                  'Cancel',
                                  style: AppTextStyles.body(
                                    size: 13.5,
                                    weight: FontWeight.w700,
                                    color: AppColors.slate600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop(); // close dialog
                                  _logout(context); // do actual logout
                                },
                                child: const Text(
                                  'Log Out',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    // ============================================================
    // TOKEN
    // ============================================================

    Future<String?> _getToken() async {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('token');

      if (stored != null && stored.isNotEmpty) {
        return stored;
      }

      return null;
    }

    // ============================================================
    // USER / COMPANY — now fetched dynamically from the profile API
    // (same endpoint + typed model used on the Profile screen), with
    // SharedPreferences only as an offline/no-token fallback.
    // ============================================================
    Future<void> _loadUserData() async {
      if (!mounted) return;

      setState(() => _userDataLoading = true);

      final prefs = await SharedPreferences.getInstance();

      // Local fallback values (used if the API call fails / no token).
      final cachedUserName = prefs.getString('userName');
      final cachedCompanyName = prefs.getString('companyName');
      final cachedCompanyCode = prefs.getString('companyCode');

      try {
        final token = await _getToken();

        if (token == null || token.trim().isEmpty) {
          throw Exception('No token — using cached values');
        }

        final response = await http.get(
          Uri.parse(_profileUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        dynamic decodedBody;
        try {
          decodedBody = jsonDecode(response.body);
        } catch (_) {
          decodedBody = null;
        }

        final decodedMap =
        decodedBody is Map<String, dynamic> ? decodedBody : <String, dynamic>{};

        final profileResponse = ProfileResponse.fromJson(decodedMap);

        if (response.statusCode != 200 || !profileResponse.success) {
          throw Exception('Profile API failed: ${response.statusCode}');
        }

        final user = profileResponse.user;

        if (!mounted) return;

        final resolvedCompanyName = _extractCompanyName(user);
        final resolvedCompanyCode = user?.company?.companyCode.trim() ?? '';
        final resolvedUserName = (user?.name.trim().isNotEmpty ?? false)
            ? user!.name.trim()
            : 'User';

        setState(() {
          _userName = resolvedUserName;
          _companyName = resolvedCompanyName;
          _companyCode = resolvedCompanyCode;
          _userDataLoading = false;
        });

        // Keep the cache fresh for next launch / offline fallback.
        await prefs.setString('userName', resolvedUserName);
        await prefs.setString('companyName', resolvedCompanyName);
        await prefs.setString('companyCode', resolvedCompanyCode);
      } catch (e) {
        debugPrint('LOAD USER DATA — falling back to cache: $e');

        if (!mounted) return;

        setState(() {
          _userName =
          (cachedUserName != null && cachedUserName.trim().isNotEmpty)
              ? cachedUserName
              : 'User';
          _companyName =
          (cachedCompanyName != null && cachedCompanyName.trim().isNotEmpty)
              ? cachedCompanyName
              : 'Your Agency';
          _companyCode = cachedCompanyCode ?? '';
          _userDataLoading = false;
        });
      }
    }

    // Priority: company.companyName -> user.agencyName -> fallback.
    String _extractCompanyName(UserModel? user) {
      final companyName = user?.company?.companyName.trim() ?? '';
      if (companyName.isNotEmpty) return companyName;

      final agencyName = user?.agencyName.trim() ?? '';
      if (agencyName.isNotEmpty) return agencyName;

      return 'Your Agency';
    }

    // ============================================================
    // VEHICLE INPUT
    // ============================================================

    void _onVehicleChanged() {
      final value = _vehicleController.text.trim();

      _vehicleDebounce?.cancel();

      if (value.isEmpty) {
        if (mounted) {
          setState(() {
            _searchResults = [];
            _hasSearched = false;
          });
        }
        return;
      }

      if (value.length == 4) {
        _vehicleDebounce = Timer(
          const Duration(milliseconds: 350),
              () => _searchVehicle(value),
        );
      }
    }
    // ============================================================
    // CHASSIS INPUT
    // ============================================================
    void _onChassisChanged() {
      final value = _chassisController.text.trim();

      _chassisDebounce?.cancel();

      if (value.isEmpty) {
        if (mounted) {
          setState(() {
            _searchResults = [];
            _hasSearched = false;
          });
        }
        return;
      }

      if (value.length == 6) {
        _chassisDebounce = Timer(
          const Duration(milliseconds: 350),
              () => _searchChassis(value),
        );
      }
    }

    void _openVehicleDetails(Map<String, dynamic> item) {
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(.55),
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 30,
            ),
            child: VehicleDetailsPopup(
              item: item,
              onClose: () {
                Navigator.of(context).pop();
              },
            ),
          );
        },
      );
    }




    // ============================================================
    // SEARCH VEHICLE
    // ============================================================

    // ============================================================
// SEARCH VEHICLE
// ============================================================

    Future<void> _searchVehicle(String lastFour) async {
      if (lastFour.length != 4) return;

      _chassisDebounce?.cancel();

      FocusScope.of(context).unfocus();

      if (!mounted) return;

      setState(() {
        _searchingVehicle = true;
        _searchingChassis = false;
        _searchResults = [];
        _hasSearched = true;
      });

      try {
        final token = await _getToken();

        final uri = Uri.parse(searchUrl).replace(
          queryParameters: {
            'search': lastFour,
            'type': 'vehicleNumber',
            'page': '1',
            'limit': '500',
          },
        );

        final headers = <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        };

        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }

        debugPrint('');
        debugPrint('========== VEHICLE SEARCH ==========');
        debugPrint('SEARCH: $lastFour');
        debugPrint('TYPE: vehicleNumber');
        debugPrint('LIMIT: 500');
        debugPrint('URL: $uri');

        final response = await http
            .get(uri, headers: headers)
            .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Vehicle search timed out');
          },
        );

        debugPrint('STATUS: ${response.statusCode}');
        debugPrint('BODY: ${response.body}');

        dynamic body;

        try {
          body = jsonDecode(response.body);
        } catch (e) {
          debugPrint('❌ JSON ERROR: $e');

          if (!mounted) return;

          _showMessage(
            'Invalid response from server',
            isError: true,
          );
          return;
        }

        // Unauthorized
        if (response.statusCode == 401) {
          _handleUnauthorized();
          return;
        }

        // Other API errors
        if (response.statusCode < 200 || response.statusCode >= 300) {
          String message = 'Vehicle search failed';

          if (body is Map && body['message'] != null) {
            message = body['message'].toString();
          }

          _showMessage(message, isError: true);
          return;
        }

        final results = _extractResults(body);

        debugPrint('FINAL VEHICLE RESULT COUNT: ${results.length}');

        if (!mounted) return;

        setState(() {
          _searchResults = results;
        });

        if (results.isEmpty) {
          _showMessage(
            'No vehicle records found for ****$lastFour',
            isError: true,
          );
        }
      } on TimeoutException {
        debugPrint('❌ VEHICLE SEARCH TIMEOUT');

        if (!mounted) return;

        _showMessage(
          'Search is taking too long. Please try again.',
          isError: true,
        );
      } catch (e, stack) {
        debugPrint('❌ VEHICLE SEARCH ERROR: $e');
        debugPrint(stack.toString());

        if (!mounted) return;

        _showMessage(
          'Unable to search vehicle right now',
          isError: true,
        );
      } finally {
        if (!mounted) return;

        setState(() {
          _searchingVehicle = false;
        });
      }
    }


// ============================================================
// SEARCH CHASSIS
// ============================================================

    Future<void> _searchChassis(String lastSix) async {
      if (lastSix.length != 6) return;

      _vehicleDebounce?.cancel();

      FocusScope.of(context).unfocus();

      if (!mounted) return;

      setState(() {
        _searchingChassis = true;
        _searchingVehicle = false;
        _searchResults = [];
        _hasSearched = true;
      });

      try {
        final token = await _getToken();

        final uri = Uri.parse(searchUrl).replace(
          queryParameters: {
            'search': lastSix,
            'type': 'chassisNumber',
            'page': '1',
            'limit': '500',
          },
        );

        final headers = <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        };

        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }

        debugPrint('');
        debugPrint('========== CHASSIS SEARCH ==========');
        debugPrint('SEARCH: $lastSix');
        debugPrint('TYPE: chassisNumber');
        debugPrint('LIMIT: 500');
        debugPrint('URL: $uri');

        final response = await http
            .get(uri, headers: headers)
            .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Chassis search timed out');
          },
        );

        debugPrint('STATUS: ${response.statusCode}');
        debugPrint('BODY: ${response.body}');

        dynamic body;

        try {
          body = jsonDecode(response.body);
        } catch (e) {
          debugPrint('❌ CHASSIS JSON ERROR: $e');

          if (!mounted) return;

          _showMessage(
            'Invalid response from server',
            isError: true,
          );
          return;
        }

        // Unauthorized
        if (response.statusCode == 401) {
          _handleUnauthorized();
          return;
        }

        // Other API errors
        if (response.statusCode < 200 || response.statusCode >= 300) {
          String message = 'Chassis search failed';

          if (body is Map && body['message'] != null) {
            message = body['message'].toString();
          }

          _showMessage(message, isError: true);
          return;
        }

        final results = _extractResults(body);

        debugPrint('FINAL CHASSIS RESULT COUNT: ${results.length}');

        if (!mounted) return;

        setState(() {
          _searchResults = results;
        });

        if (results.isEmpty) {
          _showMessage(
            'No chassis records found for ******$lastSix',
            isError: true,
          );
        }
      } on TimeoutException {
        debugPrint('❌ CHASSIS SEARCH TIMEOUT');

        if (!mounted) return;

        _showMessage(
          'Search is taking too long. Please try again.',
          isError: true,
        );
      } catch (e, stack) {
        debugPrint('❌ CHASSIS SEARCH ERROR: $e');
        debugPrint(stack.toString());

        if (!mounted) return;

        _showMessage(
          'Unable to search chassis right now',
          isError: true,
        );
      } finally {
        if (!mounted) return;

        setState(() {
          _searchingChassis = false;
        });
      }
    }

    // ============================================================
    // EXTRACT API RESULTS
    // ============================================================

    List<Map<String, dynamic>> _extractResults(dynamic body) {
      if (body is! Map) {
        return [];
      }

      dynamic rawResults;

      if (body['items'] is List) {
        rawResults = body['items'];
      } else if (body['data'] is List) {
        rawResults = body['data'];
      } else if (body['results'] is List) {
        rawResults = body['results'];
      } else if (body['cases'] is List) {
        rawResults = body['cases'];
      } else if (body['records'] is List) {
        rawResults = body['records'];
      }

      if (rawResults is! List) {
        return [];
      }

      return rawResults
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    // ============================================================
    // UNAUTHORIZED
    // ============================================================

    void _handleUnauthorized() {
      if (!mounted) return;

      setState(() {
        _searchingVehicle = false;
        _searchingChassis = false;
      });

      _showMessage('Session expired. Please login again.', isError: true);
    }

    // ============================================================
    // MESSAGE
    // ============================================================

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
                    isError ? Icons.search_off_rounded : Icons.hourglass_top_rounded,
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



    Future<void> _loadDashboardStats() async {
      if (!mounted) return;
      setState(() => _statsLoading = true);

      try {
        final token = await _getToken();
        if (token == null || token.isEmpty) {
          if (!mounted) return;
          setState(() => _statsLoading = false);
          return;
        }

        final headers = <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        };

        final results = await Future.wait([
          http.get(Uri.parse('$baseUrl/api/repo-cases/stats/overview'), headers: headers),
          http.get(Uri.parse('$baseUrl/api/confirmations/stats/pending-count'), headers: headers),
          http.get(Uri.parse('$baseUrl/api/confirmations/stats/inventory-confirmed-count'), headers: headers),
        ]);

        int totalCases = 0;
        int todayActivity = 0;
        int pending = 0;
        int inventoryConfirmed = 0;

        if (results[0].statusCode >= 200 && results[0].statusCode < 300) {
          final body = jsonDecode(results[0].body);
          if (body is Map && body['success'] == true && body['data'] is Map) {
            final data = body['data'] as Map;
            totalCases = _toInt(data['cases']);
            todayActivity = _toInt(data['todayActivity']);
          }
        }

        if (results[1].statusCode >= 200 && results[1].statusCode < 300) {
          final body = jsonDecode(results[1].body);
          if (body is Map && body['success'] == true && body['data'] is Map) {
            pending = _toInt((body['data'] as Map)['pendingConfirmations']);
          }
        }

        if (results[2].statusCode >= 200 && results[2].statusCode < 300) {
          final body = jsonDecode(results[2].body);
          if (body is Map && body['success'] == true && body['data'] is Map) {
            inventoryConfirmed = _toInt((body['data'] as Map)['inventoryConfirmed']);
          }
        }

        if (!mounted) return;
        setState(() {
          _totalCases = totalCases;
          _todayActivity = todayActivity;
          _pendingConfirmations = pending;
          _inventoryConfirmed = inventoryConfirmed;
          _statsLoading = false;
        });
      } catch (e) {
        debugPrint('DASHBOARD STATS ERROR: $e');
        if (!mounted) return;
        setState(() => _statsLoading = false);
      }
    }

    int _toInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }


    void _clearSearch({
      TextEditingController? controller,
      FocusNode? focusNode,
    }) {
      _vehicleDebounce?.cancel();
      _chassisDebounce?.cancel();

      if (controller != null && controller.text.isNotEmpty) {
        controller.clear();
      }

      if (!mounted) return;

      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _searchingVehicle = false;
        _searchingChassis = false;
      });

      if (focusNode != null) {
        FocusScope.of(context).requestFocus(focusNode);
      }
    }

    // ============================================================
    // BUILD
    // ============================================================

    @override
    Widget build(BuildContext context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xff0B1220)
            : AppColors.paper,
        drawer: _buildDrawer(),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),

              // ← YE MISSING THA — search box (Vehicle/Chassis fields)
              Transform.translate(
                offset: const Offset(0, -26),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _buildFindCard(),
                ),
              ),

              // Results / Skeleton / Stats — ek hi jagah, duplicate hataya
              Transform.translate(
                offset: const Offset(0, -10),
                child: (_searchingVehicle || _searchingChassis)
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

    Widget _buildStatsCards() {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _homeStatCard(
                    isDark: isDark,
                    label: 'Total Uploaded Cases',
                    value: _totalCases,
                    accent: AppColors.blue600,
                    icon: Icons.inventory_2_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _homeStatCard(
                    isDark: isDark,
                    label: 'Today Activity',
                    value: _todayActivity,
                    accent: AppColors.gold400,
                    icon: Icons.insights_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _homeStatCard(
                    isDark: isDark,
                    label: 'Pending Confirmations',
                    value: _pendingConfirmations,
                    accent: const Color(0xffF59E0B),
                    icon: Icons.pending_actions_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _homeStatCard(
                    isDark: isDark,
                    label: 'Inventory. Confirmed',
                    value: _inventoryConfirmed,
                    accent: const Color(0xff059669),
                    icon: Icons.verified_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
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
      final labelColor = isDark ? const Color(0xff8A97B0) : const Color(0xff64748B);
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
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: labelColor),
            ),
            const SizedBox(height: 5),
            _statsLoading
                ? const _ShimmerBox(width: 50, height: 22)
                : Text(
              value.toString(),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: valueColor),
            ),
          ],
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
                Builder(
                  builder: (context) {
                    return GestureDetector(
                      onTap: () {
                        Scaffold.of(context).openDrawer();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.menu_rounded,
                          size: 21,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xff111827)
                              : Colors.white,
                        ),
                      ),
                    );
                  },
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
                  const _ShimmerBox(width: 60, height: 24, radius: BorderRadius.all(Radius.circular(9)))
                else if (_companyCode.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
              style: AppTextStyles.body(size: 14, color: Colors.white.withOpacity(.72)),
            ),
            const SizedBox(height: 4),
            _userDataLoading
                ? const _ShimmerBox(width: 160, height: 26)
                : Text(
              _userName,
              style: AppTextStyles.display(size: 25, weight: FontWeight.w800, color: Colors.white),
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
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold400),
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
                  _userDataLoading ? 'Loading your profile...' : 'Search vehicles instantly',
                  style: AppTextStyles.mono(size: 11.5, color: Colors.white.withOpacity(.78)),
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
          color: isDark
              ? const Color(0xff111827)
              : Colors.white,
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
                          color: isDark
                              ? Colors.white
                              : AppColors.navy950,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        'Enter last digits to search automatically',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark
                              ? Colors.white60
                              : AppColors.slate600,
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
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    isLoading: _statsLoading,
                    onClear: () {
                      _clearSearch(
                        controller: _vehicleController,
                        focusNode: _vehicleFocus,
                      );
                    },
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
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    isLoading: _statsLoading,
                    onClear: () {
                      _clearSearch(
                        controller: _chassisController,
                        focusNode: _chassisFocus,
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 13),

            // Container(
            //   width: double.infinity,
            //   padding: const EdgeInsets.symmetric(
            //     horizontal: 13,
            //     vertical: 11,
            //   ),
            //   decoration: BoxDecoration(
            //     color: isDark
            //         ? const Color(0xff1E293B)
            //         : const Color(0xffF8FAFC),
            //     borderRadius: BorderRadius.circular(13),
            //     border: Border.all(
            //       color: isDark
            //           ? const Color(0xff334155)
            //           : const Color(0xffE2E8F0),
            //     ),
            //   ),
            //   child: Row(
            //     children: [
            //       Icon(
            //         Icons.info_outline_rounded,
            //         size: 16,
            //         color: isDark
            //             ? Colors.white54
            //             : AppColors.slate600,
            //       ),
            //
            //       const SizedBox(width: 8),
            //
            //       // Expanded(
            //       //   child: Text(
            //       //     'Vehicle: last 4 digits  •  Chassis: last 6 digits',
            //       //     style: AppTextStyles.body(
            //       //       size: 10.5,
            //       //       color: isDark
            //       //           ? Colors.white60
            //       //           : AppColors.slate600,
            //       //     ),
            //       //   ),
            //       // ),
            //     ],
            //   ),
            // ),

            if (_searchingVehicle || _searchingChassis) ...[
              const SizedBox(height: 13),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: AppColors.blue600.withOpacity(.10),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: AppColors.blue600.withOpacity(.25),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                      ),
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

    // ============================================================
    // FIELD
    // ============================================================

    Widget _findField({
      required String label,
      required String hint,
      required IconData icon,
      required TextEditingController controller,
      required FocusNode focusNode,
      required int maxLength,
      required TextInputType keyboardType,
      required bool isLoading,
      required VoidCallback onClear,
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
              color: isDark
                  ? const Color(0xff0F172A)
                  : const Color(0xffFCFDFE),
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
                  color: isDark
                      ? Colors.white54
                      : AppColors.slate400,
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    maxLength: maxLength,
                    keyboardType: keyboardType,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(maxLength),
                    ],
                    textCapitalization: TextCapitalization.characters,
                    style: AppTextStyles.mono(
                      size: 14,
                      weight: FontWeight.w700,
                      color: isDark
                          ? Colors.white
                          : AppColors.navy950,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: AppTextStyles.body(
                        size: 12.5,
                        color: isDark
                            ? Colors.white38
                            : AppColors.slate400,
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
                    if (isLoading) {
                      return const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      );
                    }

                    if (value.text.isEmpty) {
                      return const SizedBox(
                        width: 20,
                        height: 20,
                      );
                    }

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onClear,
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: Icon(
                            Icons.close_rounded,
                            size: 19,
                            color: isDark
                                ? Colors.white70
                                : AppColors.slate600,
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
    // RESULTS — tap now opens the full details popup
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

    Widget _buildSearchResults() {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      // API se aaye hue actual records ka count
      final resultCount = _searchResults.length;

      if (_searchResults.isEmpty) {
        return Column(
          children: [
            // Count = 0
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xff111827)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xff334155)
                        : const Color(0xffE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.search_off_rounded,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Search Results',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white70
                              : AppColors.slate600,
                        ),
                      ),
                    ),
                    Text(
                      '0',
                      style: AppTextStyles.mono(
                        size: 20,
                        weight: FontWeight.w900,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _buildEmptyResults(),
          ],
        );
      }

      // ============================================================
      // SORT RESULTS
      // ============================================================

      final sorted = List<Map<String, dynamic>>.from(_searchResults)
        ..sort((a, b) {
          final numberA =
          (a['vehicleNumber']?.toString().trim() ?? '').toUpperCase();

          final numberB =
          (b['vehicleNumber']?.toString().trim() ?? '').toUpperCase();

          final prefixA =
              RegExp(r'^[A-Z]+').firstMatch(numberA)?.group(0) ?? '';

          final prefixB =
              RegExp(r'^[A-Z]+').firstMatch(numberB)?.group(0) ?? '';

          final prefixCompare = prefixA.compareTo(prefixB);

          if (prefixCompare != 0) {
            return prefixCompare;
          }

          return numberA.compareTo(numberB);
        });

      final half = (sorted.length / 2).ceil();

      final firstColumn = sorted.take(half).toList();
      final secondColumn = sorted.skip(half).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ========================================================
          // RESULT COUNT HEADER
          // ========================================================

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xff111827)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xff334155)
                      : const Color(0xffE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      isDark ? .20 : .04,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [

                  // Search icon
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.blue600.withOpacity(.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: AppColors.blue600,
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search Results',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white70
                                : AppColors.slate600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          resultCount == 1
                              ? '1 record found'
                              : '$resultCount records found',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.white38
                                : AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // =================================================
                  // ACTUAL COUNT NUMBER
                  // =================================================

                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.blue600,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      resultCount.toString(),
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
          ),

          // ========================================================
          // VEHICLE / CHASSIS RESULTS
          // ========================================================

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // First column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: firstColumn.map((item) {
                    final vehicleNumber =
                    item['vehicleNumber']?.toString().trim();

                    final chassisNumber =
                    item['chassisNumber']?.toString().trim();

                    final number =
                    (vehicleNumber != null &&
                        vehicleNumber.isNotEmpty)
                        ? vehicleNumber
                        : (chassisNumber != null &&
                        chassisNumber.isNotEmpty)
                        ? chassisNumber
                        : '—';

                    return GestureDetector(
                      onTap: () => _openVehicleDetails(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 5,
                        ),
                        child: Text(
                          number,
                          style: AppTextStyles.mono(
                            size: 24,
                            weight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : AppColors.slate600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(width: 20),

              // Second column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: secondColumn.map((item) {
                    final vehicleNumber =
                    item['vehicleNumber']?.toString().trim();

                    final chassisNumber =
                    item['chassisNumber']?.toString().trim();

                    final number =
                    (vehicleNumber != null &&
                        vehicleNumber.isNotEmpty)
                        ? vehicleNumber
                        : (chassisNumber != null &&
                        chassisNumber.isNotEmpty)
                        ? chassisNumber
                        : '—';

                    return GestureDetector(
                      onTap: () => _openVehicleDetails(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 5,
                        ),
                        child: Text(
                          number,
                          style: AppTextStyles.mono(
                            size: 24,
                            weight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : AppColors.slate600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      );
    }

    Widget _buildEmptyResults() {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded,
                size: 40, color: isDark ? Colors.white24 : AppColors.slate400),
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

    // Widget _resultCard({
    //   required bool isDark,
    //   // required String customerName,
    //   required String number,
    //   // String? bankName,
    //   // String? status,
    //   required VoidCallback onTap,
    // }) {
    //   final cardGradient = isDark
    //       ? const LinearGradient(
    //     begin: Alignment.topLeft,
    //     end: Alignment.bottomRight,
    //     colors: [Color(0xff151F32), Color(0xff0F1729)],
    //   )
    //       : const LinearGradient(
    //     begin: Alignment.topLeft,
    //     end: Alignment.bottomRight,
    //     colors: [Colors.white, Color(0xffF7F9FC)],
    //   );
    //
    //   final border = isDark ? const Color(0xff273449) : const Color(0xffE9EEF4);
    //
    //   return Material(
    //     color: Colors.transparent,
    //     child: InkWell(
    //       onTap: onTap,
    //       borderRadius: BorderRadius.circular(20),
    //       splashColor: AppColors.blue600.withOpacity(.08),
    //       child: Ink(
    //         decoration: BoxDecoration(
    //           gradient: cardGradient,
    //           borderRadius: BorderRadius.circular(20),
    //           border: Border.all(color: border),
    //           boxShadow: [
    //             // soft ambient shadow
    //             BoxShadow(
    //               color: Colors.black.withOpacity(isDark ? .35 : .06),
    //               blurRadius: 20,
    //               offset: const Offset(0, 10),
    //             ),
    //             // tight contact shadow — gives the "lifted card" 3D depth
    //             BoxShadow(
    //               color: Colors.black.withOpacity(isDark ? .25 : .035),
    //               blurRadius: 2,
    //               offset: const Offset(0, 1),
    //             ),
    //             // top inner highlight
    //             if (!isDark)
    //               const BoxShadow(
    //                 color: Colors.white,
    //                 blurRadius: 0,
    //                 spreadRadius: -1,
    //                 offset: Offset(0, -1),
    //               ),
    //           ],
    //         ),
    //         padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
    //         child: Column(
    //           crossAxisAlignment: CrossAxisAlignment.start,
    //           children: [
    //             Row(
    //               children: [
    //                 // Container(
    //                 //   width: 38,
    //                 //   height: 38,
    //                 //   decoration: BoxDecoration(
    //                 //     gradient: AppColors.blueGradient,
    //                 //     borderRadius: BorderRadius.circular(12),
    //                 //     boxShadow: [
    //                 //       BoxShadow(
    //                 //         color: AppColors.blue600.withOpacity(.35),
    //                 //         blurRadius: 10,
    //                 //         offset: const Offset(0, 4),
    //                 //       ),
    //                 //     ],
    //                 //   ),
    //                 //   //child: const Icon(Icons.person_rounded, color: Colors.white, size: 19),
    //                 // ),
    //                 // const Spacer(),
    //               //   if (status != null && status.isNotEmpty)
    //               //     Container(
    //               //       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    //               //       decoration: BoxDecoration(
    //               //         color: AppColors.gold400.withOpacity(.16),
    //               //         borderRadius: BorderRadius.circular(20),
    //               //       ),
    //               //       child: Text(
    //               //         status.toUpperCase(),
    //               //         style: const TextStyle(
    //               //           color: Color(0xffB45309),
    //               //           fontSize: 8.5,
    //               //           fontWeight: FontWeight.w800,
    //               //           letterSpacing: .3,
    //               //         ),
    //               //       ),
    //               //     ),
    //                ],
    //             ),
    //             //const SizedBox(height: 12),
    //
    //             // NAME on top
    //             // Text(
    //             //   customerName,
    //             //   maxLines: 1,
    //             //   overflow: TextOverflow.ellipsis,
    //             //   style: AppTextStyles.body(
    //             //     size: 14,
    //             //     weight: FontWeight.w800,
    //             //     color: isDark ? Colors.white : const Color(0xFF071A33),
    //             //   ),
    //             // ),
    //             //const SizedBox(height: 4),
    //
    //             // NUMBER below
    //             Text(
    //               number,
    //               maxLines: 1,
    //               overflow: TextOverflow.ellipsis,
    //               style: AppTextStyles.mono(
    //                 size: 13.5,
    //                 weight: FontWeight.w700,
    //                 color: AppColors.blue600,
    //               ).copyWith(letterSpacing: .5),
    //             ),
    //
    //             // if (bankName != null && bankName.isNotEmpty) ...[
    //             //   const SizedBox(height: 8),
    //             //   Row(
    //             //     children: [
    //             //       Icon(Icons.account_balance_outlined,
    //             //           size: 12, color: isDark ? Colors.white38 : AppColors.slate400),
    //             //       const SizedBox(width: 4),
    //             //       Expanded(
    //             //         child: Text(
    //             //           bankName,
    //             //           maxLines: 1,
    //             //           overflow: TextOverflow.ellipsis,
    //             //           style: TextStyle(
    //             //             fontSize: 10.5,
    //             //             fontWeight: FontWeight.w600,
    //             //             color: isDark ? Colors.white54 : AppColors.slate600,
    //             //           ),
    //             //         ),
    //             //       ),
    //             //     ],
    //             //   ),
    //             // ],
    //
    //             const Spacer(),
    //             Align(
    //               alignment: Alignment.centerRight,
    //               child: Icon(Icons.arrow_forward_rounded,
    //                   size: 16, color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
    //             ),
    //           ],
    //         ),
    //       ),
    //     ),
    //   );
    // }
    // ============================================================
    // DRAWER
    // ============================================================

    Widget _buildDrawer() {
      final drawerItems = [
        (Icons.home_rounded, 'Dashboard'),
        (Icons.home_rounded, 'Find Vechcial'),
        (Icons.credit_card_outlined, 'ID Card'),
        (Icons.badge_outlined, 'Profile'),
      ];

      final isDark =
          Theme.of(context).brightness == Brightness.dark;

      // =========================
      // THEME COLORS
      // =========================

      final drawerBackground =
      isDark
          ? const Color(0xFF0B1220)
          : Colors.white;

      final primaryText =
      isDark
          ? Colors.white
          : const Color(0xFF172033);

      final secondaryText =
      isDark
          ? const Color(0xFFB8C2D1)
          : const Color(0xFF64748B);

      final iconColor =
      isDark
          ? AppColors.gold400
          : AppColors.blue600;

      final dividerColor =
      isDark
          ? Colors.white.withOpacity(0.08)
          : Colors.black.withOpacity(0.08);

      final selectedBackground =
      isDark
          ? AppColors.blue500.withOpacity(0.14)
          : AppColors.blue500.withOpacity(0.08);

      final selectedBorder =
      isDark
          ? AppColors.blue500.withOpacity(0.45)
          : AppColors.blue500.withOpacity(0.25);

      return Drawer(
        width: 270,
        backgroundColor: drawerBackground,

        child: SafeArea(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [

              // =========================
              // HEADER
              // =========================
              Padding(
                padding:
                const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  20,
                ),

                child: Row(
                  children: [

                    // Company Icon
                    Container(
                      width: 42,
                      height: 42,

                      decoration: BoxDecoration(
                        gradient:
                        AppColors.blueGradient,

                        borderRadius:
                        BorderRadius.circular(12),
                      ),

                      alignment:
                      Alignment.center,

                      child: Icon(
                        Icons.business_rounded,
                        size: 21,

                        // Icon is always visible
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Company Name — dynamic, same _companyName as header
                    Expanded(
                      child: _userDataLoading
                          ? const _ShimmerBox(width: 120, height: 14)
                          : Text(
                        _companyName.isNotEmpty
                            ? _companyName
                            : 'Your Agency',

                        maxLines: 2,

                        overflow:
                        TextOverflow.ellipsis,

                        style:
                        AppTextStyles.display(
                          size: 13,
                          weight:
                          FontWeight.w700,
                          color: primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // =========================
              // DIVIDER
              // =========================
              Divider(
                color: dividerColor,
                height: 1,
              ),

              // =========================
              // MENU ITEMS
              // =========================
              Expanded(
                child: ListView.builder(
                  padding:
                  const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),

                  itemCount:
                  drawerItems.length,

                  itemBuilder:
                      (context, i) {

                    final item =
                    drawerItems[i];

                    final active =
                        i == _drawerIndex;

                    return Padding(
                      padding:
                      const EdgeInsets.only(
                        bottom: 4,
                      ),

                      child: ListTile(
                        dense: true,

                        // =====================
                        // ICON
                        // =====================
                        leading: Icon(
                          item.$1,
                          size: 20,

                          color: active
                              ? (isDark
                              ? AppColors.gold400
                              : AppColors.blue600)
                              : (isDark
                              ? const Color(
                            0xFF9AA7BA,
                          )
                              : const Color(
                            0xFF64748B,
                          )),
                        ),

                        // =====================
                        // TITLE
                        // =====================
                        title: Text(
                          item.$2,

                          style:
                          AppTextStyles.body(
                            size: 13.5,

                            weight: active
                                ? FontWeight.w700
                                : FontWeight.w500,

                            color: active
                                ? primaryText
                                : secondaryText,
                          ),
                        ),

                        // =====================
                        // SELECTED
                        // =====================
                        selected: active,

                        selectedTileColor:
                        selectedBackground,

                        shape: active
                            ? RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                            10,
                          ),

                          side: BorderSide(
                            color:
                            selectedBorder,
                          ),
                        )
                            : null,

                        contentPadding:
                        const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),

                        onTap: () {

                          setState(() {
                            _drawerIndex = i;
                          });

                          Navigator.of(context)
                              .pop();

                          if (item.$2 ==
                              'Profile') {

                            Navigator.of(context)
                                .push(
                              MaterialPageRoute(
                                builder: (_) =>
                                const ProfileScreen(),
                              ),
                            );

                          } else if (item.$2 ==
                              'ID Card') {

                            Navigator.of(context)
                                .push(
                              MaterialPageRoute(
                                builder: (_) =>
                                const IdCardPage(),
                              ),
                            );
                          }
                          else if (item.$2 ==
                              'Dashboard') {

                            Navigator.of(context)
                                .push(
                              MaterialPageRoute(
                                builder: (_) =>
                                const AgencyDashboardPage(),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),

              // =========================
              // DARK MODE
              // =========================
              ListTile(
                dense: true,

                leading:
                ValueListenableBuilder<
                    ThemeMode>(
                  valueListenable:
                  themeNotifier,

                  builder:
                      (context, mode, _) {

                    final dark =
                        mode ==
                            ThemeMode.dark;

                    return Icon(
                      dark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,

                      size: 20,

                      color: dark
                          ? AppColors.gold400
                          : AppColors.blue600,
                    );
                  },
                ),

                title: Text(
                  'Dark Mode',

                  style:
                  AppTextStyles.body(
                    size: 13.5,
                    weight:
                    FontWeight.w500,
                    color: primaryText,
                  ),
                ),

                trailing:
                ValueListenableBuilder<
                    ThemeMode>(
                  valueListenable:
                  themeNotifier,

                  builder:
                      (context, mode, _) {

                    final dark =
                        mode ==
                            ThemeMode.dark;

                    return Switch(
                      value: dark,

                      activeColor:
                      AppColors.gold400,

                      activeTrackColor:
                      AppColors.gold400
                          .withOpacity(0.30),

                      inactiveThumbColor:
                      AppColors.blue600,

                      inactiveTrackColor:
                      AppColors.blue600
                          .withOpacity(0.15),

                      onChanged:
                          (value) {
                        toggleTheme(value);
                      },
                    );
                  },
                ),

                contentPadding:
                const EdgeInsets.symmetric(
                  horizontal: 18,
                ),
              ),

              // =========================
              // DIVIDER
              // =========================
              Divider(
                color: dividerColor,
                height: 1,
              ),

              // =========================
              // LOGOUT
              // =========================
              ListTile(
                dense: true,

                leading: const Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: Colors.redAccent,
                ),

                title: Text(
                  'Logout',

                  style:
                  AppTextStyles.body(
                    size: 13.5,
                    weight:
                    FontWeight.w700,
                    color: Colors.redAccent,
                  ),
                ),

                contentPadding:
                const EdgeInsets.symmetric(
                  horizontal: 18,
                ),

                onTap: () {
                  Navigator.of(context).pop();

                  _showLogoutDialog(context);
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }
  }

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
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : const Color(0xffE9EEF4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 44,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : const Color(0xffE9EEF4),
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
                      color: isDark ? Colors.white12 : const Color(0xffE9EEF4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : const Color(0xffE9EEF4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 70,
                    height: 9,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : const Color(0xffE9EEF4),
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

  // ============================================================
  // VEHICLE DETAILS POPUP
  // ============================================================

  class VehicleDetailsPopup extends StatefulWidget {
    final Map<String, dynamic> item;
    final VoidCallback onClose;

    const VehicleDetailsPopup({
      super.key,
      required this.item,
      required this.onClose,
    });

    @override
    State<VehicleDetailsPopup> createState() => _VehicleDetailsPopupState();
  }

  class _VehicleDetailsPopupState extends State<VehicleDetailsPopup>
      with SingleTickerProviderStateMixin {
    late AnimationController _controller;

    @override
    void initState() {
      super.initState();

      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700),
      );

      _controller.forward();
    }

    @override
    void dispose() {
      _controller.dispose();
      super.dispose();
    }

    String _value(String key) {
      final value = widget.item[key];

      if (value == null) return '-';

      final text = value.toString();

      if (text.isEmpty || text == 'null') {
        return '-';
      }

      return text;
    }

    @override
    Widget build(BuildContext context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      final vehicle = _value('vehicleNumber');
      final chassis = _value('chassisNumber');
      final customer = _value('customerName');
      final bank = _value('bankName');
      final branch = _value('branchName');
      final brand = _value('vehicleBrand');
      final model = _value('vehicleModel');
      final status = _value('repoStatus');
      final address = _value('addressLine1');
      final emi = _value('emiAmount');
      final due = _value('dueAmount');
      final outstanding = _value('totalOutstandingAmount');
      final loanAccount = _value('loanAccountNumber');
      final engine = _value('engineNumber');
      final contact1 = _value('contactPerson1Phone');
      final contact2 = _value('contactPerson2Phone');
      final contact3 = _value('contactPerson3Phone');

      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xff0B1220)
            : Colors.transparent,
        body: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                width: MediaQuery.of(context).size.width * .94,
                height: MediaQuery.of(context).size.height * .88,
                decoration: BoxDecoration(
                  color: const Color(0xffF8FAFC),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.30),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Column(
                    children: [
                      // HEADER
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xff06162D), Color(0xff123B78)],
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'VEHICLE DETAILS',
                                    style: AppTextStyles.mono(
                                      size: 11,
                                      weight: FontWeight.w800,
                                      color: Colors.white.withOpacity(.65),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: widget.onClose,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(.12),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutBack,
                              builder: (context, value, child) {
                                return Transform.scale(scale: value, child: child);
                              },
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.12),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: Colors.white.withOpacity(.15)),
                                ),
                                child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 36),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              vehicle,
                              style: AppTextStyles.mono(size: 22, weight: FontWeight.w800, color: Colors.white),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '$brand • $model',
                              style: AppTextStyles.body(size: 12, color: Colors.white.withOpacity(.65)),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.gold400.withOpacity(.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.gold400,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // BODY
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              _popupSection('Customer Information', Icons.person_outline),
                              const SizedBox(height: 10),
                              _detailCard([
                                (Icons.person_outline, 'Customer Name', customer),
                                (Icons.location_on_outlined, 'Address', address),
                                (Icons.call_outlined, 'Contact 1', contact1),
                                (Icons.call_outlined, 'Contact 2', contact2),
                                (Icons.call_outlined, 'Contact 3', contact3),
                              ]),
                              const SizedBox(height: 20),
                              _popupSection('Vehicle Information', Icons.directions_car_outlined),
                              const SizedBox(height: 10),
                              _detailCard([
                                (Icons.directions_car_outlined, 'Vehicle Number', vehicle),
                                (Icons.confirmation_number_outlined, 'Chassis Number', chassis),
                                (Icons.settings_outlined, 'Engine Number', engine),
                                (Icons.category_outlined, 'Brand', brand),
                                (Icons.car_repair_outlined, 'Model', model),
                              ]),
                              const SizedBox(height: 20),
                              _popupSection('Finance Information', Icons.account_balance_wallet_outlined),
                              const SizedBox(height: 10),
                              _detailCard([
                                (Icons.account_balance_outlined, 'Bank', bank),
                                (Icons.account_tree_outlined, 'Branch', branch),
                                (Icons.receipt_long_outlined, 'Loan Account No.', loanAccount),
                                (Icons.currency_rupee, 'EMI Amount', '₹$emi'),
                                (Icons.money_off_csred_outlined, 'Due Amount', '₹$due'),
                                (Icons.account_balance_wallet_outlined, 'Outstanding', '₹$outstanding'),
                              ]),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    Widget _popupSection(String title, IconData icon) {
      return Row(
        children: [
          Icon(icon, size: 18, color: AppColors.blue600),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy950),
          ),
        ],
      );
    }

    Widget _detailCard(List<(IconData, String, String)> details) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffE2E8F0)),
        ),
        child: Column(
          children: details.map((detail) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.blue600.withOpacity(.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(detail.$1, size: 17, color: AppColors.blue600),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.$2.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate400,
                            letterSpacing: .5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          detail.$3,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy950),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }
  }