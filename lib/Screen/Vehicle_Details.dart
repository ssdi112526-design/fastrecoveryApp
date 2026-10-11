import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Model_class/vehcial_detail_model.dart';
import '../theme/app_theme.dart';

class _Recipient {
  final String id;
  final String name;
  final String phone;
  final String roleLabel;
  final bool isPrimary;

  const _Recipient({
    required this.id,
    required this.name,
    required this.phone,
    required this.roleLabel,
    this.isPrimary = false,
  });
}

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
  static const String _whatsappRecipientsUrl =
      'https://www.fastrecovery.in/api/confirmations/whatsapp-recipients';

  static const String _vehicleLoadedUrl =
      'https://www.fastrecovery.in/api/repo-cases/vehicle-loaded';

  final TextEditingController _loadedCtrl = TextEditingController();
  bool _loadingLoaded = false;
  String? _sharingChannel;

  @override
  void initState() {
    super.initState();
    _loadingLoaded = true;
    _fetchLoadedDetails();
  }

  @override
  void dispose() {
    _loadedCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────── Loaded details ─────────────────────────

  Future<void> _fetchLoadedDetails() async {
    try {
      final token = await _getToken();
      final uri = Uri.parse(_vehicleLoadedUrl).replace(queryParameters: {
        'vehicleNumber':
        widget.item.vehicleNumber.replaceAll(RegExp(r'\s+'), ''),
        'chassisNumber': widget.item.chassisNumber,
      });

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 20));

      final body = jsonDecode(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          body is Map &&
          body['success'] == true) {
        final detail = (body['data']?['loadedDetail'] ?? '').toString();
        // user ne agar pehle hi kuch type kar diya ho to overwrite mat karo
        if (mounted && _loadedCtrl.text.isEmpty) {
          _loadedCtrl.text = detail;
        }
      }
    } catch (e) {
      debugPrint('LOADED DETAILS ERROR: $e');
    } finally {
      if (mounted) setState(() => _loadingLoaded = false);
    }
  }

  /// Message ke end mein user ke Loaded Details jod do
  /// (duplicate nahi hoga agar backend ne pehle hi daal diya ho).
  String _withLoaded(String message) {
    final loaded = _loadedCtrl.text.trim();
    if (loaded.isEmpty || message.contains(loaded)) return message;
    return '$message\n\nLoaded Details: $loaded';
  }

  // ───────────────────────── WhatsApp flow ─────────────────────────

  // WhatsApp tap -> recipients fetch -> select sheet -> send
  Future<void> _handleWhatsAppTap() async {
    if (_sharingChannel != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _sharingChannel = 'whatsapp');

    List<_Recipient> recipients = [];
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse(_whatsappRecipientsUrl),
        headers: {
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      final body = jsonDecode(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          body is Map &&
          body['success'] == true) {
        final raw = (body['data']?['adminRecipients'] as List?) ?? [];
        recipients = raw
            .whereType<Map>()
            .map((e) {
          return _Recipient(
            id: (e['id'] ?? e['_id'] ?? '').toString(),
            name: (e['name'] ?? '').toString(),
            phone: (e['phone'] ?? '').toString(),
            roleLabel: (e['roleLabel'] ?? '').toString(),
            isPrimary: e['isPrimary'] == true ||
                e['isPrimaryAdmin'] == true ||
                e['primary'] == true,
          );
        })
            .where((r) => r.phone.trim().isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('RECIPIENTS ERROR: $e');
    }

    if (!mounted) return;
    setState(() => _sharingChannel = null);

    if (recipients.isEmpty) {
      _showSnack('No WhatsApp recipients found', isError: true);
      return;
    }

    final picked = await _showRecipientSheet(recipients);
    if (picked == null || !mounted) return;
    await _sendWhatsApp(picked);
  }

  Future<_Recipient?> _showRecipientSheet(List<_Recipient> recipients) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const wa = Color(0xff25D366);
    String? selectedId;

    return showModalBottomSheet<_Recipient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final selected = selectedId == null
                ? null
                : recipients.firstWhere((r) => r.id == selectedId);

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * .78,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xff1E293B) : Colors.white,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                18,
                14,
                18,
                16 + MediaQuery.of(ctx).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xff475569)
                            : const Color(0xffCBD5E1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.chat_rounded, color: wa, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Select recipient',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.navy950,
                          ),
                        ),
                      ),
                      Text(
                        '${selectedId == null ? 0 : 1}/${recipients.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: recipients.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final r = recipients[i];
                        final isSel = r.id == selectedId;

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setSheet(() => selectedId = r.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? wa.withOpacity(.10)
                                  : (isDark
                                  ? const Color(0xff0F172A)
                                  : const Color(0xffF8FAFC)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSel
                                    ? wa.withOpacity(.6)
                                    : (isDark
                                    ? const Color(0xff334155)
                                    : const Color(0xffE2E8F0)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSel
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  color: isSel
                                      ? wa
                                      : (isDark
                                      ? Colors.white38
                                      : Colors.black38),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              r.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                                color: isDark
                                                    ? Colors.white
                                                    : AppColors.navy950,
                                              ),
                                            ),
                                          ),
                                          if (r.isPrimary) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2),
                                              decoration: BoxDecoration(
                                                color: wa.withOpacity(.15),
                                                borderRadius:
                                                BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'Primary Admin',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xff15803D),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      if (r.roleLabel.isNotEmpty)
                                        Text(
                                          r.roleLabel,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.black54,
                                          ),
                                        ),
                                      const SizedBox(height: 2),
                                      Text(
                                        r.phone,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: selected == null
                          ? null
                          : () => Navigator.pop(ctx, selected),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        selected == null
                            ? 'Select a recipient'
                            : 'Send to ${selected.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: wa,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: wa.withOpacity(.3),
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _waPhone(String raw) {
    var p = raw.replaceAll(RegExp(r'\D'), '');
    if (p.length == 11 && p.startsWith('0')) p = p.substring(1);
    if (p.length == 10) p = '91$p';
    return p;
  }

  // Report generate karo + selected recipient ki chat open karo
  Future<void> _sendWhatsApp(_Recipient r) async {
    if (_sharingChannel != null) return;
    setState(() => _sharingChannel = 'whatsapp');

    try {
      final token = await _getToken();
      final response = await http
          .post(
        Uri.parse(_confirmationsUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'searchItem': widget.item.toJson(),
          'traceMode': 'ONLINE',
          'shareChannel': 'whatsapp',
          'recipientId': r.id,
          'recipientPhone': r.phone,
          'loadedDetails': _loadedCtrl.text.trim(), // ← NEW
        }),
      )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (_) {}

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body is! Map ||
          body['success'] != true) {
        final msg = (body is Map && body['message'] != null)
            ? body['message'].toString()
            : 'Unable to share report';
        _showSnack(msg, isError: true);
        return;
      }

      final traceReport = body['traceReport'];
      final baseMessage =
      traceReport is Map ? (traceReport['message']?.toString() ?? '') : '';

      if (baseMessage.isEmpty) {
        _showSnack('Report generated, but message is empty', isError: true);
        return;
      }

      final message = _withLoaded(baseMessage); // ← NEW

      final phone = _waPhone(r.phone);
      final uri = Uri.parse(
          'https://wa.me/$phone?text=${Uri.encodeComponent(message)}');

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _showSnack('Could not open WhatsApp', isError: true);
    } catch (e) {
      debugPrint('SHARE WHATSAPP ERROR: $e');
      if (!mounted) return;
      _showSnack('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _sharingChannel = null);
    }
  }

  // ───────────────────────── Helpers ─────────────────────────

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

  // ───────────────────────── Email / SMS ─────────────────────────

  Future<void> _shareReport(String channel) async {
    if (_sharingChannel != null) return;
    FocusScope.of(context).unfocus();

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
        'loadedDetails': _loadedCtrl.text.trim(), // ← NEW
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
        _showSnack('Report generated, but no share link received',
            isError: true);
        return;
      }

      final message = _withLoaded(traceReport['message']?.toString() ?? '');
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
      if (mounted) setState(() => _sharingChannel = null);
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

  Future<void> _openSms(
      {required String phone, required String message}) async {
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

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor:
      isDark ? const Color(0xff0B1220) : const Color(0xffF8FAFC),
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
        title: Text(
          item.vehicleNumber,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.navy950,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  _popupSection('Customer Information', Icons.person_outline),
                  const SizedBox(height: 10),
                  _detailGrid([
                    (Icons.person_outline, 'Customer Name', item.customerName),
                    (Icons.location_city_outlined, 'City', item.city),
                    (Icons.map_outlined, 'State', item.state),
                  ]),
                  const SizedBox(height: 18),
                  _popupSection(
                      'Vehicle Information', Icons.directions_car_outlined),
                  const SizedBox(height: 10),
                  _detailGrid([
                    (
                    Icons.directions_car_outlined,
                    'Vehicle Number',
                    item.vehicleNumber
                    ),
                    (
                    Icons.confirmation_number_outlined,
                    'Chassis Number',
                    item.chassisNumber
                    ),
                    (
                    Icons.settings_outlined,
                    'Engine Number',
                    item.engineNumber
                    ),
                    (Icons.category_outlined, 'Brand', item.vehicleBrand),
                    (Icons.car_repair_outlined, 'Model', item.vehicleModel),
                  ]),
                  const SizedBox(height: 18),
                  _popupSection('Loaded Details', Icons.edit_note_rounded),
                  const SizedBox(height: 10),
                  _loadedDetailsField(isDark),
                  const SizedBox(height: 18),
                  _popupSection('Status', Icons.info_outline),
                  const SizedBox(height: 10),
                  _detailGrid([
                    (
                    Icons.flag_outlined,
                    'Confirmation Status',
                    item.confirmationStatus
                    ),
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

  Widget _loadedDetailsField(bool isDark) {
    return TextField(
      controller: _loadedCtrl,
      minLines: 2,
      maxLines: 5,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: 'Loaded details likhein...',
        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
        filled: true,
        fillColor: isDark ? const Color(0xff0F172A) : Colors.white,
        suffixIcon: _loadingLoaded
            ? const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
            : null,
        contentPadding: const EdgeInsets.all(12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xff334155) : const Color(0xffE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.blue600),
        ),
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
          style: TextStyle(
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
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: .9,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          detail.$3,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
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
              onTap: _handleWhatsAppTap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionButton(
              channel: 'email',
              label: 'Email',
              icon: Icons.email_rounded,
              color: AppColors.blue600,
              onTap: () => _shareReport('email'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionButton(
              channel: 'sms',
              label: 'SMS',
              icon: Icons.sms_rounded,
              color: const Color(0xffF59E0B),
              onTap: () => _shareReport('sms'),
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
    required VoidCallback onTap,
  }) {
    final isLoading = _sharingChannel == channel;
    final isDisabled = _sharingChannel != null && !isLoading;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
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
                  : Icon(icon,
                  size: 20,
                  color: isDisabled ? color.withOpacity(.4) : color),
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