import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../Screen/Activation_Payment_Screen.dart';
import '../Widget/Common_widget.dart';
import '../theme/app_theme.dart';
import 'New_password_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.fromSignup,
    this.identifier = '', // mobile number jis par OTP gaya
    this.userId = '', // forgot-password: select kiye hue account ki id
    this.registrationId = '', // signup: register API se aaya
    this.maskedPhone = '', // API se aaya: ********2589
    this.expiresInSeconds = 600,
    this.resendAfterSeconds = 60,
    this.isAgent = false, // true: agent self-registration OTP
  });

  /// true  → company signup verify → Activation payment
  /// false → forgot-password → New Password
  final bool fromSignup;
  final String identifier;
  final String userId;
  final String registrationId;
  final String maskedPhone;
  final int expiresInSeconds;
  final int resendAfterSeconds;
  final bool isAgent;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // ── Forgot-password APIs ──
  static const String _forgotVerifyUrl =
      'https://fastrecovery.in/api/Auth/forgot-password/verify-otp';
  static const String _forgotSendUrl =
      'https://fastrecovery.in/api/Auth/forgot-password/send-otp';

  // ── Company signup APIs ──
  static const String _signupVerifyUrl =
      'https://fastrecovery.in/api/companies/register/verify-otp';

  // TODO: web pe "Resend" dabake Network tab se is URL ko confirm karo.
  // (Ye guess hai, verify-otp wale pattern par bana hai.)
  static const String _signupResendUrl =
      'https://fastrecovery.in/api/companies/register/resend-otp';

  // ── Agent self-registration APIs ──
  // TODO: web pe agent registration ka OTP dalte waqt Network tab se dono URL
  // confirm karo (ye guess hain, agent-register wale pattern par bane hain).
  static const String _agentVerifyUrl =
      'https://fastrecovery.in/api/auth/agent-register/verify-otp';
  static const String _agentResendUrl =
      'https://fastrecovery.in/api/auth/agent-register/resend-otp';

  final List<TextEditingController> _controllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _timer;
  late int _expiryLeft;
  late int _resendLeft;
  late String _registrationId;
  String? _error;
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _registrationId = widget.registrationId;
    _expiryLeft = widget.expiresInSeconds;
    _resendLeft = widget.resendAfterSeconds;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ---------------- helpers ----------------
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_expiryLeft <= 0 && _resendLeft <= 0) {
        t.cancel();
        return;
      }
      setState(() {
        if (_expiryLeft > 0) _expiryLeft--;
        if (_resendLeft > 0) _resendLeft--;
      });
    });
  }

  String _mmss(int total) {
    final s = total.clamp(0, 99 * 60 + 59);
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  String get _otp => _controllers.map((c) => c.text).join();

  String get _maskedTarget {
    if (widget.maskedPhone.isNotEmpty) return widget.maskedPhone;
    final v = widget.identifier.trim();
    if (v.isEmpty) return 'your registered contact';
    if (v.contains('@')) {
      final parts = v.split('@');
      final name = parts.first;
      return '${name.isNotEmpty ? name[0] : ''}••••@${parts.last}';
    }
    return v.length > 2 ? '•••• ${v.substring(v.length - 2)}' : v;
  }

  int _int(dynamic v, int fallback) =>
      v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? fallback);

  Map<String, dynamic>? _decode(http.Response r) {
    try {
      final d = jsonDecode(r.body);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  bool _isOk(http.Response r, Map<String, dynamic>? body) =>
      r.statusCode >= 200 && r.statusCode < 300 && body?['success'] != false;

  String? _messageOf(Map<String, dynamic>? body) =>
      (body?['message'] ?? body?['error'])?.toString();

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onChanged(int i, String val) {
    if (_error != null) setState(() => _error = null);
    if (val.isNotEmpty && i < 5) {
      _focusNodes[i + 1].requestFocus();
    } else if (val.isEmpty && i > 0) {
      _focusNodes[i - 1].requestFocus();
    }
  }

  void _clearBoxes() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
  }

  // ---------------- API: verify ----------------
  Future<void> _verify() async {
    if (_isVerifying) return;

    final otp = _otp;
    if (otp.length != 6) {
      setState(() => _error = 'Enter the complete 6-digit code');
      return;
    }
    if (_expiryLeft <= 0) {
      setState(() => _error = 'Code expired. Please request a new one.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final value = widget.identifier.trim();

      // ───────────── SIGNUP ─────────────
      if (widget.fromSignup) {
        final response = await http
            .post(
          Uri.parse(widget.isAgent ? _agentVerifyUrl : _signupVerifyUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'registrationId': _registrationId, 'otp': otp}),
        )
            .timeout(const Duration(seconds: 90));

        debugPrint('SIGNUP VERIFY status: ${response.statusCode}');
        debugPrint('SIGNUP VERIFY body: ${response.body}');

        final body = _decode(response);
        if (!mounted) return;

        if (!_isOk(response, body)) {
          setState(
                  () => _error = _messageOf(body) ?? 'Invalid or expired code');
          return;
        }

        if (widget.isAgent) {
          final d = _asMap(body?['data']);
          _timer?.cancel();
          _showMessage((d['message'] ??
              body?['message'] ??
              'Registration submitted. Your account will be active once the admin activates it.')
              .toString());
          Navigator.of(context).popUntil((r) => r.isFirst);
          return;
        }

        final data = _asMap(body?['data']);
        final company = _asMap(data['company']);
        final companyId = (company['id'] ?? '').toString();
        final activationToken = (data['activationToken'] ?? '').toString();

        if (companyId.isEmpty || activationToken.isEmpty) {
          setState(() =>
          _error = 'Verified, but activation details are missing. Please contact support.');
          return;
        }

        _timer?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ActivationPaymentScreen(
              companyId: companyId,
              companyName: (company['companyName'] ?? '').toString(),
              activationToken: activationToken,
              activationFee: _int(data['activationFee'], 100),
              contactPhone: value,
            ),
          ),
        );
        return;
      }

      // ───────────── FORGOT PASSWORD ─────────────
      final response = await http
          .post(
        Uri.parse(_forgotVerifyUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': value,
          'userId': widget.userId,
          'otp': otp,
        }),
      )
          .timeout(const Duration(seconds: 20));

      final body = _decode(response);
      if (!mounted) return;

      if (!_isOk(response, body)) {
        setState(() => _error = _messageOf(body) ?? 'Invalid or expired code');
        return;
      }

      final data = _asMap(body?['data']);
      final resetToken = (data['resetToken'] ?? '').toString();
      final userId = (data['userId'] ?? widget.userId).toString();

      if (resetToken.isEmpty) {
        setState(() => _error = 'Could not verify code. Please try again.');
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewPasswordScreen(
            token: resetToken,
            userId: userId,
          ),
        ),
      );
    } on TimeoutException {
      debugPrint('VERIFY error: timeout');
      if (mounted) {
        setState(() => _error =
        'Server is taking too long. Your registration may already be submitted. '
            'Please wait a minute and check before trying again.');
      }
    } on SocketException catch (e) {
      debugPrint('VERIFY error: SocketException $e');
      if (mounted) {
        setState(() => _error = 'No internet connection. Please check and try again.');
      }
    } catch (e, st) {
      debugPrint('VERIFY error: $e\n$st');
      if (mounted) setState(() => _error = 'Something went wrong (${e.runtimeType}).');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ---------------- API: resend ----------------
  Future<void> _resend() async {
    if (_resendLeft > 0 || _isResending) return;
    setState(() => _isResending = true);

    try {
      final value = widget.identifier.trim();

      final http.Response response;
      if (widget.fromSignup) {
        response = await http
            .post(
          Uri.parse(widget.isAgent ? _agentResendUrl : _signupResendUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'registrationId': _registrationId}),
        )
            .timeout(const Duration(seconds: 20));
      } else {
        response = await http
            .post(
          Uri.parse(_forgotSendUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': value, 'userId': widget.userId}),
        )
            .timeout(const Duration(seconds: 20));
      }

      debugPrint('RESEND status: ${response.statusCode}');
      debugPrint('RESEND body: ${response.body}');

      final body = _decode(response);
      if (!mounted) return;

      if (_isOk(response, body)) {
        final data = _asMap(body?['data']);

        // Server naya registrationId de to usi se aage verify karna hai
        final newRegId = data['registrationId']?.toString() ?? '';
        if (widget.fromSignup && newRegId.isNotEmpty) {
          _registrationId = newRegId;
        }

        _clearBoxes();
        setState(() {
          _error = null;
          _expiryLeft = _int(data['expiresInSeconds'], 600);
          _resendLeft = _int(data['resendAvailableInSeconds'], 60);
        });
        _startTimer();
        _showMessage('A new code has been sent');
      } else {
        _showMessage(_messageOf(body) ?? 'Could not resend code. Try again.');
      }
    } catch (_) {
      _showMessage('Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final hasError = _error != null;
    final canResend = _resendLeft == 0 && !_isResending;

    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: c, width: 1.5),
    );

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AuthHero(
              title: 'Verify code',
              subtitle: 'Enter the 6-digit code sent to $_maskedTarget',
              showBack: true,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (i) {
                        return SizedBox(
                          width: 46,
                          height: 56,
                          child: TextField(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            enabled: !_isVerifying,
                            style: AppTextStyles.mono(
                                size: 20, weight: FontWeight.w600),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: Colors.white,
                              border: border(hasError
                                  ? Colors.redAccent
                                  : AppColors.slate200),
                              enabledBorder: border(hasError
                                  ? Colors.redAccent
                                  : AppColors.slate200),
                              focusedBorder: border(hasError
                                  ? Colors.redAccent
                                  : AppColors.blue500),
                              disabledBorder: border(AppColors.slate200),
                            ),
                            onChanged: (v) => _onChanged(i, v),
                          ),
                        );
                      }),
                    ),
                    if (hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _error!,
                            style: AppTextStyles.body(
                              size: 12,
                              color: Colors.redAccent,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text("Didn't get it? ",
                                style: AppTextStyles.body(
                                    size: 13, color: AppColors.slate600)),
                            GestureDetector(
                              onTap: canResend ? _resend : null,
                              child: Text(
                                _isResending
                                    ? 'Sending...'
                                    : (_resendLeft > 0
                                    ? 'Resend in ${_mmss(_resendLeft)}'
                                    : 'Resend'),
                                style: AppTextStyles.body(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: canResend
                                      ? AppColors.gold500
                                      : AppColors.slate400,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text('Expires in ',
                                style: AppTextStyles.body(
                                    size: 13, color: AppColors.slate600)),
                            Text(_mmss(_expiryLeft),
                                style: AppTextStyles.mono(
                                    size: 13,
                                    weight: FontWeight.w700,
                                    color: AppColors.gold500)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label:
                      _isVerifying ? 'Verifying...' : 'Verify & Continue',
                      icon: null,
                      onTap: _isVerifying ? () {} : _verify,
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