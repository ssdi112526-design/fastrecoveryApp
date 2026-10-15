import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../Service/SharedPreferenceService.dart';
import '../Widget/Common_widget.dart';
import '../theme/app_theme.dart';
import 'Succes_screen.dart';

class NewPasswordScreen extends StatefulWidget {
  final String? token;
  final String userId;

  const NewPasswordScreen({
    super.key,
    required this.token,
    required this.userId,
  });

  @override
  State<NewPasswordScreen> createState() =>
      _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  static const String _resetUrl =
      'https://fastrecovery.in/api/auth/forgot-password/reset';

  String _password = '';
  String _confirmPassword = '';

  bool _isLoading = false;

  bool get _hasLen => _password.length >= 8;

  bool get _hasUpper =>
      RegExp(r'[A-Z]').hasMatch(_password);

  bool get _hasNum =>
      RegExp(r'[0-9!@#$%^&*]').hasMatch(_password);

  int get _score =>
      [_hasLen, _hasUpper, _hasNum].where((e) => e).length;

  double get _pct {
    if (_password.isEmpty) return 0.08;
    return [0.30, 0.55, 0.80, 1.0][_score];
  }

  Color get _barColor {
    if (_password.isEmpty || _score <= 1) {
      return AppColors.danger;
    }
    if (_score == 2) return AppColors.gold500;
    return AppColors.success;
  }

  String get _label {
    if (_password.isEmpty) return 'Password strength';
    if (_score <= 1) return 'Weak password';
    if (_score == 2) return 'Good, add one more';
    return 'Strong password';
  }

  void _showMessage(
      String message, {
        bool error = true,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
          error ? AppColors.danger : AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _resetPassword() async {
    if (_isLoading) return;

    // Read the saved token.
    final resetToken =
    (widget.token ?? SharedPreferenceService.getToken() ?? '')
        .trim();

    debugPrint('[RESET DEBUG] Starting password reset');
    debugPrint('[RESET DEBUG] User ID: ${widget.userId}');
    debugPrint('[RESET DEBUG] Token available: ${resetToken.isNotEmpty}');
    debugPrint('[RESET DEBUG] Password length: ${_password.length}');
    debugPrint(
      '[RESET DEBUG] Confirm password matches: '
          '${_password == _confirmPassword}',
    );

    if (resetToken.isEmpty) {
      _showMessage(
        'Reset token missing. Please request a new password reset.',
      );
      return;
    }

    if (_password.length < 8) {
      _showMessage('Password must contain at least 8 characters.');
      return;
    }

    if (_confirmPassword.isEmpty) {
      _showMessage('Please confirm your new password.');
      return;
    }

    if (_password != _confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse(
        'https://fastrecovery.in/api/auth/forgot-password/reset',
      );

      debugPrint('[RESET DEBUG] POST $uri');

      final response = await http
          .post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'resetToken': resetToken,
          'newPassword': _password,
        }),
      )
          .timeout(const Duration(seconds: 30));

      debugPrint(
        '[RESET DEBUG] HTTP status: ${response.statusCode}',
      );

      Map<String, dynamic> result = {};

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          result = decoded;
        }
      } on FormatException {
        debugPrint('[RESET DEBUG] Response is not valid JSON');
      }

      // Do not print the token, password, or full response.
      debugPrint(
        '[RESET DEBUG] API success: ${result['success']}',
      );
      debugPrint(
        '[RESET DEBUG] API message: ${result['message']}',
      );

      if (!mounted) return;

      final success = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          result['success'] == true;

      if (success) {
        debugPrint('[RESET DEBUG] Password reset successful');

        _showMessage(
          result['message']?.toString() ??
              'Password updated successfully.',
          error: false,
        );

        // Remove the saved token only after successful reset.
        await SharedPreferenceService.removeToken();

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const SuccessScreen(),
          ),
        );
      } else {
        final message = result['message']?.toString();

        debugPrint('[RESET DEBUG] Password reset failed');

        _showMessage(
          message != null && message.isNotEmpty
              ? message
              : 'Unable to reset password. HTTP ${response.statusCode}',
        );
      }
    } on TimeoutException {
      debugPrint('[RESET DEBUG] Request timed out');
      _showMessage('Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      debugPrint('[RESET DEBUG] Network error: $e');
      _showMessage(
        'Network error. Please check your internet connection.',
      );
    } catch (e, stackTrace) {
      debugPrint('[RESET DEBUG] Unexpected error: $e');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                padding: const EdgeInsets.fromLTRB(
                  24, 26, 24, 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      label: 'New Password',
                      hint: 'Enter new password',
                      icon: Icons.lock_outline_rounded,
                      obscure: true,
                      showToggle: true,
                      onChanged: (v) {
                        setState(() => _password = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _pct,
                        minHeight: 5,
                        backgroundColor: AppColors.slate200,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(
                          _barColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _label,
                      style: AppTextStyles.body(
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: AppColors.slate600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Confirm Password',
                      hint: 'Re-enter password',
                      icon: Icons.check_circle_outline_rounded,
                      obscure: true,
                      showToggle: true,
                      onChanged: (v) {
                        setState(() => _confirmPassword = v);
                      },
                    ),
                    const SizedBox(height: 14),
                    _requirement(
                      'At least 8 characters',
                      _hasLen,
                    ),
                    const SizedBox(height: 6),
                    _requirement(
                      'One uppercase letter',
                      _hasUpper,
                    ),
                    const SizedBox(height: 6),
                    _requirement(
                      'One number or symbol',
                      _hasNum,
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: _isLoading
                          ? 'Resetting Password...'
                          : 'Reset Password',
                      icon: null,
                      gold: true,
                      onTap: _isLoading
                          ? () {}
                          : _resetPassword,
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 14),
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ],
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
            color: met
                ? AppColors.success
                : Colors.transparent,
            border: Border.all(
              color: met
                  ? AppColors.success
                  : AppColors.slate200,
              width: 1.5,
            ),
          ),
          child: met
              ? const Icon(
            Icons.check,
            size: 9,
            color: Colors.white,
          )
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: AppTextStyles.body(
            size: 12,
            weight:
            met ? FontWeight.w600 : FontWeight.w400,
            color:
            met ? AppColors.ink : AppColors.slate600,
          ),
        ),
      ],
    );
  }
}
