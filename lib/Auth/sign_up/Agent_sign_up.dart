import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../Widget/Common_widget.dart';
import '../../theme/app_theme.dart';
import '../OTP-page.dart';

class AgentRegisterScreen extends StatefulWidget {
  const AgentRegisterScreen({super.key});

  @override
  State<AgentRegisterScreen> createState() => _AgentRegisterScreenState();
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _AgentRegisterScreenState extends State<AgentRegisterScreen> {
  bool _isLoading = false;

  static const String _registerUrl =
      'https://fastrecovery.in/api/auth/agent-register'; // no "www"

  // ---------------- Controllers ----------------
  final _companyCodeC = TextEditingController();
  final _nameC = TextEditingController();
  final _fatherNameC = TextEditingController();
  final _emailC = TextEditingController();
  final _mobileC = TextEditingController();
  final _passwordC = TextEditingController();
  final _panC = TextEditingController();
  final _aadhaarC = TextEditingController();
  final _addressC = TextEditingController();
  final _pincodeC = TextEditingController();
  final _cityC = TextEditingController();

  DateTime? _dob;
  String? _bloodGroup;
  String? _state;
  String _role = 'REPO_STAFF'; // API ko ye value jaati hai

  PlatformFile? _panDoc;
  PlatformFile? _aadhaarDoc;

  final Map<String, String?> _errors = {};

  static const List<Map<String, String>> _roles = [
    {'label': 'Repo Staff', 'value': 'REPO_STAFF'},
    {'label': 'Team Leader', 'value': 'TEAM_LEADER'},
    {'label': 'Head Office Staff', 'value': 'HEAD OFFICE STAFF'},
    {'label': 'Office Staff', 'value': 'OFFICE STAFF'},
  ];

  static const List<String> _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  static const List<String> _states = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
    'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim',
    'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand',
    'West Bengal', 'Andaman and Nicobar Islands', 'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu', 'Delhi', 'Jammu and Kashmir',
    'Ladakh', 'Lakshadweep', 'Puducherry',
  ];

  static final RegExp _emailRegex =
  RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');
  static final RegExp _tenDigit = RegExp(r'^[0-9]{10}$');
  static final RegExp _pincode = RegExp(r'^[0-9]{6}$');
  static final RegExp _aadhaar = RegExp(r'^[0-9]{12}$');
  static final RegExp _pan = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');

  @override
  void dispose() {
    for (final c in [
      _companyCodeC, _nameC, _fatherNameC, _emailC, _mobileC, _passwordC,
      _panC, _aadhaarC, _addressC, _pincodeC, _cityC,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------- Helpers ----------------
  String _fmtApiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtUiDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _errors['dob'] = null;
      });
    }
  }

  Future<void> _pickDoc(String key) async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (res == null || res.isEmpty) return;
    final f = res.first;
    setState(() {
      if (key == 'panDocument') _panDoc = f;
      if (key == 'aadhaarDocument') _aadhaarDoc = f;
      _errors[key] = null;
    });
  }

  // ---------------- Validation ----------------
  bool _validate() {
    final e = <String, String?>{};

    final code = _companyCodeC.text.trim();
    if (code.isEmpty) {
      e['companyCode'] = 'Company code is required';
    } else if (code.length < 4) {
      e['companyCode'] = 'Enter a valid company code (e.g. HIM1114)';
    }

    final name = _nameC.text.trim();
    if (name.isEmpty) {
      e['name'] = 'Full name is required';
    } else if (name.length < 3) {
      e['name'] = 'Full name must be at least 3 characters';
    }

    if (_fatherNameC.text.trim().isEmpty) {
      e['fatherName'] = "Father's name is required";
    }

    final email = _emailC.text.trim();
    if (email.isEmpty) {
      e['email'] = 'Email is required';
    } else if (!_emailRegex.hasMatch(email)) {
      e['email'] = 'Enter a valid email address';
    }

    final mobile = _mobileC.text.trim();
    if (mobile.isEmpty) {
      e['mobile'] = 'Mobile number is required';
    } else if (!_tenDigit.hasMatch(mobile)) {
      e['mobile'] = 'Enter a valid 10-digit mobile number';
    }

    if (_dob == null) e['dob'] = 'Date of birth is required';

    final pwd = _passwordC.text;
    if (pwd.isEmpty) {
      e['password'] = 'Password is required';
    } else if (pwd.length < 8) {
      e['password'] = 'Password must be at least 8 characters';
    }

    if (_bloodGroup == null) e['blood'] = 'Please select blood group';

    final pan = _panC.text.trim();
    if (pan.isEmpty) {
      e['pan'] = 'PAN number is required';
    } else if (!_pan.hasMatch(pan)) {
      e['pan'] = 'Enter a valid PAN (e.g. ABCDE1234F)';
    }
    if (_panDoc == null) e['panDocument'] = 'PAN card is required';

    final aadhaar = _aadhaarC.text.trim();
    if (aadhaar.isEmpty) {
      e['aadhaar'] = 'Aadhaar number is required';
    } else if (!_aadhaar.hasMatch(aadhaar)) {
      e['aadhaar'] = 'Enter a valid 12-digit Aadhaar number';
    }
    if (_aadhaarDoc == null) e['aadhaarDocument'] = 'Aadhaar card is required';

    if (_addressC.text.trim().isEmpty) e['address'] = 'Address is required';

    final pin = _pincodeC.text.trim();
    if (pin.isEmpty) {
      e['pincode'] = 'Pincode is required';
    } else if (!_pincode.hasMatch(pin)) {
      e['pincode'] = 'Enter a valid 6-digit pincode';
    }

    if (_cityC.text.trim().isEmpty) e['city'] = 'City is required';
    if (_state == null) e['state'] = 'Please select state';

    setState(() {
      _errors
        ..clear()
        ..addAll(e);
    });

    return e.values.every((v) => v == null);
  }

  // ---------------- API ----------------
  Future<void> _registerAgent() async {
    if (_isLoading) return;

    if (!_validate()) {
      _showMessage('Please fix the highlighted fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final req = http.MultipartRequest('POST', Uri.parse(_registerUrl));
      req.headers['Accept'] = 'application/json';

      req.fields.addAll({
        'companyCode': _companyCodeC.text.trim().toUpperCase(),
        'name': _nameC.text.trim(),
        'fatherName': _fatherNameC.text.trim(),
        'email': _emailC.text.trim(),
        'phone': _mobileC.text.trim(),
        'password': _passwordC.text,
        'address': _addressC.text.trim(),
        'city': _cityC.text.trim(),
        'state': _state!,
        'pincode': _pincodeC.text.trim(),
        'panNumber': _panC.text.trim().toUpperCase(),
        'aadhaarNumber': _aadhaarC.text.trim(),
        'bloodGroup': _bloodGroup!,
        'dateOfBirth': _fmtApiDate(_dob!),
        'role': _role,
      });

      Future<void> addFile(String field, PlatformFile? f) async {
        if (f?.path == null) return;

        final ext = (f!.extension ?? '').toLowerCase();
        MediaType type;
        if (ext == 'jpg' || ext == 'jpeg') {
          type = MediaType('image', 'jpeg');
        } else if (ext == 'png') {
          type = MediaType('image', 'png');
        } else if (ext == 'pdf') {
          type = MediaType('application', 'pdf');
        } else {
          type = MediaType('application', 'octet-stream');
        }

        req.files.add(await http.MultipartFile.fromPath(
          field,
          f.path!,
          filename: f.name,
          contentType: type,
        ));
      }

      await addFile('panDocument', _panDoc);
      await addFile('aadhaarDocument', _aadhaarDoc);

      final streamed = await req.send().timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamed);

      debugPrint('AGENT REGISTER status: ${response.statusCode}');
      debugPrint('AGENT REGISTER body: ${response.body}');

      Map<String, dynamic> decoded;
      try {
        decoded = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        _showMessage('Unexpected server response (${response.statusCode})');
        return;
      }

      final ok = (response.statusCode == 200 || response.statusCode == 201) &&
          decoded['success'] == true;

      if (!ok) {
        _showMessage(decoded['message']?.toString() ??
            'Registration failed (${response.statusCode})');
        return;
      }

      final data = decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'] as Map)
          : <String, dynamic>{};

      _showMessage(decoded['message']?.toString() ?? 'OTP sent successfully.');

      if (decoded['requiresOtp'] == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              fromSignup: true,
              registrationId: data['registrationId']?.toString() ?? '',
              identifier: data['phone']?.toString() ?? _mobileC.text.trim(),
              maskedPhone: data['maskedPhone']?.toString() ?? '',
              expiresInSeconds:
              (data['expiresInSeconds'] as num?)?.toInt() ?? 600,
              resendAfterSeconds:
              (data['resendAvailableInSeconds'] as num?)?.toInt() ?? 60,
            ),
          ),
        );
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      debugPrint('AGENT REGISTER error: $e\n$st');
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

  // ---------------- Small UI builders ----------------
  Widget _err(String key) {
    final error = _errors[key];
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

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 14),
    child: Text(
      t,
      style: AppTextStyles.body(
          size: 16, weight: FontWeight.w700, color: AppColors.navy950),
    ),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: AppTextStyles.body(
          size: 13, weight: FontWeight.w600, color: AppColors.slate600),
    ),
  );

  BoxDecoration _boxDeco(bool hasError) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: hasError ? Colors.redAccent : AppColors.slate200,
    ),
  );

  Widget _gap([double h = 16]) => SizedBox(height: h);

  Widget _dropdown({
    required String label,
    required String hint,
    required String errKey,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: _boxDeco(_errors[errKey] != null),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: Colors.white,
              isExpanded: true,
              value: value,
              hint: Text(hint,
                  style:
                  AppTextStyles.body(size: 14, color: AppColors.slate400)),
              items: items
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) {
                onChanged(v);
                setState(() => _errors[errKey] = null);
              },
            ),
          ),
        ),
        _err(errKey),
      ],
    );
  }

  Widget _dateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Date of birth *'),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _pickDob,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: _boxDeco(_errors['dob'] != null),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18),
                const SizedBox(width: 10),
                Text(
                  _dob == null ? 'DD / MM / YYYY' : _fmtUiDate(_dob!),
                  style: AppTextStyles.body(
                    size: 14,
                    color:
                    _dob == null ? AppColors.slate400 : AppColors.navy950,
                  ),
                ),
              ],
            ),
          ),
        ),
        _err('dob'),
      ],
    );
  }

  Widget _bloodGroupField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Blood group *'),
        LayoutBuilder(builder: (context, c) {
          const spacing = 8.0;
          final w = (c.maxWidth - spacing * 3) / 4;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: _bloodGroups.map((g) {
              final selected = _bloodGroup == g;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() {
                  _bloodGroup = g;
                  _errors['blood'] = null;
                }),
                child: Container(
                  width: w,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.redAccent.withOpacity(.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? Colors.redAccent : AppColors.slate200,
                      width: selected ? 1.6 : 1.2,
                    ),
                  ),
                  child: Text(
                    g,
                    style: AppTextStyles.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: selected ? Colors.redAccent : AppColors.navy950,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }),
        _err('blood'),
      ],
    );
  }

  Widget _filePickerField({
    required String label,
    required String key,
    required PlatformFile? file,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _pickDoc(key),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: _boxDeco(_errors[key] != null),
            child: Row(
              children: [
                Icon(
                  file == null
                      ? Icons.upload_file_rounded
                      : Icons.check_circle_rounded,
                  size: 20,
                  color: file == null ? AppColors.blue600 : Colors.green,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    file?.name ?? 'Choose file',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(
                      size: 13.5,
                      color:
                      file == null ? AppColors.slate400 : AppColors.navy950,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _err(key),
      ],
    );
  }

  Widget _roleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Role',
            style: AppTextStyles.body(
                size: 10.5,
                weight: FontWeight.w700,
                color: AppColors.slate600)
                .copyWith(letterSpacing: 0.7)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.blue500, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: Colors.white,
              value: _role,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: _roles
                  .map((r) => DropdownMenuItem<String>(
                value: r['value'],
                child:
                Text(r['label']!, style: AppTextStyles.body(size: 13.5)),
              ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _role = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- Build ----------------
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
                'Use the company code from your repo admin. Your account stays inactive until the admin activates it.',
                style: AppTextStyles.body(size: 14.5, color: AppColors.slate600)
                    .copyWith(height: 1.5),
              ),
              const SizedBox(height: 22),

              // ---------- Agency ----------
              _sectionTitle('Agency'),
              AppTextField(
                controller: _companyCodeC,
                label: 'Company code *',
                hint: 'e.g. HIM1114',
                icon: Icons.confirmation_number_outlined,
                inputFormatters: [_UpperCaseFormatter()],
              ),
              _err('companyCode'),
              _gap(24),

              // ---------- Personal details ----------
              _sectionTitle('Personal details'),
              AppTextField(
                controller: _nameC,
                label: 'Full name *',
                hint: 'Enter full name',
                icon: Icons.person_outline_rounded,
              ),
              _err('name'),
              _gap(),
              AppTextField(
                controller: _fatherNameC,
                label: "Father's name *",
                hint: "Enter father's name",
                icon: Icons.family_restroom_outlined,
              ),
              _err('fatherName'),
              _gap(),
              AppTextField(
                controller: _emailC,
                label: 'Email *',
                hint: 'agent@email.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              _err('email'),
              _gap(),
              AppTextField(
                controller: _mobileC,
                label: 'Mobile *',
                hint: '10-digit mobile number',
                icon: Icons.phone_iphone_rounded,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              _err('mobile'),
              _gap(),
              _dateField(),
              _gap(),
              AppTextField(
                controller: _passwordC,
                label: 'Password *',
                hint: 'Create a password (min. 8 characters)',
                icon: Icons.lock_outline_rounded,
                obscure: true,
                showToggle: true,
              ),
              _err('password'),
              _gap(),
              _bloodGroupField(),
              _gap(),
              _roleDropdown(),
              _gap(24),

              // ---------- PAN & Aadhaar ----------
              _sectionTitle('PAN & Aadhaar'),
              AppTextField(
                controller: _panC,
                label: 'PAN Number *',
                hint: 'ENTER PAN NUMBER',
                icon: Icons.credit_card_outlined,
                maxLength: 10,
                inputFormatters: [
                  _UpperCaseFormatter(),
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              _err('pan'),
              _gap(),
              _filePickerField(
                  label: 'Upload PAN Card *',
                  key: 'panDocument',
                  file: _panDoc),
              _gap(),
              AppTextField(
                controller: _aadhaarC,
                label: 'Aadhaar Number *',
                hint: '12-digit Aadhaar number',
                icon: Icons.fingerprint_rounded,
                keyboardType: TextInputType.number,
                maxLength: 12,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
              ),
              _err('aadhaar'),
              _gap(),
              _filePickerField(
                  label: 'Upload Aadhaar Card *',
                  key: 'aadhaarDocument',
                  file: _aadhaarDoc),
              _gap(24),

              // ---------- Address ----------
              _sectionTitle('Address'),
              AppTextField(
                controller: _addressC,
                label: 'Address *',
                hint: 'Enter your address',
                icon: Icons.location_on_outlined,
              ),
              _err('address'),
              _gap(),
              AppTextField(
                controller: _pincodeC,
                label: 'Pincode *',
                hint: '6-digit pincode',
                icon: Icons.pin_drop_outlined,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
              ),
              _err('pincode'),
              _gap(),
              AppTextField(
                controller: _cityC,
                label: 'City *',
                hint: 'City / District',
                icon: Icons.location_city_outlined,
              ),
              _err('city'),
              _gap(),
              _dropdown(
                label: 'State *',
                hint: 'Select state',
                errKey: 'state',
                value: _state,
                items: _states,
                onChanged: (v) => setState(() => _state = v),
              ),

              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                    _isLoading ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.slate200,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Back to login',
                      style: AppTextStyles.body(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: AppColors.navy950),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _registerAgent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue600,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      _isLoading ? 'Please wait...' : 'Register',
                      style: AppTextStyles.body(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: Colors.white),
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