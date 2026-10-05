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


//
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:share_plus/share_plus.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:url_launcher/url_launcher.dart';
// import '../Model_class/vehcial_detail_model.dart';
// import '../theme/app_theme.dart';
//
// class VehicleDetailsPopup extends StatefulWidget {
//   final VehicleItem item;
//   final VoidCallback onClose;
//
//   const VehicleDetailsPopup({
//     super.key,
//     required this.item,
//     required this.onClose,
//   });
//
//   @override
//   State<VehicleDetailsPopup> createState() => _VehicleDetailsPopupState();
// }
//
// class _VehicleDetailsPopupState extends State<VehicleDetailsPopup> {
//   static const String _confirmationsUrl =
//       'https://www.fastrecovery.in/api/confirmations';
//   static const String _whatsappRecipientsUrl =
//       'https://www.fastrecovery.in/api/confirmations/whatsapp-recipients';
//
//   String? _sharingChannel;
//
//   Future<String?> _getToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     final stored = prefs.getString('token');
//     if (stored != null && stored.isNotEmpty) return stored;
//     return null;
//   }
//
//   void _showSnack(String message, {bool isError = true}) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context)
//       ..hideCurrentSnackBar()
//       ..showSnackBar(
//         SnackBar(
//           behavior: SnackBarBehavior.floating,
//           margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
//           backgroundColor:
//           isError ? const Color(0xff991B1B) : const Color(0xff0F3D68),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(14),
//           ),
//           content: Text(
//             message,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 12.5,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ),
//       );
//   }
//
//   // ── WhatsApp: fetch recipients → show selection popup ──────────────────────
//   Future<void> _handleWhatsAppTap() async {
//     if (_sharingChannel != null) return;
//     setState(() => _sharingChannel = 'whatsapp_loading');
//
//     try {
//       final token = await _getToken();
//       final headers = <String, String>{
//         'Accept': 'application/json',
//         if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
//       };
//
//       final response = await http
//           .get(Uri.parse(_whatsappRecipientsUrl), headers: headers)
//           .timeout(const Duration(seconds: 20));
//
//       if (!mounted) return;
//
//       dynamic body;
//       try {
//         body = jsonDecode(response.body);
//       } catch (_) {
//         body = null;
//       }
//
//       if (response.statusCode < 200 ||
//           response.statusCode >= 300 ||
//           body is! Map ||
//           body['success'] != true) {
//         _showSnack('Could not fetch recipients', isError: true);
//         return;
//       }
//
//       final List<dynamic> raw =
//           (body['data']?['adminRecipients'] as List?) ?? [];
//
//       final recipients = raw
//           .whereType<Map>()
//           .map((e) => _Recipient(
//         id: e['id']?.toString() ?? '',
//         name: e['name']?.toString() ?? '',
//         phone: e['phone']?.toString() ?? '',
//         roleLabel: e['roleLabel']?.toString() ?? '',
//       ))
//           .toList();
//
//       if (recipients.isEmpty) {
//         _showSnack('No recipients found', isError: true);
//         return;
//       }
//
//       // Show selection bottom-sheet
//       if (!mounted) return;
//       await _showRecipientSheet(recipients);
//     } on Exception catch (e) {
//       debugPrint('❌ RECIPIENTS ERROR: $e');
//       if (!mounted) return;
//       _showSnack('Something went wrong. Please try again.', isError: true);
//     } finally {
//       if (mounted) setState(() => _sharingChannel = null);
//     }
//   }
//
//   Future<void> _showRecipientSheet(List<_Recipient> recipients) async {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final selected = <String>{};   // selected recipient ids
//     bool isSending = false;
//
//     await showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (ctx) {
//         return StatefulBuilder(
//           builder: (ctx, setSheet) {
//             return Container(
//               decoration: BoxDecoration(
//                 color: isDark ? const Color(0xff1E293B) : Colors.white,
//                 borderRadius:
//                 const BorderRadius.vertical(top: Radius.circular(24)),
//               ),
//               padding: EdgeInsets.fromLTRB(
//                 20,
//                 20,
//                 20,
//                 20 + MediaQuery.of(ctx).viewInsets.bottom,
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Handle bar
//                   Center(
//                     child: Container(
//                       width: 40,
//                       height: 4,
//                       decoration: BoxDecoration(
//                         color: isDark
//                             ? const Color(0xff475569)
//                             : const Color(0xffCBD5E1),
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 18),
//
//                   // Title
//                   Row(
//                     children: [
//                       const Icon(Icons.chat_rounded,
//                           color: Color(0xff25D366), size: 22),
//                       const SizedBox(width: 8),
//                       Text(
//                         'Send via WhatsApp',
//                         style: TextStyle(
//                           fontSize: 17,
//                           fontWeight: FontWeight.w800,
//                           color: isDark ? Colors.white : AppColors.navy950,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     'Select recipients to send the report',
//                     style: TextStyle(
//                       fontSize: 13,
//                       color: isDark ? Colors.white54 : Colors.black45,
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//
//                   // Recipient list
//                   ...recipients.map((r) {
//                     final isChecked = selected.contains(r.id);
//                     return InkWell(
//                       onTap: () {
//                         setSheet(() {
//                           if (isChecked) {
//                             selected.remove(r.id);
//                           } else {
//                             selected.add(r.id);
//                           }
//                         });
//                       },
//                       borderRadius: BorderRadius.circular(12),
//                       child: Container(
//                         margin: const EdgeInsets.only(bottom: 10),
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 14, vertical: 12),
//                         decoration: BoxDecoration(
//                           color: isChecked
//                               ? const Color(0xff25D366).withOpacity(.1)
//                               : (isDark
//                               ? const Color(0xff0F172A)
//                               : const Color(0xffF8FAFC)),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(
//                             color: isChecked
//                                 ? const Color(0xff25D366).withOpacity(.5)
//                                 : (isDark
//                                 ? const Color(0xff334155)
//                                 : const Color(0xffE2E8F0)),
//                           ),
//                         ),
//                         child: Row(
//                           children: [
//                             // Avatar
//                             CircleAvatar(
//                               radius: 20,
//                               backgroundColor: const Color(0xff25D366)
//                                   .withOpacity(.15),
//                               child: Text(
//                                 r.name.isNotEmpty
//                                     ? r.name[0].toUpperCase()
//                                     : '?',
//                                 style: const TextStyle(
//                                   color: Color(0xff25D366),
//                                   fontWeight: FontWeight.w800,
//                                   fontSize: 15,
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(width: 12),
//
//                             // Name + role
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     r.name,
//                                     style: TextStyle(
//                                       fontSize: 14.5,
//                                       fontWeight: FontWeight.w700,
//                                       color: isDark
//                                           ? Colors.white
//                                           : AppColors.navy950,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 2),
//                                   Row(
//                                     children: [
//                                       Icon(Icons.phone_outlined,
//                                           size: 11,
//                                           color: isDark
//                                               ? Colors.white38
//                                               : Colors.black38),
//                                       const SizedBox(width: 3),
//                                       Text(
//                                         r.phone,
//                                         style: TextStyle(
//                                           fontSize: 12,
//                                           color: isDark
//                                               ? Colors.white54
//                                               : Colors.black45,
//                                         ),
//                                       ),
//                                       const SizedBox(width: 8),
//                                       Container(
//                                         padding: const EdgeInsets.symmetric(
//                                             horizontal: 6, vertical: 2),
//                                         decoration: BoxDecoration(
//                                           color: AppColors.blue600
//                                               .withOpacity(.1),
//                                           borderRadius:
//                                           BorderRadius.circular(6),
//                                         ),
//                                         child: Text(
//                                           r.roleLabel,
//                                           style: const TextStyle(
//                                             fontSize: 10,
//                                             fontWeight: FontWeight.w700,
//                                             color: AppColors.blue600,
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                             ),
//
//                             // Checkbox
//                             Checkbox(
//                               value: isChecked,
//                               activeColor: const Color(0xff25D366),
//                               shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(4)),
//                               onChanged: (_) {
//                                 setSheet(() {
//                                   if (isChecked) {
//                                     selected.remove(r.id);
//                                   } else {
//                                     selected.add(r.id);
//                                   }
//                                 });
//                               },
//                             ),
//                           ],
//                         ),
//                       ),
//                     );
//                   }),
//
//                   const SizedBox(height: 8),
//
//                   // Send button
//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton.icon(
//                       onPressed: (selected.isEmpty || isSending)
//                           ? null
//                           : () async {
//                         setSheet(() => isSending = true);
//                         Navigator.pop(ctx);           // close sheet
//                         await _shareToSelectedRecipients(
//                           recipients
//                               .where((r) => selected.contains(r.id))
//                               .toList(),
//                         );
//                       },
//                       icon: isSending
//                           ? const SizedBox(
//                         width: 16,
//                         height: 16,
//                         child: CircularProgressIndicator(
//                           strokeWidth: 2,
//                           color: Colors.white,
//                         ),
//                       )
//                           : const Icon(Icons.send_rounded, size: 18),
//                       label: Text(
//                         selected.isEmpty
//                             ? 'Select at least one'
//                             : 'Send to ${selected.length} recipient${selected.length > 1 ? 's' : ''}',
//                       ),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xff25D366),
//                         foregroundColor: Colors.white,
//                         disabledBackgroundColor:
//                         const Color(0xff25D366).withOpacity(.3),
//                         padding: const EdgeInsets.symmetric(vertical: 14),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(14),
//                         ),
//                         textStyle: const TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w700,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   // Send report to each selected recipient one-by-one
//   Future<void> _shareToSelectedRecipients(List<_Recipient> recipients) async {
//     if (_sharingChannel != null) return;
//     setState(() => _sharingChannel = 'whatsapp');
//
//     try {
//       final token = await _getToken();
//       final headers = <String, String>{
//         'Accept': 'application/json',
//         'Content-Type': 'application/json',
//         if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
//       };
//
//       final payload = {
//         'searchItem': widget.item.toJson(),
//         'traceMode': 'ONLINE',
//         'shareChannel': 'whatsapp',
//         'recipientId': recipients.first.id,
//         'recipientPhone': recipients.first.phone,
//       };
//
//       final response = await http
//           .post(
//         Uri.parse(_confirmationsUrl),
//         headers: headers,
//         body: jsonEncode(payload),
//       )
//           .timeout(const Duration(seconds: 30));
//
//       if (!mounted) return;
//
//       dynamic body;
//       try {
//         body = jsonDecode(response.body);
//       } catch (_) {
//         body = null;
//       }
//
//       if (response.statusCode < 200 ||
//           response.statusCode >= 300 ||
//           body is! Map ||
//           body['success'] != true) {
//         _showSnack('Failed to generate report', isError: true);
//         return;
//       }
//
//       final traceReport = body['traceReport'];
//       if (traceReport is! Map) {
//         _showSnack('No report data received', isError: true);
//         return;
//       }
//
//       final messageText = traceReport['message']?.toString() ?? '';
//       if (messageText.isEmpty) {
//         _showSnack('Message content is empty', isError: true);
//         return;
//       }
//
//       final encoded = Uri.encodeComponent(messageText);
//
//       // Har recipient ke liye alag WhatsApp open karo with uska number
//       for (int i = 0; i < recipients.length; i++) {
//         final phone = recipients[i].phone.replaceAll(RegExp(r'\D'), '');
//         final fullPhone = phone.startsWith('91') ? phone : '91$phone';
//
//         // whatsapp://send?phone=919XXXXXXXXX&text=MESSAGE
//         // Yeh directly us contact ka chat open karega — user sirf Send dabaye
//         final uri = Uri.parse('whatsapp://send?phone=$fullPhone&text=$encoded');
//
//         debugPrint('📲 Opening for ${recipients[i].name}: $uri');
//
//         if (await canLaunchUrl(uri)) {
//           await launchUrl(uri, mode: LaunchMode.externalApplication);
//           // WhatsApp open hone do, phir app pe wapas aao
//           await Future.delayed(const Duration(seconds: 4));
//         } else {
//           _showSnack(
//             'WhatsApp not found for ${recipients[i].name}',
//             isError: true,
//           );
//         }
//       }
//     } on Exception catch (e) {
//       debugPrint('❌ SHARE WHATSAPP ERROR: $e');
//       if (!mounted) return;
//       _showSnack('Something went wrong. Please try again.', isError: true);
//     } finally {
//       if (mounted) setState(() => _sharingChannel = null);
//     }
//   }
//
//   Future<void> _shareReport(String channel) async {
//     if (_sharingChannel != null) return;
//
//     setState(() => _sharingChannel = channel);
//
//     try {
//       final token = await _getToken();
//
//       final headers = <String, String>{
//         'Accept': 'application/json',
//         'Content-Type': 'application/json',
//         if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
//       };
//
//       final payload = {
//         'searchItem': widget.item.toJson(),
//         'traceMode': 'ONLINE',
//         'shareChannel': channel,
//       };
//
//       final response = await http
//           .post(
//         Uri.parse(_confirmationsUrl),
//         headers: headers,
//         body: jsonEncode(payload),
//       )
//           .timeout(const Duration(seconds: 30));
//
//       if (!mounted) return;
//
//       dynamic body;
//       try {
//         body = jsonDecode(response.body);
//       } catch (_) {
//         body = null;
//       }
//
//       if (response.statusCode < 200 || response.statusCode >= 300) {
//         String message = 'Unable to share report';
//         if (body is Map && body['message'] != null) {
//           message = body['message'].toString();
//         }
//         _showSnack(message, isError: true);
//         return;
//       }
//
//       if (body is! Map || body['success'] != true) {
//         _showSnack('Unable to share report', isError: true);
//         return;
//       }
//
//       final traceReport = body['traceReport'];
//       if (traceReport is! Map) {
//         _showSnack('Report generated, but no share link received',
//             isError: true);
//         return;
//       }
//
//       final message = traceReport['message']?.toString() ?? '';
//       final adminPhone = traceReport['adminPhone']?.toString() ?? '';
//
//       switch (channel) {
//         case 'email':
//           await _openEmail(message: message);
//           break;
//         case 'sms':
//           await _openSms(phone: adminPhone, message: message);
//           break;
//       }
//     } on Exception catch (e) {
//       debugPrint('❌ SHARE REPORT ERROR: $e');
//       if (!mounted) return;
//       _showSnack('Something went wrong. Please try again.', isError: true);
//     } finally {
//       if (mounted) setState(() => _sharingChannel = null);
//     }
//   }
//
//   Future<void> _openEmail({required String message}) async {
//     final subject = 'Vehicle Traced — ${widget.item.vehicleNumber}';
//     final uri = Uri(
//       scheme: 'mailto',
//       query:
//       'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(message)}',
//     );
//     if (await canLaunchUrl(uri)) {
//       await launchUrl(uri);
//     } else {
//       _showSnack('No email app found on this device', isError: true);
//     }
//   }
//
//   Future<void> _openSms(
//       {required String phone, required String message}) async {
//     if (phone.isEmpty) {
//       _showSnack('Admin phone number not available', isError: true);
//       return;
//     }
//     final uri = Uri(
//       scheme: 'sms',
//       path: phone,
//       queryParameters: {'body': message},
//     );
//     if (await canLaunchUrl(uri)) {
//       await launchUrl(uri);
//     } else {
//       _showSnack('Could not open messaging app', isError: true);
//     }
//   }
//
//   // ── UI ─────────────────────────────────────────────────────────────────────
//
//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final item = widget.item;
//
//     return Scaffold(
//       backgroundColor:
//       isDark ? const Color(0xff0B1220) : const Color(0xffF8FAFC),
//       appBar: AppBar(
//         backgroundColor: isDark ? const Color(0xff111827) : Colors.white,
//         elevation: 0.5,
//         scrolledUnderElevation: 0.5,
//         surfaceTintColor: Colors.transparent,
//         centerTitle: false,
//         leading: IconButton(
//           onPressed: widget.onClose,
//           icon: Icon(
//             Icons.arrow_back_rounded,
//             color: isDark ? Colors.white : AppColors.navy950,
//           ),
//         ),
//         title: Text(
//           item.vehicleNumber,
//           style: TextStyle(
//             fontSize: 22,
//             fontWeight: FontWeight.w800,
//             color: isDark ? Colors.white : AppColors.navy950,
//           ),
//         ),
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
//               child: Column(
//                 children: [
//                   _popupSection(
//                       'Customer Information', Icons.person_outline),
//                   const SizedBox(height: 10),
//                   _detailGrid([
//                     (Icons.person_outline, 'Customer Name',
//                     item.customerName),
//                     (Icons.location_city_outlined, 'City', item.city),
//                     (Icons.map_outlined, 'State', item.state),
//                   ]),
//                   const SizedBox(height: 18),
//                   _popupSection(
//                       'Vehicle Information', Icons.directions_car_outlined),
//                   const SizedBox(height: 10),
//                   _detailGrid([
//                     (Icons.directions_car_outlined, 'Vehicle Number',
//                     item.vehicleNumber),
//                     (Icons.confirmation_number_outlined, 'Chassis Number',
//                     item.chassisNumber),
//                     (Icons.settings_outlined, 'Engine Number',
//                     item.engineNumber),
//                     (Icons.category_outlined, 'Brand', item.vehicleBrand),
//                     (Icons.car_repair_outlined, 'Model', item.vehicleModel),
//                   ]),
//                   const SizedBox(height: 18),
//                   _popupSection('Status', Icons.info_outline),
//                   const SizedBox(height: 10),
//                   _detailGrid([
//                     (Icons.flag_outlined, 'Confirmation Status',
//                     item.confirmationStatus),
//                     (Icons.info_outline, 'Repo Status', item.repoStatus),
//                   ]),
//                   const SizedBox(height: 16),
//                 ],
//               ),
//             ),
//           ),
//           _buildActionBar(isDark),
//         ],
//       ),
//     );
//   }
//
//   Widget _popupSection(String title, IconData icon) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     return Row(
//       children: [
//         Icon(icon, size: 22, color: AppColors.blue600),
//         const SizedBox(width: 8),
//         Text(
//           title,
//           style: TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.w800,
//             color: isDark ? Colors.white : Colors.black,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _detailGrid(List<(IconData, String, String)> details) {
//     final rows = <Widget>[];
//     for (int i = 0; i < details.length; i += 2) {
//       final left = details[i];
//       final right = i + 1 < details.length ? details[i + 1] : null;
//       rows.add(
//         Padding(
//           padding: EdgeInsets.only(bottom: i + 2 < details.length ? 14 : 0),
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Expanded(child: _detailTile(left)),
//               const SizedBox(width: 10),
//               Expanded(
//                   child:
//                   right != null ? _detailTile(right) : const SizedBox()),
//             ],
//           ),
//         ),
//       );
//     }
//     return Column(children: rows);
//   }
//
//   Widget _detailTile((IconData, String, String) detail) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           detail.$2,
//           maxLines: 1,
//           overflow: TextOverflow.ellipsis,
//           style: TextStyle(
//             fontSize: 16.5,
//             fontWeight: FontWeight.w600,
//             color: isDark ? Colors.white : Colors.black,
//             letterSpacing: .9,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           detail.$3,
//           maxLines: 3,
//           overflow: TextOverflow.ellipsis,
//           style: TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w600,
//             color: isDark ? Colors.white70 : Colors.black54,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildActionBar(bool isDark) {
//     return Container(
//       padding: EdgeInsets.fromLTRB(
//         16,
//         14,
//         16,
//         14 + MediaQuery.of(context).padding.bottom,
//       ),
//       decoration: BoxDecoration(
//         color: isDark ? const Color(0xff111827) : Colors.white,
//         border: Border(
//           top: BorderSide(
//             color:
//             isDark ? const Color(0xff334155) : const Color(0xffE2E8F0),
//           ),
//         ),
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: _actionButton(
//               channel: 'whatsapp',
//               label: 'WhatsApp',
//               icon: Icons.chat_rounded,
//               color: const Color(0xff25D366),
//               onTap: _handleWhatsAppTap,   // ← custom handler
//             ),
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: _actionButton(
//               channel: 'email',
//               label: 'Email',
//               icon: Icons.email_rounded,
//               color: AppColors.blue600,
//               onTap: () => _shareReport('email'),
//             ),
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: _actionButton(
//               channel: 'sms',
//               label: 'SMS',
//               icon: Icons.sms_rounded,
//               color: const Color(0xffF59E0B),
//               onTap: () => _shareReport('sms'),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _actionButton({
//     required String channel,
//     required String label,
//     required IconData icon,
//     required Color color,
//     required VoidCallback onTap,
//   }) {
//     final isLoading = _sharingChannel == channel ||
//         (channel == 'whatsapp' && _sharingChannel == 'whatsapp_loading');
//     final isDisabled = _sharingChannel != null && !isLoading;
//
//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         onTap: isDisabled ? null : onTap,
//         borderRadius: BorderRadius.circular(14),
//         child: Container(
//           padding: const EdgeInsets.symmetric(vertical: 12),
//           decoration: BoxDecoration(
//             color: color.withOpacity(isDisabled ? .05 : .12),
//             borderRadius: BorderRadius.circular(14),
//             border: Border.all(
//               color: color.withOpacity(isDisabled ? .15 : .35),
//             ),
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               isLoading
//                   ? SizedBox(
//                 width: 20,
//                 height: 20,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 2.2,
//                   valueColor: AlwaysStoppedAnimation<Color>(color),
//                 ),
//               )
//                   : Icon(icon,
//                   size: 20,
//                   color: isDisabled ? color.withOpacity(.4) : color),
//               const SizedBox(height: 5),
//               Text(
//                 label,
//                 style: TextStyle(
//                   fontSize: 11,
//                   fontWeight: FontWeight.w700,
//                   color: isDisabled ? color.withOpacity(.4) : color,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // ── Simple model for a recipient ────────────────────────────────────────────
// class _Recipient {
//   final String id;
//   final String name;
//   final String phone;
//   final String roleLabel;
//
//   const _Recipient({
//     required this.id,
//     required this.name,
//     required this.phone,
//     required this.roleLabel,
//   });
// }