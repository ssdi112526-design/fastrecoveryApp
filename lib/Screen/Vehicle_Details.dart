import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Model_class/vehicle_detail_model.dart';
import '../theme/app_theme.dart';

/// Debug helper: Logcat / Run console mein "VDP" filter karke dekho.
void _log(String tag, Object? msg) {
  debugPrint('[VDP][$tag] $msg', wrapWidth: 1000);
}

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

  @override
  String toString() =>
      '_Recipient(id=$id, name=$name, phone=$phone, role=$roleLabel, primary=$isPrimary)';
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

  /// WhatsApp, SMS aur Call teeno isi recipients list ko use karte hain.
  static const String _recipientsUrl =
      'https://www.fastrecovery.in/api/confirmations/whatsapp-recipients';

  static const String _vehicleLoadedUrl =
      'https://www.fastrecovery.in/api/repo-cases/vehicle-loaded';

  /// Offline ke liye recipients cache key
  static const String _recipientsCacheKey = 'cached_recipients_v1';

  static const Color _waColor = Color(0xff25D366);
  static const Color _smsColor = Color(0xffF59E0B);
  static const Color _callColor = Color(0xff0E6BB8);

  final TextEditingController _loadedCtrl = TextEditingController();
  bool _loadingLoaded = false;
  String? _sharingChannel;

  @override
  void initState() {
    super.initState();
    _log('INIT', 'popup opened');
    try {
      _log('INIT', 'item.toJson = ${jsonEncode(widget.item.toJson())}');
    } catch (e) {
      _log('INIT', 'item.toJson FAILED: $e');
    }
    _log('INIT',
        'vehicleNumber="${widget.item.vehicleNumber}" chassisNumber="${widget.item.chassisNumber}"');
    _loadingLoaded = true;
    _fetchLoadedDetails();
    _prefetchRecipients();
  }

  @override
  void dispose() {
    _log('DISPOSE', 'popup closed, loadedCtrl="${_loadedCtrl.text}"');
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

      _log('LOADED GET', 'url = $uri');

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 20));

      _log('LOADED GET', 'status = ${response.statusCode}');
      _log('LOADED GET', 'body = ${response.body}');

      final body = jsonDecode(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          body is Map &&
          body['success'] == true) {
        final detail = (body['data']?['loadedDetail'] ?? '').toString();
        _log('LOADED GET', 'parsed loadedDetail = "$detail"');
        // user ne agar pehle hi kuch type kar diya ho to overwrite mat karo
        if (mounted && _loadedCtrl.text.isEmpty) {
          _loadedCtrl.text = detail;
          _log('LOADED GET', 'controller filled with "$detail"');
        } else {
          _log('LOADED GET',
              'controller NOT overwritten (mounted=$mounted, text="${_loadedCtrl.text}")');
        }
      } else {
        _log('LOADED GET', 'response not success -> skipped');
      }
    } catch (e) {
      _log('LOADED GET ERROR', e);
    } finally {
      if (mounted) setState(() => _loadingLoaded = false);
    }
  }

  /// Web payload mein loaded details top-level par nahi dikhi, isliye
  /// searchItem ke andar bhi bhej rahe hain (backend jo key padhe).
  Map<String, dynamic> _searchItemWithLoaded() {
    final loaded = _loadedCtrl.text.trim();
    final m = Map<String, dynamic>.from(widget.item.toJson());
    m['loadedDetail'] = loaded;
    m['loadedDetails'] = loaded;
    return m;
  }

  /// Message ke end mein user ke Loaded Details jod do
  /// (duplicate nahi hoga agar backend ne pehle hi daal diya ho).
  String _withLoaded(String message) {
    final loaded = _loadedCtrl.text.trim();
    _log('WITH_LOADED', 'loaded="$loaded"');
    if (loaded.isEmpty) {
      _log('WITH_LOADED', 'loaded empty -> message unchanged');
      return message;
    }
    if (message.contains(loaded)) {
      _log('WITH_LOADED', 'message already contains loaded -> unchanged');
      return message;
    }
    final out = '$message\n\nLoaded Details: $loaded';
    _log('WITH_LOADED', 'appended loaded details to message');
    return out;
  }

  /// Internet na ho to item ke data se local message
  String _buildLocalMessage() {
    final i = widget.item;
    final lines = <String>[
      'Vehicle Traced — ${i.vehicleNumber}',
      '',
      'Customer: ${i.customerName}',
      'Vehicle No: ${i.vehicleNumber}',
      'Chassis No: ${i.chassisNumber}',
      'Engine No: ${i.engineNumber}',
      'Brand: ${i.vehicleBrand}',
      'Model: ${i.vehicleModel}',
      'City: ${i.city}',
      'State: ${i.state}',
      'Status: ${i.repoStatus}',
    ];
    return lines.join('\n');
  }

  // ───────────── Recipient flow (WhatsApp + SMS + Call) ─────────────

  /// Popup khulte hi recipients fetch karke cache kar lo,
  /// taaki baad mein net band ho tab bhi list mile.
  Future<void> _prefetchRecipients() async {
    _log('PREFETCH', 'start');
    await _fetchRecipients();
  }

  /// Tap -> recipients fetch -> select sheet -> send / call
  Future<void> _handleRecipientTap(String channel) async {
    _log('TAP', 'channel=$channel sharingChannel=$_sharingChannel');
    if (_sharingChannel != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _sharingChannel = channel);

    final recipients = await _fetchRecipients();
    _log('TAP', 'recipients count = ${recipients.length}');

    if (!mounted) return;
    setState(() => _sharingChannel = null);

    if (recipients.isEmpty) {
      // Net band + cache bhi khali: WhatsApp phir bhi khul jaye
      // (contact user khud chunega)
      if (channel == 'whatsapp') {
        _log('TAP', 'no recipients -> WhatsApp fallback with local message');
        await _openWhatsApp(null, _withLoaded(_buildLocalMessage()));
        return;
      }
      _log('TAP', 'no recipients -> snack');
      _showSnack('No recipients found', isError: true);
      return;
    }

    final Color accent = channel == 'sms'
        ? _smsColor
        : channel == 'call'
        ? _callColor
        : _waColor;
    final IconData icon = channel == 'sms'
        ? Icons.sms_rounded
        : channel == 'call'
        ? Icons.call_rounded
        : Icons.chat_rounded;

    final picked = await _showRecipientSheet(
      recipients,
      accent: accent,
      icon: icon,
      actionLabel: channel == 'call' ? 'Call' : 'Send to',
      actionIcon: channel == 'call' ? Icons.call_rounded : Icons.send_rounded,
    );
    _log('TAP', 'picked = $picked');
    if (picked == null || !mounted) return;

    if (channel == 'call') {
      await _callRecipient(picked);
    } else {
      await _sendToRecipient(channel, picked);
    }
  }

  /// API se recipients; net band/error ho to cache se.
  Future<List<_Recipient>> _fetchRecipients() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final token = await _getToken();
      _log('RECIPIENTS GET', 'url = $_recipientsUrl');
      final response = await http.get(
        Uri.parse(_recipientsUrl),
        headers: {
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      _log('RECIPIENTS GET', 'status = ${response.statusCode}');
      _log('RECIPIENTS GET', 'body = ${response.body}');

      final body = jsonDecode(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          body is Map &&
          body['success'] == true) {
        final raw = (body['data']?['adminRecipients'] as List?) ?? [];
        _log('RECIPIENTS GET', 'raw adminRecipients count = ${raw.length}');
        await prefs.setString(_recipientsCacheKey, jsonEncode(raw));
        final parsed = _parseRecipients(raw);
        _log('RECIPIENTS GET', 'parsed = $parsed');
        return parsed;
      } else {
        _log('RECIPIENTS GET', 'not success -> will try cache');
      }
    } catch (e) {
      _log('RECIPIENTS ERROR', e);
    }

    // Offline / error -> cached list
    try {
      final cached = prefs.getString(_recipientsCacheKey);
      _log('RECIPIENTS CACHE', 'cached exists = ${cached != null}');
      if (cached != null) {
        final parsed = _parseRecipients(jsonDecode(cached) as List);
        _log('RECIPIENTS CACHE', 'parsed = $parsed');
        return parsed;
      }
    } catch (e) {
      _log('RECIPIENTS CACHE ERROR', e);
    }
    return [];
  }

  List<_Recipient> _parseRecipients(List raw) {
    return raw
        .whereType<Map>()
        .map((e) => _Recipient(
      id: (e['id'] ?? e['_id'] ?? '').toString(),
      name: (e['name'] ?? '').toString(),
      phone: (e['phone'] ?? '').toString(),
      roleLabel: (e['roleLabel'] ?? '').toString(),
      isPrimary: e['isPrimaryAdmin'] == true ||
          e['isPrimary'] == true ||
          e['primary'] == true,
    ))
        .where((r) => r.phone.trim().isNotEmpty)
        .toList();
  }

  Future<_Recipient?> _showRecipientSheet(
      List<_Recipient> recipients, {
        required Color accent,
        required IconData icon,
        String actionLabel = 'Send to',
        IconData actionIcon = Icons.send_rounded,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int? selectedIndex; // index se select karte hain (id khali ho to bhi theek)

    return showModalBottomSheet<_Recipient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final selected =
            selectedIndex == null ? null : recipients[selectedIndex!];

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
                      Icon(icon, color: accent, size: 22),
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
                        '${selectedIndex == null ? 0 : 1}/${recipients.length}',
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
                      itemBuilder: (_, i) => _recipientTile(
                        recipients[i],
                        selected: i == selectedIndex,
                        accent: accent,
                        isDark: isDark,
                        onTap: () {
                          _log('SHEET', 'selected index=$i ${recipients[i]}');
                          setSheet(() => selectedIndex = i);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: selected == null
                          ? null
                          : () => Navigator.pop(ctx, selected),
                      icon: Icon(actionIcon, size: 18),
                      label: Text(
                        selected == null
                            ? 'Select a recipient'
                            : '$actionLabel ${selected.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: accent.withOpacity(.3),
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

  Widget _recipientTile(
      _Recipient r, {
        required bool selected,
        required Color accent,
        required bool isDark,
        required VoidCallback onTap,
      }) {
    final badgeText = Color.lerp(accent, Colors.black, .35)!;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? accent.withOpacity(.10)
              : (isDark ? const Color(0xff0F172A) : const Color(0xffF8FAFC)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? accent.withOpacity(.6)
                : (isDark ? const Color(0xff334155) : const Color(0xffE2E8F0)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? accent
                  : (isDark ? Colors.white38 : Colors.black38),
              size: 22,
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
                          r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.navy950,
                          ),
                        ),
                      ),
                      if (r.isPrimary) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Primary Admin',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: badgeText,
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
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    r.phone,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "9654008400" -> "919654008400"
  String _waPhone(String raw) {
    var p = raw.replaceAll(RegExp(r'\D'), '');
    if (p.length == 11 && p.startsWith('0')) p = p.substring(1);
    if (p.length == 10) p = '91$p';
    return p;
  }

  /// Report generate karo + selected recipient ko WhatsApp / SMS se bhejo.
  /// Net band ho to local message se bhi bhej deta hai.
  Future<void> _sendToRecipient(String channel, _Recipient r) async {
    if (_sharingChannel != null) return;
    setState(() => _sharingChannel = channel);

    String? baseMessage;

    try {
      final token = await _getToken();

      final payload = {
        'searchItem': _searchItemWithLoaded(),
        'traceMode': 'ONLINE',
        'shareChannel': channel,
        'recipientId': r.id,
        'recipientPhone': r.phone,
        'loadedDetails': _loadedCtrl.text.trim(),
        'loadedDetail': _loadedCtrl.text.trim(),
      };
      _log('SEND $channel', 'POST $_confirmationsUrl');
      _log('SEND $channel', 'token present = ${token != null}');
      _log('SEND $channel', 'PAYLOAD = ${jsonEncode(payload)}');

      final response = await http
          .post(
        Uri.parse(_confirmationsUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 15));

      _log('SEND $channel', 'RESPONSE status = ${response.statusCode}');
      _log('SEND $channel', 'RESPONSE body = ${response.body}');

      if (!mounted) return;

      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (e) {
        _log('SEND $channel', 'jsonDecode FAILED: $e');
      }

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body is! Map ||
          body['success'] != true) {
        final msg = (body is Map && body['message'] != null)
            ? body['message'].toString()
            : 'Unable to share report';
        _log('SEND $channel', 'FAILED -> $msg');
        _showSnack(msg, isError: true);
        return;
      }

      _log('SEND $channel',
          'saved loadedDetail on server = "${body['data']?['loadedDetail']}"');

      final traceReport = body['traceReport'];
      baseMessage =
      traceReport is Map ? (traceReport['message']?.toString() ?? '') : '';
      _log('SEND $channel', 'traceReport.message = $baseMessage');
    } on SocketException catch (e) {
      _log('SEND $channel', 'SocketException (offline): $e');
      baseMessage = null; // internet band
    } on TimeoutException catch (e) {
      _log('SEND $channel', 'TimeoutException: $e');
      baseMessage = null; // net bahut slow / band
    } on http.ClientException catch (e) {
      _log('SEND $channel', 'ClientException: $e');
      baseMessage = null;
    } catch (e) {
      _log('SEND $channel ERROR', e);
      if (!mounted) return;
      _showSnack('Something went wrong. Please try again.', isError: true);
      return;
    } finally {
      if (mounted) setState(() => _sharingChannel = null);
    }

    if (!mounted) return;

    final bool offline = baseMessage == null || baseMessage.isEmpty;
    final String message =
    _withLoaded(offline ? _buildLocalMessage() : baseMessage);

    _log('SEND $channel', 'offline = $offline');
    _log('SEND $channel', 'FINAL MESSAGE =\n$message');

    if (offline) {
      _showSnack('Internet off hai, offline message bheja ja raha hai',
          isError: false);
    }

    if (channel == 'sms') {
      await _openSms(r, message);
    } else {
      await _openWhatsApp(r, message);
    }
  }

  /// recipient null ho to number ke bina WhatsApp khulta hai
  /// (user khud contact chun leta hai).
  Future<void> _openWhatsApp(_Recipient? r, String message) async {
    final phone = r == null ? '' : _waPhone(r.phone);
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );
    _log('OPEN WA', 'phone = "$phone"');
    _log('OPEN WA', 'uri = $uri');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    _log('OPEN WA', 'launch ok = $ok');
    if (!ok) _showSnack('Could not open WhatsApp', isError: true);
  }

  Future<void> _openSms(_Recipient r, String message) async {
    // Uri(queryParameters:) space ko '+' bana deta hai, isliye string
    // khud banate hain. Android: sms:NUMBER?body=...  iOS: sms:NUMBER&body=...
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final sep = isIos ? '&' : '?';
    final uri = Uri.parse(
      'sms:+${_waPhone(r.phone)}${sep}body=${Uri.encodeComponent(message)}',
    );

    _log('OPEN SMS', 'isIos = $isIos');
    _log('OPEN SMS', 'uri = $uri');
    final ok = await launchUrl(uri);
    _log('OPEN SMS', 'launch ok = $ok');
    if (!ok) _showSnack('Could not open messaging app', isError: true);
  }

  Future<void> _callRecipient(_Recipient r) async {
    final uri = Uri(scheme: 'tel', path: '+${_waPhone(r.phone)}');
    _log('CALL', 'uri = $uri');
    final ok = await launchUrl(uri);
    _log('CALL', 'launch ok = $ok');
    if (!ok) _showSnack('Could not open dialer', isError: true);
  }

  // ───────────────────────── Helpers ─────────────────────────

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('token');
    if (stored != null && stored.isNotEmpty) return stored;
    _log('TOKEN', 'token missing in SharedPreferences (key "token")');
    return null;
  }

  void _showSnack(String message, {bool isError = true}) {
    _log('SNACK', '${isError ? "ERROR" : "INFO"}: $message');
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

  // ───────────────────────── Email ─────────────────────────

  Future<void> _shareEmail() async {
    if (_sharingChannel != null) return;
    FocusScope.of(context).unfocus();

    setState(() => _sharingChannel = 'email');

    try {
      final token = await _getToken();

      final payload = {
        'searchItem': _searchItemWithLoaded(),
        'traceMode': 'ONLINE',
        'shareChannel': 'email',
        'loadedDetails': _loadedCtrl.text.trim(),
        'loadedDetail': _loadedCtrl.text.trim(),
      };
      _log('SEND email', 'POST $_confirmationsUrl');
      _log('SEND email', 'token present = ${token != null}');
      _log('SEND email', 'PAYLOAD = ${jsonEncode(payload)}');

      final response = await http
          .post(
        Uri.parse(_confirmationsUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 30));

      _log('SEND email', 'RESPONSE status = ${response.statusCode}');
      _log('SEND email', 'RESPONSE body = ${response.body}');

      if (!mounted) return;

      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (e) {
        _log('SEND email', 'jsonDecode FAILED: $e');
        body = null;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Unable to share report';
        if (body is Map && body['message'] != null) {
          message = body['message'].toString();
        }
        _log('SEND email', 'HTTP FAILED -> $message');
        _showSnack(message, isError: true);
        return;
      }

      if (body is! Map || body['success'] != true) {
        _log('SEND email', 'success != true');
        _showSnack('Unable to share report', isError: true);
        return;
      }

      _log('SEND email',
          'saved loadedDetail on server = "${body['data']?['loadedDetail']}"');

      final traceReport = body['traceReport'];
      if (traceReport is! Map) {
        _log('SEND email', 'traceReport missing');
        _showSnack('Report generated, but no share link received',
            isError: true);
        return;
      }

      _log('SEND email', 'traceReport.message = ${traceReport['message']}');
      final message = _withLoaded(traceReport['message']?.toString() ?? '');
      _log('SEND email', 'FINAL MESSAGE =\n$message');
      await _openEmail(message: message);
    } on SocketException catch (e) {
      _log('SEND email', 'SocketException: $e');
      if (!mounted) return;
      _showSnack('Internet required to send email', isError: true);
    } on TimeoutException catch (e) {
      _log('SEND email', 'TimeoutException: $e');
      if (!mounted) return;
      _showSnack('Internet required to send email', isError: true);
    } catch (e) {
      _log('SEND email ERROR', e);
      if (!mounted) return;
      _showSnack('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _sharingChannel = null);
    }
  }

  Future<void> _openEmail({required String message}) async {
    final subject = 'Vehicle Traced — ${widget.item.vehicleNumber}';

    final uri = Uri(
      scheme: 'mailto',
      query:
      'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(message)}',
    );

    final can = await canLaunchUrl(uri);
    _log('OPEN EMAIL', 'canLaunch = $can, uri = $uri');
    if (can) {
      final ok = await launchUrl(uri);
      _log('OPEN EMAIL', 'launch ok = $ok');
    } else {
      _showSnack('No email app found on this device', isError: true);
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
                    (Icons.info_outline, 'Status', item.repoStatus),
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
      onChanged: (v) => _log('LOADED FIELD', 'typed = "$v"'),
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
              color: _waColor,
              onTap: () => _handleRecipientTap('whatsapp'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionButton(
              channel: 'email',
              label: 'Email',
              icon: Icons.email_rounded,
              color: AppColors.blue600,
              onTap: _shareEmail,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionButton(
              channel: 'sms',
              label: 'SMS',
              icon: Icons.sms_rounded,
              color: _smsColor,
              onTap: () => _handleRecipientTap('sms'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionButton(
              channel: 'call',
              label: 'Call',
              icon: Icons.call_rounded,
              color: _callColor,
              onTap: () => _handleRecipientTap('call'),
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