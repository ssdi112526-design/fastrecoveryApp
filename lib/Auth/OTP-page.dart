import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../Screen/home.dart';
import '../Widget/Common_widget.dart';
import '../theme/app_theme.dart';
import 'New_password_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.fromSignup});

  /// If true, this OTP is verifying a new signup → goes to Home.
  /// If false, it's part of the forgot-password flow → goes to New Password.
  final bool fromSignup;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _timer;
  int _secondsLeft = 29;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = 29;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  String get _timerLabel {
    final s = _secondsLeft.clamp(0, 999);
    return '00:${s.toString().padLeft(2, '0')}';
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

  void _onChanged(int i, String val) {
    if (val.isNotEmpty && i < 5) {
      _focusNodes[i + 1].requestFocus();
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
              title: 'Verify code',
              subtitle: 'Enter the 6-digit code sent to •••• 84 00',
              showBack: true,
              onBack: () => Navigator.of(context).pop(),
            ),
            Padding(
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
                          style: AppTextStyles.mono(size: 20, weight: FontWeight.w600),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: const BorderSide(color: AppColors.slate200, width: 1.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: const BorderSide(color: AppColors.slate200, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: const BorderSide(color: AppColors.blue500, width: 1.5),
                            ),
                          ),
                          onChanged: (v) => _onChanged(i, v),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text("Didn't get it? ",
                              style: AppTextStyles.body(size: 13, color: AppColors.slate600)),
                          GestureDetector(
                            onTap: _startTimer,
                            child: Text('Resend',
                                style: AppTextStyles.body(
                                    size: 13, weight: FontWeight.w600, color: AppColors.gold500)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text('Expires in ',
                              style: AppTextStyles.body(size: 13, color: AppColors.slate600)),
                          Text(_timerLabel,
                              style: AppTextStyles.mono(
                                  size: 13, weight: FontWeight.w700, color: AppColors.gold500)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    label: 'Verify & Continue',
                    icon: null,
                    onTap: () {
                      if (widget.fromSignup) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                              (route) => false,
                        );
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NewPasswordScreen()),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
