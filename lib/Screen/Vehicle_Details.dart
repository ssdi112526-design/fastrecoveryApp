import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Model_class/vehcial_detail_model.dart';
import '../theme/app_theme.dart';

class VehicleDetailsPopup extends StatefulWidget {
  final VehicleItem item;
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
        'searchItem': widget.item.toJson(),
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
    final subject = 'Vehicle Traced — ${widget.item.vehicleNumber}';

    final uri = Uri(
      scheme: 'mailto',
      query:
      'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(message)}',
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
    final item = widget.item;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xff0B1220) : const Color(0xffF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xff111827) : Colors.white,
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
            Text(
               '${item.vehicleNumber}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.navy950,
              ),
            ),
            const SizedBox(height: 2),
            // Text(
            //   '${item.customerName}',
            //       // '• ${item.vehicleModel}',
            //   style: TextStyle(
            //     fontSize: 16.5,
            //     fontWeight: FontWeight.w500,
            //     color: isDark ? Colors.white70 : AppColors.slate400,
            //   ),
            // ),
          ],
        ),
        // actions: [
        //   Padding(
        //     padding: const EdgeInsets.only(right: 14),
        //     child: Center(
        //       child: Container(
        //         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        //         decoration: BoxDecoration(
        //           color: AppColors.blue600.withOpacity(.1),
        //           borderRadius: BorderRadius.circular(20),
        //           border: Border.all(color: AppColors.blue600.withOpacity(.3)),
        //         ),
        //         child: Text(
        //           item.repoStatus.toUpperCase(),
        //           style: const TextStyle(
        //             color: AppColors.blue600,
        //             fontSize: 10,
        //             fontWeight: FontWeight.w800,
        //             letterSpacing: .3,
        //           ),
        //         ),
        //       ),
        //     ),
        //   ),
        // ],
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
                    (Icons.person_outline, 'Customer Name', item.customerName),
                    //(Icons.location_on_outlined, 'Address', item.addressLine1),
                    (Icons.location_city_outlined, 'City', item.city),
                    (Icons.map_outlined, 'State', item.state),
                    // (Icons.phone_outlined, 'Mobile Number', item.mobileNumber),
                    // (Icons.phone_android_outlined, 'Alternate Mobile', item.alternateMobileNumber),
                    // (Icons.numbers_outlined, 'Reference Number', item.referenceNumber),
                  ]),
                  const SizedBox(height: 18),
                  _popupSection('Vehicle Information', Icons.directions_car_outlined),
                  const SizedBox(height: 10),
                  _detailGrid([
                    (Icons.directions_car_outlined, 'Vehicle Number', item.vehicleNumber),
                    (Icons.confirmation_number_outlined, 'Chassis Number', item.chassisNumber),
                    (Icons.settings_outlined, 'Engine Number', item.engineNumber),
                    (Icons.category_outlined, 'Brand', item.vehicleBrand),
                    (Icons.car_repair_outlined, 'Model', item.vehicleModel),
                  ]),
                  //const SizedBox(height: 18),
                  //_popupSection('Finance Information', Icons.account_balance_wallet_outlined),
                 // const SizedBox(height: 10),

                  _detailGrid([
                    // (Icons.currency_rupee, 'EMI Amount', '₹${item.emiAmount}'),
                    // (Icons.money_off_csred_outlined, 'Due Amount', '₹${item.dueAmount}'),
                    // (Icons.account_balance_wallet_outlined, 'Outstanding', '₹${item.totalOutstandingAmount}'),
                    // (Icons.inbox_outlined, 'Bucket', item.bucket),
                  ]),

                  const SizedBox(height: 18),

                  _popupSection('Status', Icons.info_outline),

                  const SizedBox(height: 10),

                  _detailGrid([
                    (Icons.flag_outlined, 'Confirmation Status', item.confirmationStatus),
                    (Icons.info_outline, 'Repo Status', item.repoStatus),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.blue600),
        const SizedBox(width: 8),
        Text(
          title,
          style:  TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _detailGrid(List<(IconData, String, String)> details) {
    final rows = <Widget>[];

    for (int i = 0; i < details.length; i += 2) {
      final left = details[i];
      final right = i + 1 < details.length ? details[i + 1] : null;

      rows.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: i + 2 < details.length ? 14 : 0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _detailTile(left)),
              const SizedBox(width: 10),
              Expanded(
                child: right != null ? _detailTile(right) : const SizedBox(),
              ),
            ],
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _detailTile((IconData, String, String) detail) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          detail.$2,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:  TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white: Colors.black,
            letterSpacing: .9,
          ),
        ),
        const SizedBox(height: 4),
        Text(
            detail.$3,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style:  TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70: Colors.black54
            ),
        // Row(
        //   crossAxisAlignment: CrossAxisAlignment.start,
        //   children: [
        //     const Text(
        //       '• ',
        //       style: TextStyle(
        //         fontSize: 14,
        //         fontWeight: FontWeight.w700,
        //         color: AppColors.navy950,
        //       ),
        //     ),
        //     Expanded(
        //       child: Text(
        //         detail.$3,
        //         maxLines: 3,
        //         overflow: TextOverflow.ellipsis,
        //         style: const TextStyle(
        //           fontSize: 14,
        //           fontWeight: FontWeight.w700,
        //           color: AppColors.navy950,
        //         ),
        //       ),
        //     ),
        //   ],
         ),
      ],
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