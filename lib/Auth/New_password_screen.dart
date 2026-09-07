import 'package:flutter/material.dart';
import '../Widget/Common_widget.dart';
import '../theme/app_theme.dart';
import 'Succes_screen.dart';

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  String _password = '';

  bool get _hasLen => _password.length >= 8;
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(_password);
  bool get _hasNum => RegExp(r'[0-9!@#$%^&*]').hasMatch(_password);

  int get _score => [_hasLen, _hasUpper, _hasNum].where((e) => e).length;

  double get _pct {
    if (_password.isEmpty) return 0.08;
    return [0.30, 0.55, 0.80, 1.0][_score.clamp(0, 3)];
  }

  Color get _barColor {
    if (_password.isEmpty || _score <= 1) return AppColors.danger;
    if (_score == 2) return AppColors.gold500;
    return AppColors.success;
  }

  String get _label {
    if (_password.isEmpty) return 'Password strength';
    if (_score <= 1) return 'Weak password';
    if (_score == 2) return 'Good, add one more';
    return 'Strong password';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AuthHero(
              title: 'Set new password',
              subtitle: 'Make it strong and easy to remember',
              showBack: true,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      label: 'New Password',
                      hint: 'Enter new password',
                      icon: Icons.lock_outline_rounded,
                      obscure: true,
                      showToggle: true,
                      onChanged: (v) => setState(() => _password = v),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _pct,
                        minHeight: 5,
                        backgroundColor: AppColors.slate200,
                        valueColor: AlwaysStoppedAnimation(_barColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(_label,
                        style: AppTextStyles.body(
                            size: 11.5, weight: FontWeight.w600, color: AppColors.slate600)),
                    const SizedBox(height: 16),
                    const AppTextField(
                      label: 'Confirm Password',
                      hint: 'Re-enter password',
                      icon: Icons.check_circle_outline_rounded,
                      obscure: true,
                    ),
                    const SizedBox(height: 14),
                    _requirement('At least 8 characters', _hasLen),
                    const SizedBox(height: 6),
                    _requirement('One uppercase letter', _hasUpper),
                    const SizedBox(height: 6),
                    _requirement('One number or symbol', _hasNum),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: 'Reset Password',
                      icon: null,
                      gold: true,
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const SuccessScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requirement(String text, bool met) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: met ? AppColors.success : Colors.transparent,
            border: Border.all(
              color: met ? AppColors.success : AppColors.slate200,
              width: 1.5,
            ),
          ),
          child: met
              ? const Icon(Icons.check, size: 9, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: AppTextStyles.body(
            size: 12,
            weight: met ? FontWeight.w600 : FontWeight.w400,
            color: met ? AppColors.ink : AppColors.slate600,
          ),
        ),
      ],
    );
  }
}
