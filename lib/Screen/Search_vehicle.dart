import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class VehicleDetailsPopup extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onClose;

  const VehicleDetailsPopup({
    super.key,
    required this.item,
    required this.onClose,
  });

  @override
  State<VehicleDetailsPopup> createState() => _VehicleDetailsPopupState();
}

class _VehicleDetailsPopupState extends State<VehicleDetailsPopup> {
  static const String _confirmationsUrl =
      'https://www.fastrecovery.in/api/confirmations';

  String? _sharingChannel;

  String _value(String key) {
    final value = widget.item[key];
    if (value == null) return '-';
    final text = value.toString();
    if (text.isEmpty || text == 'null') return '-';
    return text;
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('token');
    if (stored != null && stored.isNotEmpty) return stored;
    return null;
  }

  void _showSnack(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          backgroundColor:
          isError ? const Color(0xff991B1B) : const Color(0xff0F3D68),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
  }

  Future<void> _shareReport(String channel) async {
    if (_sharingChannel != null) return;

    setState(() => _sharingChannel = channel);

    try {
      final token = await _getToken();

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final payload = {
        'searchItem': widget.item,
        'traceMode': 'ONLINE',
        'shareChannel': channel,
      };

      final response = await http
          .post(
        Uri.parse(_confirmationsUrl),
        headers: headers,
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = null;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Unable to share report';
        if (body is Map && body['message'] != null) {
          message = body['message'].toString();
        }
        _showSnack(message, isError: true);
        return;
      }

      if (body is! Map || body['success'] != true) {
        _showSnack('Unable to share report', isError: true);
        return;
      }

      final traceReport = body['traceReport'];
      if (traceReport is! Map) {
        _showSnack('Report generated, but no share link received', isError: true);
        return;
      }

      final message = traceReport['message']?.toString() ?? '';
      final adminPhone = traceReport['adminPhone']?.toString() ?? '';
      final whatsAppUrl = traceReport['whatsAppUrl']?.toString() ?? '';

      switch (channel) {
        case 'whatsapp':
          await _openWhatsApp(whatsAppUrl);
          break;
        case 'email':
          await _openEmail(message: message);
          break;
        case 'sms':
          await _openSms(phone: adminPhone, message: message);
          break;
      }
    } on Exception catch (e) {
      debugPrint('❌ SHARE REPORT ERROR: $e');
      if (!mounted) return;
      _showSnack('Something went wrong. Please try again.', isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _sharingChannel = null);
    }
  }

  Future<void> _openWhatsApp(String whatsAppUrl) async {
    if (whatsAppUrl.isEmpty) {
      _showSnack('WhatsApp link not available', isError: true);
      return;
    }

    final uri = Uri.parse(whatsAppUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Could not open WhatsApp', isError: true);
    }
  }

  Future<void> _openEmail({required String message}) async {
    final caseCode = _value('caseCode') != '-' ? _value('caseCode') : 'Vehicle Trace Report';

    final uri = Uri(
      scheme: 'mailto',
      query:
      'subject=${Uri.encodeComponent('Vehicle Traced — $caseCode')}&body=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnack('No email app found on this device', isError: true);
    }
  }

  Future<void> _openSms({required String phone, required String message}) async {
    if (phone.isEmpty) {
      _showSnack('Admin phone number not available', isError: true);
      return;
    }

    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnack('Could not open messaging app', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final vehicle = _value('vehicleNumber');
    final chassis = _value('chassisNumber');
    final customer = _value('customerName');
    final bank = _value('bankName');
    final branch = _value('branchName');
    final brand = _value('vehicleBrand');
    final model = _value('vehicleModel');
    final status = _value('repoStatus');
    final address = _value('addressLine1');
    final emi = _value('emiAmount');
    final due = _value('dueAmount');
    final outstanding = _value('totalOutstandingAmount');
    final loanAccount = _value('loanAccountNumber');
    final engine = _value('engineNumber');
    final contact1 = _value('contactPerson1Phone');
    final contact2 = _value('contactPerson2Phone');
    final contact3 = _value('contactPerson3Phone');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xff0B1220) : const Color(0xffF8FAFC),
      appBar: AppBar(
        backgroundColor:
        isDark ? const Color(0xff111827) : Colors.white,
        elevation: 0.5,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        leading: IconButton(
          onPressed: widget.onClose,
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : AppColors.navy950,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("vehicle Details",style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.navy950,
            ),
          ),
            Text(
              vehicle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : AppColors.navy950,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$brand • $model',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : AppColors.slate400,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.blue600.withOpacity(.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.blue600.withOpacity(.3)),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.blue600,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  _popupSection('Customer Information', Icons.person_outline),
                  const SizedBox(height: 10),
                  _detailGrid([
                    (Icons.person_outline, 'Customer Name', customer),
                    (Icons.location_on_outlined, 'Address', address),
                    (Icons.call_outlined, 'Contact 1', contact1),
                    (Icons.call_outlined, 'Contact 2', contact2),
                    (Icons.call_outlined, 'Contact 3', contact3),
                  ]),
                  const SizedBox(height: 18),
                  _popupSection('Vehicle Information', Icons.directions_car_outlined),
                  const SizedBox(height: 10),
                  _detailGrid([
                    (Icons.directions_car_outlined, 'Vehicle Number', vehicle),
                    (Icons.confirmation_number_outlined, 'Chassis Number', chassis),
                    (Icons.settings_outlined, 'Engine Number', engine),
                    (Icons.category_outlined, 'Brand', brand),
                    (Icons.car_repair_outlined, 'Model', model),
                  ]),
                  const SizedBox(height: 18),
                  _popupSection('Finance Information', Icons.account_balance_wallet_outlined),
                  const SizedBox(height: 10),
                  _detailGrid([
                    (Icons.account_balance_outlined, 'Bank', bank),
                    (Icons.account_tree_outlined, 'Branch', branch),
                    (Icons.receipt_long_outlined, 'Loan Account No.', loanAccount),
                    (Icons.currency_rupee, 'EMI Amount', '₹$emi'),
                    (Icons.money_off_csred_outlined, 'Due Amount', '₹$due'),
                    (Icons.account_balance_wallet_outlined, 'Outstanding', '₹$outstanding'),
                  ]),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _buildActionBar(isDark),
        ],
      ),
    );
  }

  Widget _popupSection(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.blue600),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy950),
        ),
      ],
    );
  }

  Widget _detailGrid(List<(IconData, String, String)> details) {
    final hiddenFields = {
      'Contact 1',
      'Contact 2',
      'Contact 3',
      'Case Code',
      'Vehicle Type',
      'City',
      'State',
      'Pincode',
      'Due Amount',
      'Bucket',
      'Yeah Sub',
    };

    final visibleDetails = details
        .where((detail) => !hiddenFields.contains(detail.$2))
        .toList();

    final rows = <Widget>[];

    for (int i = 0; i < visibleDetails.length; i += 2) {
      final left = visibleDetails[i];
      final right =
      i + 1 < visibleDetails.length ? visibleDetails[i + 1] : null;

      rows.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: i + 2 < visibleDetails.length ? 10 : 0,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _detailTile(left, i + 1),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: right != null
                      ? _detailTile(right, i + 2)
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xffE2E8F0),
        ),
      ),
      child: Column(
        children: rows,
      ),
    );
  }

  Widget _detailTile(
      (IconData, String, String) detail,
      int number,
      ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xffE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.blue600.withOpacity(.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.blue600,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate400,
                    letterSpacing: .3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail.$3,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy950,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff111827) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xff334155) : const Color(0xffE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _actionButton(
              channel: 'whatsapp',
              label: 'WhatsApp',
              icon: Icons.chat_rounded,
              color: const Color(0xff25D366),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionButton(
              channel: 'email',
              label: 'Email',
              icon: Icons.email_rounded,
              color: AppColors.blue600,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionButton(
              channel: 'sms',
              label: 'SMS',
              icon: Icons.sms_rounded,
              color: const Color(0xffF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String channel,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isLoading = _sharingChannel == channel;
    final isDisabled = _sharingChannel != null && !isLoading;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : () => _shareReport(channel),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(isDisabled ? .05 : .12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withOpacity(isDisabled ? .15 : .35),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              isLoading
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
                  : Icon(icon, size: 20, color: isDisabled ? color.withOpacity(.4) : color),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDisabled ? color.withOpacity(.4) : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}