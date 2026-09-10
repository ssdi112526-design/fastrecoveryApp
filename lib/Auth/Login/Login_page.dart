import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../Service/SharedPreferenceService.dart';
import '../../Widget/Common_widget.dart';
import '../../theme/app_theme.dart';
import '../Forgetpassword_screen.dart';
import '../Sign_up option/GEt_start.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _AuthTab { login, register }

class _LoginScreenState extends State<LoginScreen> {
  _AuthTab _selectedTab = _AuthTab.login;

  bool _remember = false;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _emailError;
  String? _passwordError;

  static const String _loginUrl =
      'https://www.fastrecovery.in/api/auth/repo-agent-login';

  // Premium palette (matches the FastRecovery wordmark)
  static const Color _navy = Color(0xFF0C1220);
  static const Color _blueStart = Color(0xFF38B6FF);
  static const Color _blueEnd = Color(0xFF1D3FAE);
  static const LinearGradient _brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_blueStart, _blueEnd],
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    isDark ? const Color(0xff9CAAC4) : const Color(0xff000000);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _launchUrl(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.blue600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _validateFields() {
    String? emailErr;
    String? passwordErr;

    final idOrMobile = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (idOrMobile.isEmpty) {
      emailErr = 'Agency ID or mobile number is required';
    } else {
      final isAllDigits = RegExp(r'^[0-9]+$').hasMatch(idOrMobile);
      if (isAllDigits) {
        if (idOrMobile.length != 10) {
          emailErr = 'Mobile number must be exactly 10 digits';
        }
      } else {
        if (idOrMobile.length < 4) {
          emailErr = 'Enter a valid Agency ID (e.g. KAR1111)';
        }
      }
    }

    if (password.isEmpty) {
      passwordErr = 'Password is required';
    } else if (password.length < 6) {
      passwordErr = 'Password must be at least 6 characters';
    }

    setState(() {
      _emailError = emailErr;
      _passwordError = passwordErr;
    });

    return emailErr == null && passwordErr == null;
  }

  Future<void> _login() async {
    if (!_validateFields()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final body = {
      "email": _emailController.text.trim(),
      "password": _passwordController.text.trim(),
    };

    try {
      final response = await http
          .post(
        Uri.parse(_loginUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 20));

      Map<String, dynamic> decoded;
      try {
        decoded = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        if (mounted) _showMessage('Invalid server response. Please try again.');
        return;
      }

      if (response.statusCode == 200 && decoded['success'] == true) {
        final data = decoded['data'];
        if (data == null || data is! Map) {
          if (mounted) _showMessage('Invalid login response from server.');
          return;
        }

        final token = data['token']?.toString().trim();
        final user = data['user'];

        if (token == null || token.isEmpty) {
          if (mounted) _showMessage('Login successful but token not received.');
          return;
        }

        await SharedPreferenceService.setString('token', token);

        if (user != null && user is Map) {
          await SharedPreferenceService.setString('userName', user['name']?.toString() ?? 'User');
          await SharedPreferenceService.setString('userRole', user['role']?.toString() ?? '');
          await SharedPreferenceService.setString('userEmail', user['email']?.toString() ?? '');
          await SharedPreferenceService.setString('companyName', user['companyName']?.toString() ?? 'Your Agency');
          await SharedPreferenceService.setString('companyCode', user['companyCode']?.toString() ?? '');
        }

        await SharedPreferenceService.setBool('remember_me', _remember);

        if (!mounted) return;
        FocusScope.of(context).unfocus();

        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        final message = decoded['message']?.toString() ?? 'Invalid credentials';
        if (mounted) _showMessage(message);
      }
    } on TimeoutException {
      if (mounted) _showMessage('Server is taking too long. Please try again.');
    } catch (e, stackTrace) {
      debugPrint('LOGIN ERROR: $e\n$stackTrace');
      if (mounted) _showMessage('Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _errorText(String? error) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 5, left: 2),
      child: Text(
        error,
        style: AppTextStyles.body(size: 11.5, color: Colors.redAccent)
            .copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  // =========================
  // ANIMATED TAB TOGGLE (premium pill w/ gradient)
  // =========================
  Widget _authTabToggle() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _navy.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = (constraints.maxWidth - 8) / 2;

          return Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: _selectedTab == _AuthTab.login
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: tabWidth,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: _brandGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _blueEnd.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(child: _tabButton('Login', _AuthTab.login)),
                  Expanded(child: _tabButton('Register', _AuthTab.register)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tabButton(String label, _AuthTab tab) {
    final bool isSelected = _selectedTab == tab;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_selectedTab == tab) return;
        FocusScope.of(context).unfocus();
        setState(() => _selectedTab = tab);
      },
      child: SizedBox(
        height: 42,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: AppTextStyles.body(
              size: 14.5,
              weight: FontWeight.w700,
              color: isSelected ? Colors.white : AppColors.slate600,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  // =========================
  // ANIMATED SWITCHER
  // =========================
  Widget _buildAnimatedSwitcher() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final bool isIncoming = child.key == ValueKey(_selectedTab);
        final offsetTween = Tween<Offset>(
          begin: Offset(isIncoming ? 0.15 : -0.15, 0),
          end: Offset.zero,
        );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(offsetTween),
            child: child,
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: _selectedTab == _AuthTab.login
          ? _loginForm(key: const ValueKey(_AuthTab.login))
          : GetStartedScreenBody(
        key: const ValueKey(_AuthTab.register),
        showBackRow: false,
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    final mutedText =
    isDark ? const Color(0xff6B7893) : const Color(0xff94A3B8);

    final currentYear = DateTime.now().year;

    return Column(
      // mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Developed By: Software Solutions Development India',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: Colors.black,
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
          'Copyright © $currentYear SSDI All rights reserved.',
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

  // =========================
  // PREMIUM CARD WRAPPER
  // =========================
  Widget _card({required Widget child, Key? key}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }


  // =========================
  // LOGIN FORM
  // =========================
  Widget _loginForm({Key? key}) {
    return _card(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: _emailController,
            label: 'Agency ID / Mobile',
            hint: ' Email or mobile',
            icon: Icons.person_outline_rounded,
          ),
          _errorText(_emailError),

          const SizedBox(height: 16),

          AppTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Enter password',
            icon: Icons.lock_outline_rounded,
            obscure: true,
            showToggle: true,
          ),
          _errorText(_passwordError),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _remember,
                      onChanged: (value) => setState(() => _remember = value ?? false),
                      activeColor: _blueEnd,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Remember me',
                    style: AppTextStyles.body(size: 13, color: AppColors.slate600),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                  );
                },
                child: Text(
                  'Forgot password?',
                  style: AppTextStyles.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.gold500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Premium gradient button
          _GradientButton(
            gradient: _brandGradient,
            label: _isLoading ? 'Please wait...' : 'Log In',
            loading: _isLoading,
            onTap: _isLoading ? null : _login,
          ),

          const SizedBox(height: 20),

          // Center(
          //   child: GestureDetector(
          //     onTap: () {
          //       FocusScope.of(context).unfocus();
          //       setState(() => _selectedTab = _AuthTab.register);
          //     },
          //     child: Wrap(
          //       children: [
          //         Text(
          //           'New agency? ',
          //           style: AppTextStyles.body(size: 13.5, color: AppColors.slate600),
          //         ),
          //         Text(
          //           'Self-register with company code',
          //           style: AppTextStyles.body(
          //             size: 13.5,
          //             weight: FontWeight.w700,
          //             color: _blueEnd,
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // =========================
            // HEADER
            // =========================
            Container(
              width: double.infinity,
              height: 200,
              decoration:  BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Color(0xFFFFFFFF),
                    Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      "assets/images/fastrecovery_logo-2.png",
                      width: 230,
                      //height: 70,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _selectedTab == _AuthTab.login
                          ? 'Sign in to your agency workspace '
                          : 'Register your company or join with a code',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(
                        size: 18.5,
                        color: Colors.black.withOpacity(0.70),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // =========================
            // MAIN CONTENT
            // =========================
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  22,
                  20,
                  20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _authTabToggle(),

                    const SizedBox(height: 22),

                    _buildAnimatedSwitcher(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // =========================
            // FIXED FOOTER
            // =========================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              color: const Color(0xFFF4F7FC),
              child: _buildFooter(false),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================
// REUSABLE PREMIUM GRADIENT BUTTON
// =========================
class _GradientButton extends StatelessWidget {
  final Gradient gradient;
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _GradientButton({
    required this.gradient,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap == null
              ? []
              : [
            BoxShadow(
              color: const Color(0xFF1D3FAE).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
              : Text(
            label,
            style: AppTextStyles.body(
              size: 15.5,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}