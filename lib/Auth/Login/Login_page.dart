import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

class _LoginScreenState extends State<LoginScreen> {
  bool _remember = false;
  bool _isLoading = false;

  final TextEditingController _emailController =
  TextEditingController();

  final TextEditingController _passwordController =
  TextEditingController();

  String? _emailError;
  String? _passwordError;

  static const String _loginUrl =
      'https://www.fastrecovery.in/api/auth/repo-agent-login';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // =========================
  // VALIDATION
  // =========================
  bool _validateFields() {
    String? emailErr;
    String? passwordErr;

    final idOrMobile =
    _emailController.text.trim();

    final password =
    _passwordController.text.trim();

    if (idOrMobile.isEmpty) {
      emailErr =
      'Agency ID or mobile number is required';
    } else {
      final isAllDigits =
      RegExp(r'^[0-9]+$').hasMatch(idOrMobile);

      if (isAllDigits) {
        if (idOrMobile.length != 10) {
          emailErr =
          'Mobile number must be exactly 10 digits';
        }
      } else {
        if (idOrMobile.length < 4) {
          emailErr =
          'Enter a valid Agency ID (e.g. KAR1111)';
        }
      }
    }

    if (password.isEmpty) {
      passwordErr = 'Password is required';
    } else if (password.length < 6) {
      passwordErr =
      'Password must be at least 6 characters';
    }

    setState(() {
      _emailError = emailErr;
      _passwordError = passwordErr;
    });

    return emailErr == null &&
        passwordErr == null;
  }

  // =========================
  // LOGIN
  // =========================
  Future<void> _login() async {
    if (!_validateFields()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final body = {
      "email": _emailController.text.trim(),
      "password": _passwordController.text.trim(),
    };

    try {
      final response = await http.post(
        Uri.parse(_loginUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          decoded['success'] == true) {
        final data = decoded['data'];

        final token =
        data['token']?.toString();

        final user = data['user'];

        // =========================
        // SAVE LOGIN DATA
        // =========================
        if (token != null &&
            token.trim().isNotEmpty) {

          // IMPORTANT:
          // Same key that SplashScreen reads
          await SharedPreferenceService.setString(
            'token',
            token,
          );

          // Save user information
          if (user != null) {
            await SharedPreferenceService.setString(
              'userName',
              user['name']?.toString() ?? 'User',
            );

            await SharedPreferenceService.setString(
              'userRole',
              user['role']?.toString() ?? '',
            );

            await SharedPreferenceService.setString(
              'userEmail',
              user['email']?.toString() ?? '',
            );

            await SharedPreferenceService.setString(
              'companyName',
              user['companyName']?.toString() ??
                  'Your Agency',
            );

            await SharedPreferenceService.setString(
              'companyCode',
              user['companyCode']?.toString() ?? '',
            );
          }

          // Remember me
          await SharedPreferenceService.setBool(
            'remember_me',
            _remember,
          );

          // Debug
          debugPrint(
            'LOGIN TOKEN SAVED: $token',
          );

          _showMessage(
            decoded['message'] ??
                'Login successful',
          );

          // =========================
          // GO HOME
          // =========================
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/home',
            );
          }
        } else {
          _showMessage(
            'Login successful but token not received.',
          );
        }
      } else {
        _showMessage(
          decoded['message'] ??
              'Invalid credentials',
        );
      }
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');

      _showMessage(
        'Network error. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =========================
  // SNACKBAR
  // =========================
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // =========================
  // ERROR TEXT
  // =========================
  Widget _errorText(String? error) {
    if (error == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(
        top: 5,
        left: 2,
      ),
      child: Text(
        error,
        style: AppTextStyles.body(
          size: 11.5,
          color: Colors.redAccent,
        ).copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,

      body: SafeArea(
        bottom: false,

        child: Column(
          children: [
            const AuthHero(
              title: 'Welcome back',
              subtitle:
              'Sign in to your agency workspace',
              height: 210,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.fromLTRB(
                  24,
                  26,
                  24,
                  24,
                ),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    AppTextField(
                      controller:
                      _emailController,
                      label:
                      'Agency ID / Mobile',
                      hint: ' Email or mobile',
                      icon:
                      Icons.person_outline_rounded,
                    ),

                    _errorText(_emailError),

                    const SizedBox(height: 16),

                    AppTextField(
                      controller:
                      _passwordController,
                      label: 'Password',
                      hint: 'Enter password',
                      icon:
                      Icons.lock_outline_rounded,
                      obscure: true,
                      showToggle: true,
                    ),

                    _errorText(
                      _passwordError,
                    ),

                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,

                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _remember,
                                onChanged: (value) {
                                  setState(() {
                                    _remember =
                                        value ?? false;
                                  });
                                },
                                activeColor:
                                AppColors.blue600,
                                shape:
                                RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                    4,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            Text(
                              'Remember me',
                              style:
                              AppTextStyles.body(
                                size: 13,
                                color:
                                AppColors.slate600,
                              ),
                            ),
                          ],
                        ),

                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                const ForgotPasswordScreen(),
                              ),
                            );
                          },

                          child: Text(
                            'Forgot password?',
                            style:
                            AppTextStyles.body(
                              size: 13,
                              weight:
                              FontWeight.w600,
                              color:
                              AppColors.gold500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    PrimaryButton(
                      label: _isLoading
                          ? 'Please wait...'
                          : 'Log In',

                      onTap: _isLoading
                          ? () {}
                          : _login,
                    ),

                    const SizedBox(height: 24),

                    Center(
                      child: Wrap(
                        children: [
                          Text(
                            'New agency? ',
                            style:
                            AppTextStyles.body(
                              size: 13.5,
                              color:
                              AppColors.slate600,
                            ),
                          ),

                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const GetStartedScreen(),
                                ),
                              );
                            },

                            child: Text(
                              'Self-register with company code',
                              style:
                              AppTextStyles.body(
                                size: 13.5,
                                weight:
                                FontWeight.w700,
                                color:
                                AppColors.blue600,
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
          ],
        ),
      ),
    );
  }
}