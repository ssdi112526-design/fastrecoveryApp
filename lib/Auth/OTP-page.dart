import 'dart:async';
import 'dart:convert';
import 'package:fastrecovery/Service/SharedPreferenceService.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../Screen/Find_vehicle.dart';
import '../Widget/Common_widget.dart';
import '../theme/app_theme.dart';
import 'New_password_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.fromSignup,
    this.identifier = '', // mobile ya email jis par OTP gaya
    this.userId = '', // forgot-password: select kiye hue account ki id
    this.maskedPhone = '', // API se aaya: ********8500
    this.expiresInSeconds = 600, // API: expiresInSeconds
    this.resendAfterSeconds = 60, // API: resendAvailableInSeconds
  });

  /// true  → signup verify → Home
  /// false → forgot-password → New Password
  final bool fromSignup;
  final String identifier;
  final String userId;
  final String maskedPhone;
  final int expiresInSeconds;
  final int resendAfterSeconds;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // ── Forgot-password APIs ──
  static const String _forgotVerifyUrl =
      'https://fastrecovery.in/api/auth/forgot-password/verify-otp';
  static const String _forgotSendUrl =
      'https://fastrecovery.in/api/auth/forgot-password/send-otp';

  // ── Signup APIs (pehle jaise) ──
  // TODO: apne backend ke sahi endpoints daalo
  static const String _signupVerifyUrl =
      'https://www.fastrecovery.in/api/auth/verify-otp';
  static const String _signupResendUrl =
      'https://www.fastrecovery.in/api/auth/forgot-password';

  final List<TextEditingController> _controllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _timer;
  late int _expiryLeft; // OTP kitni der mein expire hoga
  late int _resendLeft; // resend kitni der baad available hoga
  String? _error;
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
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
      _focusNodes[i - 1].requestFocus(); // delete karne par pichle box par
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
      return; // ← adhura OTP ho to aage nahi jayega
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

      final http.Response response;
      if (widget.fromSignup) {
        response = await http
            .post(
          Uri.parse(_signupVerifyUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            if (value.contains('@')) 'email': value else 'phone': value,
            'otp': otp,
          }),
        )
            .timeout(const Duration(seconds: 20));
      } else {
        // {phone, userId, otp}
        response = await http
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
      }

      final body = _decode(response);
      if (!mounted) return;

      if (!_isOk(response, body)) {
        setState(() => _error = _messageOf(body) ?? 'Invalid or expired code');
        return;
      }

      if (widget.fromSignup) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
        );
        return;
      }

      // Forgot-password: data.resetToken aage New Password screen ko chahiye
      final data = body?['data'] is Map ? body!['data'] as Map : const {};
      final resetToken = (data['resetToken'] ?? '').toString();
      final userId = (data['userId'] ?? widget.userId).toString();

      if (resetToken.isEmpty) {
        setState(() => _error = 'Could not verify code. Please try again.');
        return;
      }

      // final token = SharedPreferenceService.getToken();
      // if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewPasswordScreen(
            token: resetToken,
            userId: userId,
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Network error. Please try again.');
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
          Uri.parse(_signupResendUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(
            value.contains('@') ? {'email': value} : {'phone': value},
          ),
        )
            .timeout(const Duration(seconds: 20));
      } else {
        // send-otp: {phone, userId}
        response = await http
            .post(
          Uri.parse(_forgotSendUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': value, 'userId': widget.userId}),
        )
            .timeout(const Duration(seconds: 20));
      }

      final body = _decode(response);
      if (!mounted) return;

      if (_isOk(response, body)) {
        final data = body?['data'] is Map ? body!['data'] as Map : const {};
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