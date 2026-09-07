import 'package:flutter/material.dart';
import '../Widget/Common_widget.dart';
import '../theme/app_theme.dart';
import 'OTP-page.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AuthHero(
              title: 'Forgot password',
              subtitle: "We'll send a code to reset it",
              showBack: true,
              onBack: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppTextField(
                    label: 'Registered Mobile / Email',
                    hint: 'Mobile number or email',
                    icon: Icons.mail_outline_rounded,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A 6-digit verification code will be sent for confirmation.',
                    style: AppTextStyles.body(size: 11.5, color: AppColors.slate600),
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    label: 'Send OTP',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OtpScreen(fromSignup: false)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
