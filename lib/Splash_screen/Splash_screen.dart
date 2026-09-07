import 'package:flutter/material.dart';
import '../Service/SharedPreferenceService.dart';
import '../../theme/app_theme.dart';
import 'Onbording_screens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() =>
      _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _barController;
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();

    // Progress bar
    _barController = AnimationController(
      vsync: this,
      duration:
      const Duration(milliseconds: 2500),
    )..forward();

    // Fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration:
      const Duration(milliseconds: 1200),
    )..forward();

    // Check login after splash
    _checkLogin();
  }

  // =========================
  // CHECK LOGIN
  // =========================
  Future<void> _checkLogin() async {

    // Same splash duration
    await Future.delayed(
      const Duration(milliseconds: 3000),
    );

    if (!mounted) return;

    // IMPORTANT:
    // Read SAME KEY that LoginScreen saves
    final token =
    SharedPreferenceService.getString('token');

    debugPrint(
      'SPLASH TOKEN: $token',
    );

    final bool isLoggedIn =
        token != null &&
            token.trim().isNotEmpty;

    if (!mounted) return;

    // =========================
    // ALREADY LOGGED IN
    // =========================
    if (isLoggedIn) {

      debugPrint(
        'USER ALREADY LOGGED IN → HOME',
      );

      Navigator.pushReplacementNamed(
        context,
        '/home',
      );

    }

    // =========================
    // FIRST TIME USER
    // =========================
    else {

      debugPrint(
        'NO TOKEN → ONBOARDING',
      );

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration:
          const Duration(milliseconds: 450),

          pageBuilder:
              (_, __, ___) =>
          const OnboardingScreen(),

          transitionsBuilder:
              (_, animation, __, child) =>
              FadeTransition(
                opacity: animation,
                child: child,
              ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _barController.dispose();
    _fadeController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy950,

      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center:
            Alignment(-0.2, -0.8),
            radius: 1.1,
            colors: [
              Color(0xFF1C3260),
              AppColors.navy950,
            ],
          ),
        ),

        child: Stack(
          children: [

            // =========================
            // CENTER CONTENT
            // =========================
            Align(
              alignment: Alignment.center,

              child: Padding(
                padding:
                const EdgeInsets.only(
                  left: 30,
                  right: 30,
                ),

                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,

                  crossAxisAlignment:
                  CrossAxisAlignment.center,

                  children: [

                    SizedBox(
                      width: 150,
                      height: 190,

                      child: Image.asset(
                        'assets/images/kartik_agency.png',
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 36),

                    FadeTransition(
                      opacity:
                      _fadeController,

                      child: RichText(
                        textAlign:
                        TextAlign.center,

                        text: TextSpan(
                          style:
                          AppTextStyles.display(
                            size: 22,
                            weight:
                            FontWeight.w700,
                            color:
                            Colors.white,
                          ),

                          children: [
                            const TextSpan(
                              text: 'KARTIK\n',
                            ),

                            TextSpan(
                              text:
                              'REPOSSESSION AGENCY',

                              style: TextStyle(
                                color:
                                AppColors.gold400,
                                fontWeight:
                                FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    FadeTransition(
                      opacity:
                      _fadeController,

                      child: Text(
                        'TRACK · TRACE · RECOVER',

                        textAlign:
                        TextAlign.center,

                        style:
                        AppTextStyles.mono(
                          size: 11.5,
                          color:
                          AppColors.slate400,
                        ).copyWith(
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // =========================
            // PROGRESS BAR
            // =========================
            Positioned(
              bottom: 64,
              left: 30,
              right: 30,

              child: Container(
                width: 140,
                height: 3,

                decoration:
                BoxDecoration(
                  color: Colors.white
                      .withOpacity(0.12),

                  borderRadius:
                  BorderRadius.circular(3),
                ),

                child: AnimatedBuilder(
                  animation:
                  _barController,

                  builder: (_, __) =>
                      Align(
                        alignment:
                        Alignment.centerLeft,

                        child:
                        FractionallySizedBox(
                          widthFactor:
                          _barController.value,

                          child: Container(
                            decoration:
                            BoxDecoration(
                              borderRadius:
                              BorderRadius.circular(
                                3,
                              ),

                              gradient:
                              const LinearGradient(
                                colors: [
                                  AppColors.blue500,
                                  AppColors.gold400,
                                ],
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
      ),
    );
  }
}