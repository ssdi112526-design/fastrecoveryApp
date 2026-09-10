import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../Widget/Common_widget.dart';
import '../../theme/app_theme.dart';
import '../OTP-page.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _agree = false;
  bool _isLoading = false;

  // ---- Controllers for fields already in UI ----
  final TextEditingController _agencyNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // ---- Controllers for fields required by API but missing from UI ----
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactPersonNameController = TextEditingController();
  final TextEditingController _adminNameController = TextEditingController();
  final TextEditingController _adminEmailController = TextEditingController();
  final TextEditingController _adminPhoneController = TextEditingController();
  final TextEditingController _adminDistrictController =
  TextEditingController();
  final TextEditingController _adminPincodeController =
  TextEditingController();
  final TextEditingController _adminPostController = TextEditingController();

  // ---- Error messages, one per field ----
  String? _agencyNameError;
  String? _phoneError;
  String? _emailError;
  String? _passwordError;
  String? _addressError;
  String? _contactPersonNameError;
  String? _adminNameError;
  String? _adminEmailError;
  String? _adminPhoneError;
  String? _adminDistrictError;
  String? _adminPincodeError;
  String? _adminPostError;

  static const String _registerUrl =
      'https://www.fastrecovery.in/api/companies/register';

  static final RegExp _emailRegex =
  RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');
  static final RegExp _tenDigitRegex = RegExp(r'^[0-9]{10}$');
  static final RegExp _pincodeRegex = RegExp(r'^[0-9]{6}$');

  @override
  void dispose() {
    _agencyNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _contactPersonNameController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPhoneController.dispose();
    _adminDistrictController.dispose();
    _adminPincodeController.dispose();
    _adminPostController.dispose();
    super.dispose();
  }

  // Returns true if every field is valid; also sets individual error messages.
  bool _validateFields() {
    String? agencyNameErr;
    String? phoneErr;
    String? emailErr;
    String? passwordErr;
    String? addressErr;
    String? contactPersonNameErr;
    String? adminNameErr;
    String? adminEmailErr;
    String? adminPhoneErr;
    String? adminDistrictErr;
    String? adminPincodeErr;
    String? adminPostErr;

    final agencyName = _agencyNameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final address = _addressController.text.trim();
    final contactPersonName = _contactPersonNameController.text.trim();
    final adminName = _adminNameController.text.trim();
    final adminEmail = _adminEmailController.text.trim();
    final adminPhone = _adminPhoneController.text.trim();
    final adminDistrict = _adminDistrictController.text.trim();
    final adminPincode = _adminPincodeController.text.trim();
    final adminPost = _adminPostController.text.trim();

    if (agencyName.isEmpty) {
      agencyNameErr = 'Agency name is required';
    } else if (agencyName.length < 3) {
      agencyNameErr = 'Agency name must be at least 3 characters';
    }

    if (phone.isEmpty) {
      phoneErr = 'Mobile number is required';
    } else if (!_tenDigitRegex.hasMatch(phone)) {
      phoneErr = 'Enter a valid 10-digit mobile number';
    }

    if (email.isEmpty) {
      emailErr = 'Email is required';
    } else if (!_emailRegex.hasMatch(email)) {
      emailErr = 'Enter a valid email address';
    }

    if (password.isEmpty) {
      passwordErr = 'Password is required';
    } else if (password.length < 6) {
      passwordErr = 'Password must be at least 6 characters';
    }

    if (address.isEmpty) {
      addressErr = 'Address is required';
    }

    if (contactPersonName.isEmpty) {
      contactPersonNameErr = 'Contact person name is required';
    }

    if (adminName.isEmpty) {
      adminNameErr = 'Admin name is required';
    }

    if (adminEmail.isEmpty) {
      adminEmailErr = 'Admin email is required';
    } else if (!_emailRegex.hasMatch(adminEmail)) {
      adminEmailErr = 'Enter a valid email address';
    }

    if (adminPhone.isEmpty) {
      adminPhoneErr = 'Admin phone is required';
    } else if (!_tenDigitRegex.hasMatch(adminPhone)) {
      adminPhoneErr = 'Enter a valid 10-digit mobile number';
    }

    if (adminDistrict.isEmpty) {
      adminDistrictErr = 'District is required';
    }

    if (adminPincode.isEmpty) {
      adminPincodeErr = 'Pincode is required';
    } else if (!_pincodeRegex.hasMatch(adminPincode)) {
      adminPincodeErr = 'Enter a valid 6-digit pincode';
    }

    if (adminPost.isEmpty) {
      adminPostErr = 'Post / Designation is required';
    }

    setState(() {
      _agencyNameError = agencyNameErr;
      _phoneError = phoneErr;
      _emailError = emailErr;
      _passwordError = passwordErr;
      _addressError = addressErr;
      _contactPersonNameError = contactPersonNameErr;
      _adminNameError = adminNameErr;
      _adminEmailError = adminEmailErr;
      _adminPhoneError = adminPhoneErr;
      _adminDistrictError = adminDistrictErr;
      _adminPincodeError = adminPincodeErr;
      _adminPostError = adminPostErr;
    });

    return agencyNameErr == null &&
        phoneErr == null &&
        emailErr == null &&
        passwordErr == null &&
        addressErr == null &&
        contactPersonNameErr == null &&
        adminNameErr == null &&
        adminEmailErr == null &&
        adminPhoneErr == null &&
        adminDistrictErr == null &&
        adminPincodeErr == null &&
        adminPostErr == null;
  }

  Future<void> _registerCompany() async {
    if (!_validateFields()) {
      _showMessage('Please fix the highlighted fields');
      return;
    }

    if (!_agree) {
      _showMessage('Please agree to Terms & Privacy Policy');
      return;
    }

    setState(() => _isLoading = true);

    final body = {
      "companyName": _agencyNameController.text.trim(),
      "email": _emailController.text.trim(),
      "phone": _phoneController.text.trim(),
      "address": _addressController.text.trim(),
      "contactPersonName": _contactPersonNameController.text.trim(),
      "adminName": _adminNameController.text.trim(),
      "adminEmail": _adminEmailController.text.trim(),
      "adminPhone": _adminPhoneController.text.trim(),
      "adminPassword": _passwordController.text.trim(),
      "adminDistrict": _adminDistrictController.text.trim(),
      "adminPincode": _adminPincodeController.text.trim(),
      "adminPost": _adminPostController.text.trim(),
      "adminAgencyName": _agencyNameController.text.trim(),
    };

    try {
      final response = await http.post(
        Uri.parse(_registerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decoded['success'] == true) {
          _showMessage(decoded['message'] ?? 'Registration submitted');

          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const OtpScreen(fromSignup: true),
              ),
            );
          }
        } else {
          _showMessage(decoded['message'] ?? 'Registration failed');
        }
      } else {
        _showMessage(decoded['message'] ?? 'Something went wrong (${response.statusCode})');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child:
        Column(
          children: [
            Container(
              width: double.infinity,
              height: 150,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    // Color(0xFF38B6FF),
                    // Color(0xFF1D3FAE),
                    // Color(0xFF1D3FAE),
                    Color(0xFFFFFFFF),
                    Color(0xFFFFFFFF),
                    Color(0xFFFFFFFF),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Stack(
                children: [
                  // =========================
                  // BACK BUTTON
                  // =========================
                  Positioned(
                    top: 14,
                    left: 16,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F7FC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.slate200,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            size: 21,
                            color: Color(0xFF0C1220),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // =========================
                  // CENTER CONTENT
                  // =========================
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // LOGO
                          // Center(
                          //   child: Image.asset(
                          //     "assets/images/fastrecovery_logo.png",
                          //     width: 230,
                          //     fit: BoxFit.contain,
                          //   ),
                          // ),

                          //const SizedBox(height: 6),

                          // TITLE
                          // Text(
                          //   'Create Account',
                          //   textAlign: TextAlign.center,
                          //   style: AppTextStyles.body(
                          //     size: 24,
                          //     weight: FontWeight.w700,
                          //     color: const Color(0xFFFFFFFF),
                          //   ),
                          // ),
                          Image.asset("assets/images/fastrecovery_logo-2.png",height: 50,),

                          const SizedBox(height: 3),

                          // SUBTITLE
                          Text(
                            'Create your company account to get started',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color:  Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      controller: _agencyNameController,
                      label: 'Agency Name',
                      hint: 'e.g. Kartik Repossession Agency',
                      icon: Icons.home_work_outlined,
                    ),
                    _errorText(_agencyNameError),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _phoneController,
                      label: 'Mobile Number',
                      hint: '10-digit mobile number',
                      icon: Icons.phone_iphone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                    _errorText(_phoneError),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'agency@email.com',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _errorText(_emailError),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Create a password',
                      icon: Icons.lock_outline_rounded,
                      obscure: true,
                      showToggle: true,
                    ),
                    _errorText(_passwordError),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _addressController,
                      label: 'Address',
                      hint: 'e.g. India, Delhi',
                      icon: Icons.location_on_outlined,
                    ),
                    _errorText(_addressError),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _contactPersonNameController,
                      label: 'Contact Person Name',
                      hint: 'Enter contact person name',
                      icon: Icons.person_outline_rounded,
                    ),
                    _errorText(_contactPersonNameError),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _adminNameController,
                      label: 'Admin Name',
                      hint: 'Enter admin name',
                      icon: Icons.admin_panel_settings_outlined,
                    ),
                    _errorText(_adminNameError),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _adminEmailController,
                      label: 'Admin Email',
                      hint: 'admin@email.com',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _errorText(_adminEmailError),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _adminPhoneController,
                      label: 'Admin Phone',
                      hint: '10-digit admin phone number',
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                    _errorText(_adminPhoneError),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _adminDistrictController,
                      label: 'District',
                      hint: 'e.g. Delhi',
                      icon: Icons.map_outlined,
                    ),
                    _errorText(_adminDistrictError),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _adminPincodeController,
                      label: 'Pincode',
                      hint: 'e.g. 110095',
                      icon: Icons.pin_drop_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    _errorText(_adminPincodeError),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _adminPostController,
                      label: 'Post / Designation',
                      hint: 'e.g. Proprietor',
                      icon: Icons.badge_outlined,
                    ),
                    _errorText(_adminPostError),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _agree,
                            onChanged: (v) => setState(() => _agree = v ?? false),
                            activeColor: AppColors.blue600,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: RichText(
                              text: TextSpan(
                                style: AppTextStyles.body(
                                    size: 13, color: AppColors.slate600),
                                children: [
                                  const TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms & Privacy Policy',
                                    style: TextStyle(
                                        color: AppColors.blue600,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    PrimaryButton(
                      label: _isLoading ? 'Please wait...' : 'Create Account',
                      icon: null,
                      onTap: _isLoading ? () {} : _registerCompany,
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Wrap(
                        children: [
                          Text('Already registered? ',
                              style: AppTextStyles.body(
                                  size: 13.5, color: AppColors.slate600)),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Text('Log in',
                                style: AppTextStyles.body(
                                    size: 13.5,
                                    weight: FontWeight.w700,
                                    color: AppColors.blue600)),
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