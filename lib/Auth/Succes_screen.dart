import 'package:flutter/material.dart';
import '../Widget/Common_widget.dart';
import '../theme/app_theme.dart';
import 'Login/Login_page.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) => Transform.scale(
                    scale: value,
                    child: child,
                  ),
                  child: Container(
                    width: 74,
                    height: 74,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success.withOpacity(0.12),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 26),
                    ),
                  ),
                ),
                Text('Password updated',
                    style: AppTextStyles.display(size: 22, weight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text(
                  'Your password has been reset successfully. Use it the next time you log in.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(size: 14, color: AppColors.slate600).copyWith(height: 1.6),
                ),
                const SizedBox(height: 26),
                PrimaryButton(
                  label: 'Back to Log In',
                  icon: null,
                  expand: false,
                  onTap: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
