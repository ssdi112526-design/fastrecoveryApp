import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../Widget/Common_widget.dart';
import '../../theme/app_theme.dart';

class AgentRegisterScreen extends StatefulWidget {
  const AgentRegisterScreen({super.key});

  @override
  State<AgentRegisterScreen> createState() => _AgentRegisterScreenState();
}

class _AgentRegisterScreenState extends State<AgentRegisterScreen> {
  bool _isLoading = false;

  final TextEditingController _companyCodeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // value sent to the API
  String _role = 'REPO_STAFF';

  final List<Map<String, String>> _roles = const [
    {'label': 'Repo Staff', 'value': 'REPO_STAFF'},
    {'label': 'Team Leader', 'value': 'TEAM_LEADER'},
    {'label': 'Field Agent', 'value': 'HEAD OFFICE STAFF'},
    {'label': 'Field Agent', 'value': 'OFFICE STAFF'},
  ];

  String? _companyCodeError;
  String? _nameError;
  String? _emailError;
  String? _mobileError;
  String? _passwordError;

  static const String _registerUrl =
      'https://www.fastrecovery.in/api/auth/agent-register';

  static final RegExp _emailRegex =
  RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');
  static final RegExp _tenDigitRegex = RegExp(r'^[0-9]{10}$');

  @override
  void dispose() {
    _companyCodeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateFields() {
    String? companyCodeErr;
    String? nameErr;
    String? emailErr;
    String? mobileErr;
    String? passwordErr;

    final companyCode = _companyCodeController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final mobile = _mobileController.text.trim();
    final password = _passwordController.text.trim();

    if (companyCode.isEmpty) {
      companyCodeErr = 'Company code is required';
    } else if (companyCode.length < 4) {
      companyCodeErr = 'Enter a valid company code (e.g. HIM1114)';
    }

    if (name.isEmpty) {
      nameErr = 'Full name is required';
    } else if (name.length < 3) {
      nameErr = 'Full name must be at least 3 characters';
    }

    if (email.isEmpty) {
      emailErr = 'Email is required';
    } else if (!_emailRegex.hasMatch(email)) {
      emailErr = 'Enter a valid email address';
    }

    if (mobile.isEmpty) {
      mobileErr = 'Mobile number is required';
    } else if (!_tenDigitRegex.hasMatch(mobile)) {
      mobileErr = 'Enter a valid 10-digit mobile number';
    }

    if (password.isEmpty) {
      passwordErr = 'Password is required';
    } else if (password.length < 6) {
      passwordErr = 'Password must be at least 6 characters';
    }

    setState(() {
      _companyCodeError = companyCodeErr;
      _nameError = nameErr;
      _emailError = emailErr;
      _mobileError = mobileErr;
      _passwordError = passwordErr;
    });

    return companyCodeErr == null &&
        nameErr == null &&
        emailErr == null &&
        mobileErr == null &&
        passwordErr == null;
  }

  Future<void> _registerAgent() async {
    if (!_validateFields()) {
      _showMessage('Please fix the highlighted fields');
      return;
    }

    setState(() => _isLoading = true);

    final body = {
      "companyCode": _companyCodeController.text.trim(),
      "name": _nameController.text.trim(),
      "email": _emailController.text.trim(),
      "phone": _mobileController.text.trim(),
      "password": _passwordController.text.trim(),
      "role": _role,
    };

    try {
      final response = await http.post(
        Uri.parse(_registerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final decoded = jsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          decoded['success'] == true) {
        final message = decoded['data']?['message'] ??
            decoded['message'] ??
            'Registration submitted';
        _showMessage(message);

        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        _showMessage(decoded['message'] ?? 'Registration failed');
      }
    } catch (e) {
      _showMessage('Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

  // Widget _fieldLabel(String label) {
  //   return RichText(
  //     text: TextSpan(
  //       style: AppTextStyles.display(
  //           size: 14, weight: FontWeight.w700, color: AppColors.navy950),
  //       children: const [
  //         TextSpan(text: ''),
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                "assets/images/fastrecovery_logo-2.png",
                width: 230,
                //height: 70,
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
              Text(
                'Agent self-registration',
                style: AppTextStyles.display(
                  size: 24,
                  weight: FontWeight.w800,
                  color: AppColors.navy950,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Register with your company code from the repo admin. Your account stays inactive until the admin activates it.',
                style: AppTextStyles.body(size: 14.5, color: AppColors.slate600)
                    .copyWith(height: 1.5),
              ),
              const SizedBox(height: 26),

              AppTextField(
                controller: _companyCodeController,
                label: 'Company code *',
                hint: 'e.g. HIM1114',
                icon: Icons.confirmation_number_outlined,
              ),
              _errorText(_companyCodeError),
              const SizedBox(height: 18),

              AppTextField(
                controller: _nameController,
                label: 'Full name *',
                hint: 'Enter full name',
                icon: Icons.person_outline_rounded,
              ),
              _errorText(_nameError),
              const SizedBox(height: 18),

              AppTextField(
                controller: _emailController,
                label: 'Email *',
                hint: 'agent@email.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              _errorText(_emailError),
              const SizedBox(height: 18),

              AppTextField(
                controller: _mobileController,
                label: 'Mobile *',
                hint: '10-digit mobile number',
                icon: Icons.phone_iphone_rounded,
                keyboardType: TextInputType.phone,
              ),
              _errorText(_mobileError),
              const SizedBox(height: 18),

              AppTextField(
                controller: _passwordController,
                label: 'Password *',
                hint: 'Create a password',
                icon: Icons.lock_outline_rounded,
                obscure: true,
                showToggle: true,
              ),
              _errorText(_passwordError),
              const SizedBox(height: 18),

              Text('Role',
                  style: AppTextStyles.body(
                      size: 10.5, weight: FontWeight.w700, color: AppColors.slate600)
                      .copyWith(letterSpacing: 0.7)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.blue500, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(dropdownColor: Colors.white,
                    value: _role,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    items: _roles
                        .map(
                          (r) => DropdownMenuItem<String>(
                        value: r['value'],
                        child: Text(
                          r['label']!,
                          style: AppTextStyles.body(size: 13.5),
                        ),
                      ),
                    )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _role = v);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.slate200,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Back to login',
                      style: AppTextStyles.body(
                          size: 13.5, weight: FontWeight.w700, color: AppColors.navy950),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _registerAgent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue600,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      _isLoading ? 'Please wait...' : 'Register',
                      style: AppTextStyles.body(
                          size: 13.5, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}