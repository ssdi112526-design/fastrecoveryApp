import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'Agent_sign_up.dart';
import 'Company_Signup.dart';

/// Thin wrapper so any existing Navigator.push(... GetStartedScreen()) calls
/// elsewhere in the app still work unchanged.
class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: GetStartedScreenBody(showBackRow: true),
      ),
    );
  }
}

/// The actual "Get started / Register" content, with NO Scaffold of its
/// own, so it can be dropped into AuthTabScreen directly.
class GetStartedScreenBody extends StatelessWidget {
  /// When embedded inside AuthTabScreen the "Back to login portal" row is
  /// redundant (the toggle already does that job), so it's hidden by
  /// default there and only shown when used as a standalone pushed screen.
  final bool showBackRow;

  const GetStartedScreenBody({
    super.key, this.showBackRow = false});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   'Get started with Fast Recovery',
          //   style: AppTextStyles.display(
          //     size: 20,
          //     weight: FontWeight.w800,
          //     color: AppColors.navy950,
          //   ),
          // ),
          //const SizedBox(height: 14),
          Text(
            // 'Install the APK and register here. '
            //     'New companies need SSDI approval after payment (offline or online). '
            //     'Agents join with a company code from their repo admin.',
            "Install, register, and get SSDI approval. Agents can join using their company code.",
            style: AppTextStyles.body(
              size: 14.5,
              color: AppColors.slate600,
            ).copyWith(height: 1.5),
          ),
          const SizedBox(height: 28),
          _OptionCard(
            icon: Icons.work_outline_rounded,
            title: 'Register a new company',
            description:
            'Create your repo company and admin account. Status stays pending until payment is confirmed and SSDI activates you.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SignupScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _OptionCard(
            icon: Icons.person_add_alt_1_outlined,
            title: 'Join as repo user / agent',
            description:
            'Use the company code from your repo admin. Your account stays inactive until the admin activates you.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AgentRegisterScreen()),
            ),
          ),
          if (showBackRow) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded,
                      size: 16, color: AppColors.blue600),
                  const SizedBox(width: 6),
                  Text(
                    'Back to login portal',
                    style: AppTextStyles.body(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: AppColors.blue600,
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
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.slate200, width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.blue600.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 21, color: AppColors.blue600),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.display(
                      size: 18.5,
                      weight: FontWeight.w700,
                      color: AppColors.navy950,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: AppTextStyles.body(
                      size: 12,
                      color: AppColors.slate600,
                    ).copyWith(height: 1.4),
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