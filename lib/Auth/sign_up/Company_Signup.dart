import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../Widget/Common_widget.dart';
import '../../theme/app_theme.dart';
import '../OTP-page.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _SignupScreenState extends State<SignupScreen> {
  bool _agree = false;
  bool _isLoading = false;

  static const String _registerUrl =
      'https://fastrecovery.in/api/companies/register'; // no "www" (redirect can drop POST body)

  // ---------------- Controllers ----------------
  final _agencyNameC = TextEditingController();
  final _ownerNameC = TextEditingController();
  final List<TextEditingController> _extraOwnerCs = [];
  final _emailC = TextEditingController();
  final _phoneC = TextEditingController(); // First confirmation number
  final _phone2C = TextEditingController(); // Second confirmation number
  final _panC = TextEditingController();
  final _aadhaarC = TextEditingController();
  final _gstC = TextEditingController();
  final _addressC = TextEditingController();
  final _pincodeC = TextEditingController();
  final _districtC = TextEditingController();
  final _passwordC = TextEditingController();

  String? _post;
  String? _state;
  DateTime? _dob;

  // ---------------- Files ----------------
  PlatformFile? _companyPhoto;
  PlatformFile? _adminPhoto;
  PlatformFile? _panDoc;
  PlatformFile? _aadhaarDoc;
  PlatformFile? _gstDoc;

  // ---------------- Errors (key -> message) ----------------
  final Map<String, String?> _errors = {};

  static final RegExp _emailRegex =
  RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');
  static final RegExp _tenDigit = RegExp(r'^[0-9]{10}$');
  static final RegExp _pincode = RegExp(r'^[0-9]{6}$');
  static final RegExp _aadhaar = RegExp(r'^[0-9]{12}$');
  static final RegExp _pan = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
  static final RegExp _gst = RegExp(r'^[A-Z0-9]{15}$');

  static const List<String> _posts = ['Proprietor', 'Partner', 'Director'];

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

  @override
  void dispose() {
    for (final c in [
      _agencyNameC, _ownerNameC, _emailC, _phoneC, _phone2C, _panC,
      _aadhaarC, _gstC, _addressC, _pincodeC, _districtC, _passwordC,
      ..._extraOwnerCs,
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

  Future<void> _pickFile(String key, {bool imageOnly = false}) async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions:
      imageOnly ? ['jpg', 'jpeg', 'png'] : ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (res == null || res.isEmpty) return;
    final f = res.first;
    setState(() {
      switch (key) {
        case 'companyPhoto':
          _companyPhoto = f;
          break;
        case 'adminPhoto':
          _adminPhoto = f;
          break;
        case 'panDocument':
          _panDoc = f;
          break;
        case 'aadhaarDocument':
          _aadhaarDoc = f;
          break;
        case 'gstDocument':
          _gstDoc = f;
          break;
      }
      _errors[key] = null;
    });
  }

  // ---------------- Validation ----------------
  bool _validate() {
    final e = <String, String?>{};

    final agency = _agencyNameC.text.trim();
    if (agency.isEmpty) {
      e['agency'] = 'Agency name is required';
    } else if (agency.length < 3) {
      e['agency'] = 'Agency name must be at least 3 characters';
    }

    if (_post == null) e['post'] = 'Please select post';

    if (_ownerNameC.text.trim().isEmpty) {
      e['owner'] = 'Proprietor / Partner / Director name is required';
    }

    final email = _emailC.text.trim();
    if (email.isEmpty) {
      e['email'] = 'Email is required';
    } else if (!_emailRegex.hasMatch(email)) {
      e['email'] = 'Enter a valid email address';
    }

    if (_dob == null) e['dob'] = 'Date of birth is required';

    final p1 = _phoneC.text.trim();
    if (p1.isEmpty) {
      e['phone'] = 'First confirmation number is required';
    } else if (!_tenDigit.hasMatch(p1)) {
      e['phone'] = 'Enter a valid 10-digit mobile number';
    }

    final p2 = _phone2C.text.trim();
    if (p2.isEmpty) {
      e['phone2'] = 'Second confirmation number is required';
    } else if (!_tenDigit.hasMatch(p2)) {
      e['phone2'] = 'Enter a valid 10-digit mobile number';
    }

    final pan = _panC.text.trim();
    if (pan.isEmpty) {
      e['pan'] = 'PAN number is required';
    } else if (!_pan.hasMatch(pan)) {
      e['pan'] = 'Enter a valid PAN (e.g. ABCDE1234F)';
    }

    final aadhaar = _aadhaarC.text.trim();
    if (aadhaar.isEmpty) {
      e['aadhaar'] = 'Aadhaar number is required';
    } else if (!_aadhaar.hasMatch(aadhaar)) {
      e['aadhaar'] = 'Enter a valid 12-digit Aadhaar number';
    }

    final gst = _gstC.text.trim();
    if (gst.isEmpty) {
      e['gst'] = 'GST number is required';
    } else if (!_gst.hasMatch(gst)) {
      e['gst'] = 'Enter a valid 15-character GST number';
    }

    if (_panDoc == null) e['panDocument'] = 'PAN card is required';
    if (_aadhaarDoc == null) e['aadhaarDocument'] = 'Aadhaar card is required';
    if (_gstDoc == null) e['gstDocument'] = 'GST certificate is required';

    if (_addressC.text.trim().isEmpty) e['address'] = 'Address is required';

    final pin = _pincodeC.text.trim();
    if (pin.isEmpty) {
      e['pincode'] = 'Pincode is required';
    } else if (!_pincode.hasMatch(pin)) {
      e['pincode'] = 'Enter a valid 6-digit pincode';
    }

    if (_districtC.text.trim().isEmpty) e['district'] = 'District is required';
    if (_state == null) e['state'] = 'Please select state';

    final pwd = _passwordC.text;
    if (pwd.isEmpty) {
      e['password'] = 'Password is required';
    } else if (pwd.length < 8) {
      e['password'] = 'Password must be at least 8 characters';
    }

    e['agree'] = _agree ? null : 'Please accept Terms & Privacy Policy to continue';

    setState(() {
      _errors
        ..clear()
        ..addAll(e);
    });

    return e.values.every((v) => v == null);
  }

  // ---------------- API ----------------
  Future<void> _registerCompany() async {
    if (_isLoading) return;

    if (!_validate()) {
      _showMessage('Please fix the highlighted fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final owners = [
        _ownerNameC.text.trim(),
        ..._extraOwnerCs.map((c) => c.text.trim()).where((s) => s.isNotEmpty),
      ];

      final req = http.MultipartRequest('POST', Uri.parse(_registerUrl));
      req.headers['Accept'] = 'application/json';

      req.fields.addAll({
        'companyName': _agencyNameC.text.trim(),
        'email': _emailC.text.trim(),
        'phone': _phoneC.text.trim(),
        'address': _addressC.text.trim(),
        'contactPersonName': owners.first,
        'ownerName': owners.join(', '),
        'panNumber': _panC.text.trim().toUpperCase(),
        'aadhaarNumber': _aadhaarC.text.trim(),
        'gstNumber': _gstC.text.trim().toUpperCase(),
        'adminName': owners.first,
        'adminEmail': _emailC.text.trim(),
        'adminPhone': _phone2C.text.trim(),
        'adminPassword': _passwordC.text,
        'adminDistrict': _districtC.text.trim(),
        'adminState': _state!,
        'adminPincode': _pincodeC.text.trim(),
        'adminPost': _post!,
        'adminAgencyName': _agencyNameC.text.trim(),
        'adminDateOfBirth': _fmtApiDate(_dob!),
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

      await addFile('companyPhoto', _companyPhoto);
      await addFile('adminPhoto', _adminPhoto);
      await addFile('panDocument', _panDoc);
      await addFile('aadhaarDocument', _aadhaarDoc);
      await addFile('gstDocument', _gstDoc);

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      debugPrint('REGISTER status: ${response.statusCode}');
      debugPrint('REGISTER body: ${response.body}');

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

      _showMessage(decoded['message']?.toString() ?? 'OTP sent successfully.');

      final data = (decoded['data'] ?? {}) as Map<String, dynamic>;

      if (decoded['requiresOtp'] == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              fromSignup: true,
              registrationId: data['registrationId']?.toString() ?? '',
              identifier: data['phone']?.toString() ?? _phoneC.text.trim(),
              maskedPhone: data['maskedPhone']?.toString() ?? '',
              expiresInSeconds:
              (data['expiresInSeconds'] as num?)?.toInt() ?? 600,
              resendAfterSeconds:
              (data['resendAvailableInSeconds'] as num?)?.toInt() ?? 60,
            ),
          ),
        );
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
          size: 16, weight: FontWeight.w700, color: const Color(0xFF0C1220)),
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
              isExpanded: true,
              value: value,
              hint: Text(hint,
                  style: AppTextStyles.body(size: 14, color: AppColors.slate400)),
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
        _label('Date of Birth'),
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
                    color: _dob == null
                        ? AppColors.slate400
                        : const Color(0xFF0C1220),
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

  Widget _filePickerField({
    required String label,
    required String key,
    required PlatformFile? file,
    bool imageOnly = false,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _pickFile(key, imageOnly: imageOnly),
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
                    file?.name ?? (required ? 'Choose file' : 'Choose file (optional)'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(
                      size: 13.5,
                      color: file == null
                          ? AppColors.slate400
                          : const Color(0xFF0C1220),
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

  Widget _gap([double h = 16]) => SizedBox(height: h);

  // ---------------- Build ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---------- Uploads ----------
                    _filePickerField(
                      label: 'Company Logo',
                      key: 'companyPhoto',
                      file: _companyPhoto,
                      imageOnly: true,
                      required: false,
                    ),
                    _gap(),
                    _filePickerField(
                      label: 'Admin Photo',
                      key: 'adminPhoto',
                      file: _adminPhoto,
                      imageOnly: true,
                      required: false,
                    ),
                    _gap(24),

                    // ---------- Firm details ----------
                    _sectionTitle('Firm / Agency Details'),
                    AppTextField(
                      controller: _agencyNameC,
                      label: 'Agency Name',
                      hint: 'Enter agency name',
                      icon: Icons.home_work_outlined,
                    ),
                    _err('agency'),
                    _gap(),
                    _dropdown(
                      label: 'Post',
                      hint: 'Select post',
                      errKey: 'post',
                      value: _post,
                      items: _posts,
                      onChanged: (v) => setState(() => _post = v),
                    ),
                    _gap(),
                    AppTextField(
                      controller: _ownerNameC,
                      label: 'Proprietor / Partners / Directors Name',
                      hint: 'Enter proprietor / partners / directors name',
                      icon: Icons.person_outline_rounded,
                    ),
                    _err('owner'),
                    for (int i = 0; i < _extraOwnerCs.length; i++) ...[
                      _gap(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _extraOwnerCs[i],
                              label: 'Director / Partner ${i + 2}',
                              hint: 'Enter name',
                              icon: Icons.person_add_alt_outlined,
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() {
                              _extraOwnerCs.removeAt(i).dispose();
                            }),
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ],
                    _gap(12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(
                                () => _extraOwnerCs.add(TextEditingController())),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add another director/partner'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.blue600,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    _gap(24),

                    // ---------- Contact ----------
                    _sectionTitle('Contact'),
                    AppTextField(
                      controller: _emailC,
                      label: 'Email',
                      hint: 'Enter email',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _err('email'),
                    _gap(),
                    _dateField(),
                    _gap(),
                    AppTextField(
                      controller: _phoneC,
                      label: 'First Confirmation Number',
                      hint: 'Enter first confirmation number',
                      icon: Icons.phone_iphone_rounded,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                    ),
                    _err('phone'),
                    _gap(),
                    AppTextField(
                      controller: _phone2C,
                      label: 'Second Confirmation Number',
                      hint: 'Enter second confirmation number',
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                    ),
                    _err('phone2'),
                    _gap(24),

                    // ---------- Tax & registration ----------
                    _sectionTitle('Tax & Registration'),
                    AppTextField(
                      controller: _panC,
                      label: 'PAN Number',
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
                        label: 'Upload PAN Card',
                        key: 'panDocument',
                        file: _panDoc),
                    _gap(),
                    AppTextField(
                      controller: _aadhaarC,
                      label: 'Aadhaar Number',
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
                        label: 'Upload Aadhaar Card',
                        key: 'aadhaarDocument',
                        file: _aadhaarDoc),
                    _gap(),
                    AppTextField(
                      controller: _gstC,
                      label: 'GST Number',
                      hint: '15-DIGIT GST NUMBER',
                      icon: Icons.receipt_long_outlined,
                      maxLength: 15,
                      inputFormatters: [
                        _UpperCaseFormatter(),
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                        LengthLimitingTextInputFormatter(15),
                      ],
                    ),
                    _err('gst'),
                    _gap(),
                    _filePickerField(
                        label: 'Upload GST Certificate',
                        key: 'gstDocument',
                        file: _gstDoc),
                    _gap(24),

                    // ---------- Address ----------
                    _sectionTitle('Address'),
                    AppTextField(
                      controller: _addressC,
                      label: 'Address',
                      hint: 'Enter firm / agency address',
                      icon: Icons.location_on_outlined,
                    ),
                    _err('address'),
                    _gap(),
                    AppTextField(
                      controller: _pincodeC,
                      label: 'Pincode',
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
                      controller: _districtC,
                      label: 'District',
                      hint: 'District',
                      icon: Icons.map_outlined,
                    ),
                    _err('district'),
                    _gap(),
                    _dropdown(
                      label: 'State',
                      hint: 'Search or select state',
                      errKey: 'state',
                      value: _state,
                      items: _states,
                      onChanged: (v) => setState(() => _state = v),
                    ),
                    _gap(),
                    AppTextField(
                      controller: _passwordC,
                      label: 'Password',
                      hint: 'Enter secure password (min. 8 characters)',
                      icon: Icons.lock_outline_rounded,
                      obscure: true,
                      showToggle: true,
                    ),
                    _err('password'),
                    _gap(14),

                    // ---------- Terms ----------
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _agree,
                            onChanged: (v) => setState(() {
                              _agree = v ?? false;
                              if (_agree) _errors['agree'] = null;
                            }),
                            activeColor: AppColors.blue600,
                            side: BorderSide(
                              color: _errors['agree'] != null
                                  ? Colors.redAccent
                                  : AppColors.slate400,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() {
                                _agree = !_agree;
                                if (_agree) _errors['agree'] = null;
                              }),
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
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: _err('agree'),
                    ),

                    const SizedBox(height: 18),
                    Opacity(
                      opacity: _agree ? 1 : .55,
                      child: PrimaryButton(
                        label: _isLoading ? 'Please wait...' : 'Submit Registration',
                        icon: null,
                        onTap: _isLoading ? () {} : _registerCompany,
                      ),
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

  Widget _header() {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 14,
            left: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      size: 21, color: Color(0xFF0C1220)),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset("assets/images/fastrecovery_logo-2.png",
                      height: 50),
                  const SizedBox(height: 3),
                  const Text(
                    'Register your company',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}