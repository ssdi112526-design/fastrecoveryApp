import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../Widget/Common_widget.dart';
import '../theme/app_theme.dart';
import 'OTP-page.dart';

// ------------------------------------------------------------
// ACCOUNT MODEL  (accounts API ke data.accounts[] se)
// ------------------------------------------------------------
class _Account {
  final String id;
  final String name;
  final String roleLabel;
  final String agencyName;
  final String branchName;
  final String maskedEmail;

  const _Account({
    required this.id,
    required this.name,
    required this.roleLabel,
    required this.agencyName,
    required this.branchName,
    required this.maskedEmail,
  });

  factory _Account.fromJson(Map<String, dynamic> j) {
    String s(String key) => (j[key] ?? '').toString().trim();
    return _Account(
      id: s('id'),
      name: s('name'),
      roleLabel: s('roleLabel').isNotEmpty ? s('roleLabel') : s('role'),
      agencyName: s('agencyName'),
      branchName: s('branchName'),
      maskedEmail: s('maskedEmail'),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const String _accountsUrl =
      'https://www.fastrecovery.in/api/auth/forgot-password/accounts';

  // ✅ Naya send-otp API  (body: {phone, userId})
  static const String _sendOtpUrl =
      'https://fastrecovery.in/api/auth/forgot-password/send-otp';

  static final RegExp _tenDigits = RegExp(r'^[0-9]{10}$');

  final _controller = TextEditingController();

  String? _error;
  bool _loadingAccounts = false;
  bool _sendingOtp = false;
  String? _selectedId; // jis account par OTP bhej rahe hain

  List<_Account>? _accounts; // null = step 1 (number), non-null = step 2 (list)
  String _phone = '';

  bool get _onListStep => _accounts != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------
  Map<String, dynamic>? _decode(http.Response r) {
    try {
      final d = jsonDecode(r.body);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) {
      return null;
    }
  }

  bool _isOk(http.Response r, Map<String, dynamic>? body) =>
      r.statusCode >= 200 && r.statusCode < 300 && body?['success'] != false;

  String? _messageOf(Map<String, dynamic>? body) =>
      (body?['message'] ?? body?['error'])?.toString();

  int _int(dynamic v, int fallback) =>
      v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? fallback);

  void _backToNumberStep() {
    setState(() {
      _accounts = null;
      _error = null;
      _selectedId = null;
    });
  }

  // ------------------------------------------------------------
  // STEP 1 — accounts fetch
  // ------------------------------------------------------------
  Future<void> _fetchAccounts() async {
    if (_loadingAccounts) return;

    final phone = _controller.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Enter your registered mobile number');
      return;
    }
    if (!_tenDigits.hasMatch(phone)) {
      setState(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loadingAccounts = true;
      _error = null;
    });

    try {
      final res = await http
          .post(
        Uri.parse(_accountsUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      )
          .timeout(const Duration(seconds: 20));

      final body = _decode(res);
      if (!mounted) return;

      if (!_isOk(res, body)) {
        setState(() => _error =
            _messageOf(body) ?? 'No account found with this mobile number');
        return;
      }

      final raw = (body?['data'] is Map) ? body!['data']['accounts'] : null;
      final accounts = (raw is List)
          ? raw
          .whereType<Map>()
          .map((e) => _Account.fromJson(Map<String, dynamic>.from(e)))
          .toList()
          : <_Account>[];

      if (accounts.isEmpty) {
        setState(() => _error = 'No account found with this mobile number');
        return;
      }

      setState(() {
        _phone = phone;
        _accounts = accounts;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Network error. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  // ------------------------------------------------------------
  // STEP 2 — selected account par OTP bhejo
  // ------------------------------------------------------------
  Future<void> _sendOtpFor(_Account account) async {
    if (_sendingOtp) return;

    setState(() {
      _sendingOtp = true;
      _selectedId = account.id;
      _error = null;
    });

    try {
      final payload = jsonEncode({'phone': _phone, 'userId': account.id});

      debugPrint('📲 [SEND OTP] URL     : $_sendOtpUrl');
      debugPrint('📲 [SEND OTP] Payload : $payload');

      final res = await http
          .post(
        Uri.parse(_sendOtpUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: payload,
      )
          .timeout(const Duration(seconds: 20));

      debugPrint('📲 [SEND OTP] Status  : ${res.statusCode}');
      debugPrint('📲 [SEND OTP] Response: ${res.body}');

      final body = _decode(res);
      if (!mounted) return;

      if (_isOk(res, body)) {
        final data = body?['data'] is Map ? body!['data'] as Map : const {};

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(_messageOf(body) ?? 'OTP sent')),
          );

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              fromSignup: false,
              identifier: _phone,
              userId: account.id,
              maskedPhone: (data['maskedPhone'] ?? '').toString(),
              expiresInSeconds: _int(data['expiresInSeconds'], 600),
              resendAfterSeconds: _int(data['resendAvailableInSeconds'], 60),
            ),
          ),
        );
      } else {
        setState(() => _error =
            _messageOf(body) ?? 'Could not send OTP (${res.statusCode})');
      }
    } catch (e) {
      debugPrint('📲 [SEND OTP] ERROR   : $e');
      if (mounted) {
        setState(() => _error = 'Network error. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingOtp = false;
          _selectedId = null;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------
  Widget _errorBox(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body(size: 12.5, color: Colors.redAccent)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: _controller,
          label: 'Registered Mobile Number',
          hint: '10-digit mobile number',
          icon: Icons.phone_iphone_rounded,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 2),
            child: Text(
              _error!,
              style: AppTextStyles.body(size: 11.5, color: Colors.redAccent)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'We will show the accounts linked to this number. '
              'Select one to receive the verification code.',
          style: AppTextStyles.body(size: 11.5, color: AppColors.slate600),
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: _loadingAccounts ? 'Checking...' : 'Send OTP',
          onTap: _loadingAccounts ? () {} : _fetchAccounts,
        ),
      ],
    );
  }

  Widget _listStep() {
    final accounts = _accounts!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          accounts.length == 1
              ? '1 account is registered with +91 $_phone'
              : '${accounts.length} accounts are registered with +91 $_phone',
          style: AppTextStyles.body(
            size: 13.5,
            weight: FontWeight.w700,
            color: AppColors.slate600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select the account for which you want to reset the password.',
          style: AppTextStyles.body(size: 12, color: AppColors.slate600),
        ),
        const SizedBox(height: 16),
        if (_error != null) _errorBox(_error!),
        for (final a in accounts) ...[
          _accountCard(a),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _sendingOtp ? null : _backToNumberStep,
          icon: const Icon(Icons.edit_outlined, size: 17),
          label: const Text('Change Mobile Number',
              style: TextStyle(fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: AppColors.blue600,
            side: BorderSide(color: AppColors.slate200),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _accountCard(_Account a) {
    final isThis = _sendingOtp && _selectedId == a.id;
    final initial = a.name.isNotEmpty ? a.name[0].toUpperCase() : '?';
    final subtitle = [
      if (a.agencyName.isNotEmpty) a.agencyName,
      if (a.branchName.isNotEmpty) a.branchName,
    ].join('  •  ');

    return Opacity(
      opacity: (_sendingOtp && !isThis) ? .5 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _sendingOtp ? null : () => _sendOtpFor(a),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isThis ? AppColors.blue500 : AppColors.slate200,
                width: isThis ? 1.6 : 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.blueGradient,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              a.name.isNotEmpty ? a.name : 'Unnamed',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body(
                                size: 15,
                                weight: FontWeight.w800,
                                color: AppColors.navy950,
                              ),
                            ),
                          ),
                          if (a.roleLabel.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.blue600.withOpacity(.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                a.roleLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.blue600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (a.maskedEmail.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          a.maskedEmail,
                          style: AppTextStyles.body(
                              size: 12, color: AppColors.slate600),
                        ),
                      ],
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(
                              size: 11, color: AppColors.slate400),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                isThis
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
                    : Icon(Icons.chevron_right_rounded,
                    color: AppColors.slate400),
              ],
            ),
          ),
        ),
      ),
    );
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
              title: 'Forgot password',
              subtitle: _onListStep
                  ? 'Choose your account'
                  : "We'll send a code to reset it",
              showBack: true,
              onBack: () {
                if (_onListStep && !_sendingOtp) {
                  _backToNumberStep();
                } else if (!_sendingOtp) {
                  Navigator.of(context).pop();
                }
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey(_onListStep),
                    child: _onListStep ? _listStep() : _numberStep(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}