import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../Widget/Common_widget.dart';
import '../theme/app_theme.dart';

/// OTP verify hone ke baad ye screen khulti hai:
/// 1. activation-order API se Razorpay order banta hai
/// 2. Razorpay checkout khulta hai (₹100)
/// 3. Payment ke baad (optional) backend ko confirm kiya jata hai
class ActivationPaymentScreen extends StatefulWidget {
  const ActivationPaymentScreen({
    super.key,
    required this.companyId,
    required this.companyName,
    required this.activationToken,
    this.activationFee = 100,
    this.contactPhone = '',
  });

  final String companyId;
  final String companyName;
  final String activationToken;
  final int activationFee;
  final String contactPhone;

  @override
  State<ActivationPaymentScreen> createState() =>
      _ActivationPaymentScreenState();
}

class _ActivationPaymentScreenState extends State<ActivationPaymentScreen> {
  static const String _orderUrl =
      'https://fastrecovery.in/api/companies/register/activation-order';

  // TODO: web pe payment karte waqt Network tab me dekho, Razorpay success ke
  // baad kaun si API hit hoti hai (verify / confirm). Uska URL yahan daalo.
  // Khali chhodoge to app backend ko confirm nahi karega (sirf Razorpay tak).
  static const String _verifyUrl = '';

  // Public Key ID (secret nahi). Order API se na aaye to ye fallback use hoga.
  static const String _fallbackKeyId = 'rzp_live_Tmx5vyR9QoS9R9';

  bool _creatingOrder = false;
  bool _confirming = false;
  bool _paid = false;
  String? _error;
  Map<String, dynamic>? _order; // activation-order ka data (retry par reuse)

  // ---------------- helpers ----------------
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

  bool get _busy => _creatingOrder || _confirming;

  // ---------------- Pay button ----------------
  // Same pattern jo SubscriptionPayment me chal raha hai:
  // order banao -> Razorpay() banao -> open -> Completer se result ka wait
  Future<void> _startPayment() async {
    if (_busy) return;

    setState(() {
      _creatingOrder = true;
      _error = null;
    });

    Razorpay? razorpay;
    try {
      // 1) Backend se order (retry par purana order reuse hota hai)
      if (_order == null) {
        final res = await http
            .post(
          Uri.parse(_orderUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'companyId': widget.companyId,
            'activationToken': widget.activationToken,
          }),
        )
            .timeout(const Duration(seconds: 30));

        debugPrint('ORDER status: ${res.statusCode}');
        debugPrint('ORDER body: ${res.body}');

        final body = _decode(res);
        if (!mounted) return;

        if (!_isOk(res, body) || body?['data'] is! Map) {
          setState(() =>
          _error = _messageOf(body) ?? 'Could not create order. Try again.');
          return;
        }
        _order = Map<String, dynamic>.from(body!['data'] as Map);
      }

      final o = _order!;
      final orderId = (o['orderId'] ?? o['razorpayOrderId'])?.toString();
      if (orderId == null || orderId.isEmpty) {
        setState(() => _error = 'Order ID not received from server');
        return;
      }

      // activation-order ka amount pehle se paise me hai (10000 = ₹100)
      final amountPaise =
          (o['amount'] as num?)?.toInt() ?? widget.activationFee * 100;
      final key = (o['razorpayKeyId'] ?? _fallbackKeyId).toString();

      // 2) Razorpay checkout
      razorpay = Razorpay();
      final completer = Completer<PaymentSuccessResponse?>();

      razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
        if (!completer.isCompleted) completer.complete(r);
      });
      razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
        debugPrint('RAZORPAY error: ${r.code} ${r.message}');
        if (mounted) {
          setState(() {
            _error = (r.message != null && r.message!.trim().isNotEmpty)
                ? r.message
                : 'Payment was cancelled or failed. Please try again.';
          });
        }
        if (!completer.isCompleted) completer.complete(null);
      });
      razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {});

      final options = <String, dynamic>{
        'key': key,
        'order_id': orderId,
        'amount': amountPaise,
        'currency': (o['currency'] ?? 'INR').toString(),
        'name': 'Fast Recovery',
        'description': 'Agency activation fee',
        'prefill': {
          if (widget.contactPhone.isNotEmpty) 'contact': widget.contactPhone,
        },
        'theme': {'color': '#2563EB'},
      };
      debugPrint('RAZORPAY open: $options');

      razorpay.open(options);

      final success = await completer.future;
      if (success == null) return; // cancel / fail: error upar set ho chuka

      // 3) Backend ko confirm
      await _confirmPayment(success);
    } catch (e, st) {
      debugPrint('PAY error: $e\n$st');
      if (mounted) {
        setState(() => _error = 'Could not start payment (${e.runtimeType}). Please try again.');
      }
    } finally {
      razorpay?.clear();
      if (mounted) setState(() => _creatingOrder = false);
    }
  }

  Future<void> _confirmPayment(PaymentSuccessResponse r) async {
    if (!mounted) return;
    setState(() {
      _confirming = true;
      _error = null;
    });

    try {
      if (_verifyUrl.isNotEmpty) {
        final res = await http
            .post(
          Uri.parse(_verifyUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'companyId': widget.companyId,
            'activationToken': widget.activationToken,
            'paymentId': _order?['paymentId'],
            'razorpay_order_id': r.orderId,
            'razorpay_payment_id': r.paymentId,
            'razorpay_signature': r.signature,
          }),
        )
            .timeout(const Duration(seconds: 30));

        debugPrint('VERIFY status: ${res.statusCode}');
        debugPrint('VERIFY body: ${res.body}');

        final body = _decode(res);
        if (!_isOk(res, body)) {
          if (mounted) {
            setState(() => _error =
            'Payment received (ID: ${r.paymentId}) but confirmation failed: '
                '${_messageOf(body) ?? res.statusCode}. Please contact support with this ID.');
          }
          return;
        }
      }

      if (mounted) setState(() => _paid = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
        'Payment received (ID: ${r.paymentId}) but we could not confirm it. '
            'Please contact support with this ID.');
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  // ---------------- UI ----------------
  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.body(
                size: 12.5,
                weight: FontWeight.w700,
                color: AppColors.slate600),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Text(
              value,
              style: AppTextStyles.body(
                  size: 14, color: const Color(0xFF0C1220)),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _payStep() {
    final fee = widget.activationFee;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('Company',
            widget.companyName.isNotEmpty ? widget.companyName : '-'),
        _row('Status', 'PENDING ACTIVATION'),
        _row('Registration Fee', '₹0 (Free)'),
        _row('First User Activation Fee', '₹$fee'),
        _row('Refund', 'Non-refundable'),
        const SizedBox(height: 4),
        if (_error != null) _errorBox(_error!),
        PrimaryButton(
          label: _creatingOrder
              ? 'Please wait...'
              : (_confirming ? 'Confirming payment...' : 'Pay ₹$fee'),
          icon: null,
          onTap: _busy ? () {} : _startPayment,
        ),
      ],
    );
  }

  Widget _doneStep() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, size: 48, color: Colors.green),
        ),
        const SizedBox(height: 20),
        Text(
          'Payment successful',
          style: AppTextStyles.body(
              size: 20,
              weight: FontWeight.w800,
              color: const Color(0xFF0C1220)),
        ),
        const SizedBox(height: 10),
        Text(
          'Your registration has been submitted for Super Admin verification. '
              'Your agency will be active within 24 hours.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(size: 13.5, color: AppColors.slate600),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Back to login',
          icon: null,
          onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy && !_paid,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AuthHero(
                title: _paid ? 'All done' : 'Registration submitted',
                subtitle: _paid
                    ? 'Verification in progress'
                    : 'Pay ₹${widget.activationFee} to submit for Super Admin verification',
                showBack: false,
                onBack: () {},
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                  child: _paid ? _doneStep() : _payStep(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}