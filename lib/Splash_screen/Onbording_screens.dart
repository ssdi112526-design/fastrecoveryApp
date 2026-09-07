import 'package:flutter/material.dart';
import '../Auth/Login/Login_page.dart';
import '../Widget/Common_widget.dart';
import '../theme/app_theme.dart';

class _ObSlide {
  final IconData icon;
  final String title;
  final String desc;
  const _ObSlide(this.icon, this.title, this.desc);
}

const _slides = [
  _ObSlide(
    Icons.search_rounded,
    'Find any vehicle\nin seconds',
    'Search by vehicle number, mobile, or chassis ID and pull up the full case in one tap.',
  ),
  _ObSlide(
    Icons.location_on_outlined,
    'Live field\ntracking',
    'Follow your agents in real time on the map, from dispatch to recovery.',
  ),
  _ObSlide(
    Icons.shield_outlined,
    'Secure, role-based\naccess',
    'Banks, repo companies and field agents each see exactly what they need.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  void _goLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _next() {
    if (_index == _slides.length - 1) {
      _goLogin();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFFF5F8FC),
        body: Stack(
          children: [
          Positioned(
          top: -120,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.blue500.withOpacity(0.16),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        Positioned(
          bottom: -140,
          left: -100,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.gold400.withOpacity(0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

      SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 22, top: 8),
                child: TextButton(
                  onPressed: _goLogin,
                  child: Text('Skip',
                      style: AppTextStyles.body(
                          size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 34),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 172,
                          height: 172,
                          margin: const EdgeInsets.only(bottom: 34),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.navy800, AppColors.navy900],
                            ),
                            borderRadius: BorderRadius.circular(36),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.navy900.withOpacity(0.5),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Icon(s.icon, size: 62, color: AppColors.gold400),
                        ),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.display(size: 22, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.desc,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body(size: 14, color: AppColors.slate600)
                              .copyWith(height: 1.6),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 20),
                  width: active ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active ? AppColors.gold500 : AppColors.slate200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 30),
              child: PrimaryButton(
                label: _index == _slides.length - 1 ? 'Get Started' : 'Next',
                onTap: _next,
              ),
            ),
          ],
        ),
      ),
    ])
    );
  }
}
