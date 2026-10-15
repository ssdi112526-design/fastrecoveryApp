import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, Platform;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

// =============================================================
// CONFIG
// =============================================================

const String _baseUrl = 'https://www.fastrecovery.in';

/// Inventory image/video/pdf ka base URL.
/// null = app khud sahi route dhoondh leta hai (`_Media` dekho).
/// Agar tumhe web ka exact static route pata hai to yahan set kar do, e.g.
/// 'https://www.fastrecovery.in/uploads/'
const String? _pinnedBase = null;

/// Endpoints web ke Network tab se confirm hain.
///   POST /api/confirmations/:id/inventory/request-revision
///   POST /api/confirmations/:id/inventory            (multipart)
///   GET  /api/parking-yards/search?q=&page=1&limit=20   -> data.yards
String _requestInventoryUpdateUrl(String id) =>
    '$_baseUrl/api/confirmations/$id/inventory/request-revision';
String _submitInventoryUrl(String id) =>
    '$_baseUrl/api/confirmations/$id/inventory';
String _parkingYardSearchUrl(String q) =>
    '$_baseUrl/api/parking-yards/search?q=${Uri.encodeComponent(q)}&page=1&limit=20';

const Color _blue = Color(0xff1D4ED8);
const Color _green = Color(0xff16A34A);

// =============================================================
// SHARED HELPERS
// =============================================================

class _C {
  final bool dark;
  const _C(this.dark);
  factory _C.of(BuildContext c) =>
      _C(Theme.of(c).brightness == Brightness.dark);

  Color get bg => dark ? const Color(0xff080D18) : const Color(0xffF5F7FB);
  Color get card => dark ? const Color(0xff10182A) : Colors.white;
  Color get border => dark ? const Color(0xff24304A) : const Color(0xffE5EAF2);
  Color get text => dark ? Colors.white : const Color(0xff0F172A);
  Color get muted => dark ? const Color(0xff7F8BA4) : const Color(0xff64748B);
  Color get tile => dark ? const Color(0xff0C1424) : const Color(0xffF4F7FB);
}

Map<String, String> _headers(String? token, {bool json = true}) => {
  'Accept': 'application/json',
  if (json) 'Content-Type': 'application/json',
  'Authorization': 'Bearer ${token?.trim()}',
};

String _str(dynamic v) {
  final s = (v ?? '').toString().trim();
  return (s.isEmpty || s == 'null') ? '-' : s;
}

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> _asMapList(dynamic v) => (v as List? ?? [])
    .whereType<Map>()
    .map((e) => Map<String, dynamic>.from(e))
    .toList();

/// UP02CD7283 -> UP 02 CD 7283
String _formatVehicle(dynamic v) {
  final raw = (v ?? '').toString().replaceAll(' ', '').toUpperCase();
  final m =
  RegExp(r'^([A-Z]{2})(\d{1,2})([A-Z]{1,3})(\d{1,4})$').firstMatch(raw);
  if (m == null) return raw.isEmpty ? '-' : raw;
  return '${m.group(1)} ${m.group(2)} ${m.group(3)} ${m.group(4)}';
}

String _formatDate(dynamic v) {
  final d = DateTime.tryParse((v ?? '').toString())?.toLocal();
  if (d == null) return '-';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  final ap = d.hour >= 12 ? 'PM' : 'AM';
  return '${d.day} ${months[d.month - 1]} ${d.year}, $h12:$mm $ap';
}

/// 15/10/2026, 13:29:22  (web ke "Reported At" jaisa)
String _formatDateTable(dynamic v) {
  final d = DateTime.tryParse((v ?? '').toString())?.toLocal();
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}, '
      '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

String _prettyCategory(String c) {
  if (c.isEmpty) return 'Other';
  return c
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// 10-digit -> 91XXXXXXXXXX (wa.me / sms ke liye)
String _normPhone(String raw) {
  var p = raw.replaceAll(RegExp(r'\D'), '');
  if (p.length == 11 && p.startsWith('0')) p = p.substring(1);
  if (p.length == 10) p = '91$p';
  return p;
}

void _toast(BuildContext context, String msg, {bool error = true}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
    ));
}

Future<void> _launch(BuildContext context, Uri uri, String failMsg) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _toast(context, failMsg);
  } catch (e) {
    debugPrint('LAUNCH ERROR: $e');
    _toast(context, failMsg);
  }
}

Future<void> _call(BuildContext context, String phone) async {
  final p = phone.trim();
  if (p.isEmpty || p == '-') return;
  await _launch(context, Uri.parse('tel:$p'), 'Could not open dialer');
}

Future<String?> _askText(
    BuildContext context, String title, String hint, TextInputType type) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title),
      content: TextField(
        controller: ctrl,
        keyboardType: type,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: _blue, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Parking yard search result (API ke alag-alag key names handle karta hai)
Map<String, String> _yardFromJson(Map<String, dynamic> m) {
  String g(List<String> ks) {
    for (final k in ks) {
      final v = (m[k] ?? '').toString().trim();
      if (v.isNotEmpty && v != 'null') return v;
    }
    return '';
  }

  return {
    'id': g(['_id', 'id', 'parkingYardId']),
    'name': g(['name', 'parkingYardName', 'yardName']),
    'address': g(['address', 'parkingYardAddress']),
    'area': g(['area', 'parkingYardArea']),
    'pincode': g(['pincode', 'pin', 'parkingYardPincode']),
    'phone': g(['phone', 'parkingYardPhone']),
    'managerName': g(['managerName', 'parkingYardManagerName']),
    'managerPhone': g(['managerPhone', 'parkingYardManagerPhone']),
    'code': g(['code', 'yardCode', 'parkingYardCode']),
  };
}

/// Confirmation ke andar already saved parking yard (parkingYard* keys).
/// NOTE: yahan `_id` use nahi hota (wo confirmation ki id hai, yard ki nahi).
Map<String, String> _yardFromConfirmation(Map<String, dynamic> c) {
  String g(String k) {
    final v = (c[k] ?? '').toString().trim();
    return v == 'null' ? '' : v;
  }

  return {
    'id': g('parkingYardId'),
    'name': g('parkingYardName'),
    'address': g('parkingYardAddress'),
    'area': g('parkingYardArea'),
    'pincode': g('parkingYardPincode'),
    'phone': g('parkingYardPhone'),
    'managerName': g('parkingYardManagerName'),
    'managerPhone': g('parkingYardManagerPhone'),
    'code': g('parkingYardCode'),
  };
}

// ---------- inventory files (image / video / pdf) ----------

Map<String, String> _fileHeaders(String? token) => {
  'Accept': '*/*',
  'Authorization': 'Bearer ${token?.trim()}',
};

/// API sirf relative path deti hai, jaise
/// "inventory/107/103/images/front-1790932919865-7t3zntn0.jpeg".
/// Web ka static route yahan se verify nahi ho paya, isliye pehli baar kuch
/// common prefixes try hote hain. Jo bhi image/video/pdf type ke saath 200/206
/// de (HTML ya JSON nahi), wahi cache ho jata hai. Sab fail ho to tile par
/// tap karne se tried URLs aur status dikhte hain.
class _Media {
  static const List<String> _hosts = [
    'https://www.fastrecovery.in',
    'https://fastrecovery.in',
  ];
  static const List<String> _routes = [
    '/uploads/',
    '/',
    '/api/uploads/',
    '/api/files/',
    '/files/',
    '/static/',
    '/api/',
  ];

  static String? _okBase = _pinnedBase;
  static Future<String?>? _probing;
  static DateTime? _failedAt;
  static final List<String> log = [];

  static String _clean(String p) => p.startsWith('/') ? p.substring(1) : p;

  static void reset() {
    _okBase = _pinnedBase;
    _failedAt = null;
  }

  static String debugText() =>
      log.isEmpty ? 'No attempts logged' : log.join('\n');

  static Future<String?> resolve(String path, String? token) async {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final clean = _clean(path);

    final ok = _okBase;
    if (ok != null) return '$ok$clean';

    final failed = _failedAt;
    if (failed != null && DateTime.now().difference(failed).inSeconds < 20) {
      return null;
    }

    final running =
    _probing ??= _probe(clean, token).whenComplete(() => _probing = null);
    final base = await running;
    return base == null ? null : '$base$clean';
  }

  static Future<String?> _probe(String clean, String? token) async {
    log.clear();
    for (final h in _hosts) {
      for (final r in _routes) {
        final base = '$h$r';
        final url = '$base$clean';
        final client = http.Client();
        try {
          final req = http.Request('GET', Uri.parse(url))
            ..headers.addAll(_fileHeaders(token))
            ..headers['Range'] = 'bytes=0-0';
          final res =
          await client.send(req).timeout(const Duration(seconds: 8));
          final ct = (res.headers['content-type'] ?? '').toLowerCase();
          log.add('${res.statusCode}  ${ct.isEmpty ? '-' : ct}  $url');
          final okStatus = res.statusCode == 200 || res.statusCode == 206;
          if (okStatus && !ct.contains('text/html') && !ct.contains('json')) {
            _okBase = base;
            return base;
          }
        } catch (e) {
          log.add('ERR  $url  ($e)');
        } finally {
          client.close();
        }
      }
    }
    _failedAt = DateTime.now();
    return null;
  }
}

const Map<String, String> _catLabels = {
  'front': 'Front Photo',
  'side': 'Side Photo',
  'back': 'Back Photo',
  'tire': 'Tire Photo',
  'chassis': 'Chassis',
  'engine': 'Engine',
  'meter': 'Meter',
  'glass': 'Glass',
  'crack': 'Crack Item',
  'crack_item': 'Crack Item', // purane records
  'key': 'Key',
  'rc': 'RC',
  'insurance': 'Insurance',
  'bilty': 'Bilty',
  'jack_rod': 'Jack Rod',
  'stepney': 'Stepney',
  'driver': 'Driver Photo',
  'vehicle_condition': 'Vehicle Condition',
  'videos': 'Videos',
  'pre_post': 'Pre/Post Inventory',
  'inventory_sheet': 'Inventory Sheet',
  'crane_bill': 'Crane Bill',
  'other_bills': 'Other Bills',
};

String _catLabel(String cat, {String fallback = 'Files'}) {
  if (cat.isEmpty) return fallback;
  return _catLabels[cat] ?? _prettyCategory(cat);
}

/// Photo thumbnail / full image. URL pehle `_Media` se resolve hota hai.
class _NetImage extends StatefulWidget {
  final String path;
  final String? token;
  final _C c;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;
  const _NetImage({
    required this.path,
    required this.token,
    required this.c,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 0,
  });

  @override
  State<_NetImage> createState() => _NetImageState();
}

class _NetImageState extends State<_NetImage> {
  String? _url;
  bool _resolving = true;
  Object? _imgError;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final u = await _Media.resolve(widget.path, widget.token);
    if (!mounted) return;
    setState(() {
      _url = u;
      _resolving = false;
    });
  }

  void _showDebug() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Image load failed'),
        content: SingleChildScrollView(
          child: SelectableText(
            'File: ${widget.path}\n\n'
                'URL: ${_url ?? 'not found'}\n'
                '${_imgError != null ? 'Error: $_imgError\n' : ''}\n'
                'Tried:\n${_Media.debugText()}',
            style: const TextStyle(fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _Media.reset();
              setState(() {
                _resolving = true;
                _imgError = null;
              });
              _resolve();
            },
            child: const Text('Retry'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _box(Widget child) => Container(
    width: widget.width,
    height: widget.height,
    color: widget.c.border,
    alignment: Alignment.center,
    child: child,
  );

  Widget _broken() => GestureDetector(
    onTap: _showDebug,
    child: _box(Icon(Icons.broken_image_rounded, color: widget.c.muted)),
  );

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_resolving) {
      child = _box(const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2)));
    } else if (_url == null) {
      child = _broken();
    } else {
      child = Image.network(
        _url!,
        headers: _fileHeaders(widget.token),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (ctx, err, st) {
          _imgError = err;
          return _broken();
        },
        loadingBuilder: (ctx, img, prog) => prog == null
            ? img
            : _box(const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return widget.radius > 0
        ? ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius), child: child)
        : child;
  }
}

/// Full-screen swipeable photo viewer (pinch to zoom).
class _GalleryPage extends StatefulWidget {
  final List<String> paths;
  final int initial;
  final String? token;
  const _GalleryPage(
      {required this.paths, required this.initial, required this.token});

  @override
  State<_GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<_GalleryPage> {
  late final PageController _pc = PageController(initialPage: widget.initial);
  late int _i = widget.initial;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('${_i + 1} / ${widget.paths.length}',
            style: const TextStyle(fontSize: 15)),
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: widget.paths.length,
        onPageChanged: (i) => setState(() => _i = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: _NetImage(
              path: widget.paths[i],
              token: widget.token,
              c: const _C(true),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

/// Video: browser me kholta hai (web par chalti hai, in-app player nahi).
Future<void> _openVideo(
    BuildContext context, String path, String? token) async {
  final url = await _Media.resolve(path, token);
  if (!context.mounted) return;
  if (url == null) {
    _toast(context, 'Video URL not found');
    debugPrint('VIDEO URL NOT FOUND\n${_Media.debugText()}');
    return;
  }
  await _launch(context, Uri.parse(url), 'Could not open video');
}

/// PDF: auth ke saath download karke phone ke PDF viewer me kholta hai.
Future<void> _openPdf(BuildContext context, String path, String? token) async {
  _toast(context, 'Opening PDF…', error: false);
  try {
    final url = await _Media.resolve(path, token);
    if (url == null) {
      throw Exception('PDF URL not found.\n${_Media.debugText()}');
    }
    final res = await http
        .get(Uri.parse(url), headers: _fileHeaders(token))
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

    var name = path.split('/').last.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (!name.toLowerCase().endsWith('.pdf')) name = '$name.pdf';
    final file = File('${Directory.systemTemp.path}/$name');
    await file.writeAsBytes(res.bodyBytes, flush: true);

    final r = await OpenFilex.open(file.path);
    if (r.type != ResultType.done) throw Exception(r.message);
  } catch (e) {
    debugPrint('PDF ERROR: $e');
    if (context.mounted) _toast(context, 'Could not open PDF');
  }
}

/// PDF picker. file_picker ka syntax version ke hisaab se badalta hai, isliye
/// sirf yehi ek function is package ko chhuta hai. Tumhare version par
/// jo purana code chal raha tha, use yahan paste kar do.
Future<String?> _pickPdfPath() async {
  final dynamic r = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );
  if (r == null) return null;
  if (r is List) return r.isEmpty ? null : r.first.path as String?;
  return r.files.first.path as String?;
}

// ---------- load one confirmation (+ bank-notify-message) ----------

class _Bundle {
  final Map<String, dynamic> conf;
  final Map<String, dynamic> cs;
  final Map<String, dynamic> notify;
  const _Bundle(this.conf, this.cs, this.notify);
}

/// GET /api/confirmations/:id  ->  POST /api/repo-cases/bank-notify-message
/// (bank-notify fail ho to bhi page chalta hai, sirf notify khali rehta hai)
Future<_Bundle> _loadBundle({
  required String id,
  required String? token,
  String? adminName,
  String? adminPhone,
  bool withNotify = true, // false = sirf confirmation + case (bank notify nahi)
}) async {
  final confRes = await http
      .get(Uri.parse('$_baseUrl/api/confirmations/$id'),
      headers: _headers(token))
      .timeout(const Duration(seconds: 20));

  final confBody = jsonDecode(confRes.body);
  if (confRes.statusCode < 200 ||
      confRes.statusCode >= 300 ||
      confBody is! Map ||
      confBody['success'] != true) {
    throw Exception('Confirmation load failed (${confRes.statusCode})');
  }

  final data = _asMap(confBody['data']);
  final conf = _asMap(data['confirmation']);
  final cs = _asMap(data['case']);

  Map<String, dynamic> notify = {};
  if (!withNotify) return _Bundle(conf, cs, notify);
  try {
    final reqBody = <String, dynamic>{
      'caseId': (conf['caseId'] ?? cs['_id']).toString(),
      'confirmationId': id,
      'searchItem': cs,
    };
    if ((adminName ?? '').trim().isNotEmpty) {
      reqBody['adminName'] = adminName!.trim();
    }
    if ((adminPhone ?? '').trim().isNotEmpty) {
      reqBody['adminPhone'] = adminPhone!.trim();
    }

    final nRes = await http
        .post(
      Uri.parse('$_baseUrl/api/repo-cases/bank-notify-message'),
      headers: _headers(token),
      body: jsonEncode(reqBody),
    )
        .timeout(const Duration(seconds: 20));
    final nBody = jsonDecode(nRes.body);
    if (nRes.statusCode >= 200 &&
        nRes.statusCode < 300 &&
        nBody is Map &&
        nBody['success'] == true) {
      notify = _asMap(nBody['data']);
    }
  } catch (e) {
    debugPrint('BANK NOTIFY ERROR: $e');
  }

  return _Bundle(conf, cs, notify);
}

// ---------- vehicle & trace fields (Excel columns, web jaisa) ----------

const Map<String, String> _kCaseOverride = {
  'make': 'vehicleBrand',
  'model': 'vehicleModel',
  'emi': 'emiAmount',
  'pos': 'totalOutstandingAmount',
  'bank name': 'bankName',
  'branch name': 'branchName',
  'customer name': 'customerName',
  'engine number': 'engineNumber',
  'chasis number': 'chassisNumber',
  'chassis number': 'chassisNumber',
};

Widget _vehicleFields(
    _C c, {
      required Map<String, dynamic> caseMap,
      required Map<String, dynamic> notify,
      String requestNote = '-',
    }) {
  final enriched = _asMap(notify['enrichedCase']);
  final cs = {...caseMap, ...enriched}..remove('excelFields');
  final excel = _asMap(enriched['excelFields']).isNotEmpty
      ? _asMap(enriched['excelFields'])
      : _asMap(caseMap['excelFields']);

  var order = (notify['excelColumnOrder'] as List? ??
      excel['_excelColumnOrder'] as List? ??
      [])
      .map((e) => e.toString())
      .where((k) => !k.startsWith('_'))
      .toList();

  final fallback = <String, String>{
    'Vehicle': _formatVehicle(caseMap['vehicleNumber']),
    'Customer Name': _str(caseMap['customerName']),
    'Bank Name': _str(caseMap['bankName']),
    'Branch Name': _str(caseMap['branchName']),
    'Loan Number': _str(caseMap['loanNumber']),
    'Chassis Number': _str(caseMap['chassisNumber']),
    'Engine Number': _str(caseMap['engineNumber']),
  };
  final useFallback = order.isEmpty;
  if (useFallback) order = fallback.keys.toList();

  String val(String k) {
    if (useFallback) return fallback[k] ?? '-';
    final lk = k.toLowerCase().trim();
    if (lk.contains('registration')) {
      final v = _str(excel[k]);
      return _formatVehicle(v == '-' ? caseMap['vehicleNumber'] : v);
    }
    final caseKey = _kCaseOverride[lk];
    if (caseKey != null) {
      final v = _str(cs[caseKey]);
      if (v != '-') return v;
    }
    return _str(excel[k]);
  }

  final rows = <Widget>[];
  var i = 0;
  while (i < order.length) {
    final k = order[i];
    if (k.toLowerCase() == 'address') {
      rows.add(_FieldBox(k, val(k), c));
      i++;
    } else {
      final k2 =
      (i + 1 < order.length && order[i + 1].toLowerCase() != 'address')
          ? order[i + 1]
          : null;
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _FieldBox(k, val(k), c)),
          const SizedBox(width: 10),
          Expanded(
              child:
              k2 == null ? const SizedBox() : _FieldBox(k2, val(k2), c)),
        ],
      ));
      i += k2 == null ? 1 : 2;
    }
    rows.add(const SizedBox(height: 10));
  }

  if (requestNote != '-') rows.add(_FieldBox('Request note', requestNote, c));

  return Column(children: rows);
}

// ---------- inventory status ----------

class _InvStatus {
  final String label;
  final Color bg;
  final Color fg;
  const _InvStatus(this.label, this.bg, this.fg);
}

_InvStatus _invStatus(Map<String, dynamic> m) {
  if (m['inventoryConfirmed'] == true) {
    return const _InvStatus(
        'Confirmed', Color(0xffD1FAE5), Color(0xff065F46));
  }
  if (m['inventoryRevisionRequested'] == true) {
    return const _InvStatus(
        'Update requested', Color(0xffFFEDD5), Color(0xff9A3412));
  }
  if (m['inventorySubmitted'] == true) {
    return const _InvStatus(
        'Pending approval', Color(0xffFEF3C7), Color(0xff92400E));
  }
  return const _InvStatus(
      'Not uploaded', Color(0xffFEF3C7), Color(0xff92400E));
}

bool _needsUpload(Map<String, dynamic> m) => m['inventorySubmitted'] != true;

// ---------- small widgets ----------

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Pill(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration:
    BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(label.toUpperCase(),
        style: TextStyle(
            color: fg, fontSize: 10, fontWeight: FontWeight.w900)),
  );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final s = status.toUpperCase();
    Color bg = const Color(0xffFEF3C7), fg = const Color(0xff92400E);
    if (s == 'CONFIRMED') {
      bg = const Color(0xffD1FAE5);
      fg = const Color(0xff065F46);
    } else if (s == 'REJECTED') {
      bg = const Color(0xffFEE2E2);
      fg = const Color(0xff991B1B);
    }
    return _Pill(s, bg, fg);
  }
}

Widget _sectionTitle(String t, _C c) => Text(t,
    style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w900));

Widget _tiny(String t, _C c) => Text(t.toUpperCase(),
    style: TextStyle(
        color: c.muted,
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: .5));

class _FieldBox extends StatelessWidget {
  final String label;
  final String value;
  final _C c;
  const _FieldBox(this.label, this.value, this.c);

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: c.tile,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: c.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tiny(label, c),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: c.text, fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

/// Border uniform rakha hai (borderRadius ke saath non-uniform border crash
/// karta hai). Left accent ek alag 3px strip se banayi hai.
class _ContactCard extends StatelessWidget {
  final String title, name, sub, phone;
  final Color accent;
  final IconData icon;
  final _C c;
  const _ContactCard({
    required this.title,
    required this.name,
    required this.sub,
    required this.phone,
    required this.accent,
    required this.icon,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.tile,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(icon, color: accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _tiny(title, c),
                          const SizedBox(height: 3),
                          Text(name,
                              style: TextStyle(
                                  color: c.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900)),
                          Text(sub,
                              style: TextStyle(color: c.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (phone != '-' && phone.isNotEmpty)
                      InkWell(
                        onTap: () => _call(context, phone),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: _blue.withOpacity(.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.call_rounded,
                                  size: 14, color: _blue),
                              const SizedBox(width: 5),
                              Text(phone,
                                  style: const TextStyle(
                                      color: _blue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
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

// =============================================================
// LIST PAGE  (GET /api/confirmations?status=CONFIRMED&page&limit)
// =============================================================

class SeizedConfirmedCases extends StatefulWidget {
  final String? token;

  /// Logged-in repo admin (bank-notify-message ko bhejne ke liye)
  final String? adminName;
  final String? adminPhone;

  /// null = Confirmed cases, 'inventory-confirmed' = Inventory confirmed list
  final String? view;
  final String title;
  const SeizedConfirmedCases({
    super.key,
    required this.token,
    this.adminName,
    this.adminPhone,
    this.view,
    this.title = 'Confirmed cases',
  });

  @override
  State<SeizedConfirmedCases> createState() => _SeizedConfirmedCasesState();
}

class _SeizedConfirmedCasesState extends State<SeizedConfirmedCases> {
  static const int _limit = 50;

  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  final List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _error = false;
  bool _hasNext = false;
  bool _exporting = false;
  int _page = 1;
  int _total = 0;
  String _query = '';

  bool get _inventoryMode => widget.view == 'inventory-confirmed';

  /// Confirmed cases: GET /api/confirmations?status=CONFIRMED&page=1&limit=50&uniqueBy=vehicle
  /// (ek vehicle ek hi baar; total = vehicleTotal)
  /// Inventory confirmed: ...&view=inventory-confirmed
  String get _listUrlBase =>
      '$_baseUrl/api/confirmations?status=CONFIRMED&limit=$_limit'
          '${widget.view == null ? '&uniqueBy=vehicle' : '&view=${widget.view}'}';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300 &&
        _hasNext &&
        !_loadingMore &&
        !_loading) {
      _fetch();
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = false;
        _page = 1;
        _items.clear();
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final pageToLoad = reset ? 1 : _page + 1;

    try {
      final res = await http
          .get(
        Uri.parse('$_listUrlBase&page=$pageToLoad'),
        headers: _headers(widget.token),
      )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final body = jsonDecode(res.body);
      if (body is! Map || body['success'] != true) {
        throw Exception('success=false');
      }

      final list = _asMapList(body['data']);
      final pg = _asMap(body['pagination']);

      if (!mounted) return;
      setState(() {
        _items.addAll(list);
        _page = pageToLoad;
        _hasNext = pg['hasNextPage'] == true;
        // uniqueBy=vehicle me vehicleTotal hi unique count hai (total = requests)
        _total = int.tryParse(
            '${body['vehicleTotal'] ?? pg['total'] ?? _items.length}') ??
            _items.length;
        _loading = false;
        _loadingMore = false;
        _error = false;
      });
    } catch (e) {
      debugPrint('Confirmed cases error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = _items.isEmpty;
      });
      if (_items.isNotEmpty) _toast(context, 'Could not load more. Try again.');
    }
  }

  bool _matches(Map<String, dynamic> e, String query) {
    final q = query.trim().toLowerCase().replaceAll(' ', '');
    if (q.isEmpty) return true;
    final hay = [
      e['vehicleNumber'],
      e['customerName'],
      e['bankName'],
      e['branchName'],
      e['caseCode'],
      e['requestedByName'],
    ].map((v) => (v ?? '').toString().toLowerCase().replaceAll(' ', '')).join('|');
    return hay.contains(q);
  }

  List<Map<String, dynamic>> get _filtered => _query.trim().isEmpty
      ? _items
      : _items.where((e) => _matches(e, _query)).toList();

  // ---------------------------------------------------------
  // DOWNLOAD EXCEL
  // Saare pages server se laata hai (search filter ke saath), .csv banata hai
  // (Excel / Google Sheets seedha khol leta hai) aur phone ke app me kholta hai.
  // ---------------------------------------------------------
  Future<void> _exportExcel() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final all = <Map<String, dynamic>>[];
      var page = 1;
      while (page <= 100) {
        final res = await http
            .get(Uri.parse('$_listUrlBase&page=$page'),
            headers: _headers(widget.token))
            .timeout(const Duration(seconds: 20));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw Exception('HTTP ${res.statusCode}');
        }
        final body = jsonDecode(res.body);
        if (body is! Map || body['success'] != true) {
          throw Exception('success=false');
        }
        all.addAll(_asMapList(body['data']));
        if (_asMap(body['pagination'])['hasNextPage'] != true) break;
        page++;
      }

      final rows = all.where((e) => _matches(e, _query)).toList();
      if (!mounted) return;
      if (rows.isEmpty) {
        _toast(context, 'No data to export');
        return;
      }

      String esc(dynamic v) {
        final s = (v ?? '').toString().replaceAll(RegExp(r'[\r\n]+'), ' ');
        return '"${s.replaceAll('"', '""')}"';
      }

      final header = [
        'S.No',
        'Registration Number',
        'Customer Name',
        'Bank Name',
        'Branch Name',
        'Case Code',
        'Status',
        'Confirmed By',
        'Field Note',
        'Requested By',
        'Requested By Phone',
        'Reported At',
        'Inventory',
        'Parking Yard',
      ];

      final buf = StringBuffer()..writeln(header.map(esc).join(','));
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        final note = _str(r['requestNote']) != '-'
            ? _str(r['requestNote'])
            : _str(r['reviewNote']);
        buf.writeln([
          i + 1,
          _formatVehicle(r['vehicleNumber']),
          _str(r['customerName']),
          _str(r['bankName']),
          _str(r['branchName']),
          _str(r['caseCode']),
          _str(r['status']),
          _str(r['reviewedByName']),
          note,
          _str(r['requestedByName']),
          _str(r['requestedByPhone']),
          _formatDate(r['createdAt']),
          _invStatus(r).label,
          _str(r['parkingYardName']),
        ].map(esc).join(','));
      }

      // UTF-8 BOM: Excel me Hindi/special characters sahi dikhte hain
      final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(buf.toString())];
      final prefix = _inventoryMode ? 'inventory_confirmed' : 'confirmed_cases';
      final file = File(
          '${Directory.systemTemp.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsBytes(bytes, flush: true);

      final r = await OpenFilex.open(file.path);
      if (r.type != ResultType.done) throw Exception(r.message);
      if (mounted) {
        _toast(context, 'Exported ${rows.length} cases', error: false);
      }
    } catch (e) {
      debugPrint('EXPORT ERROR: $e');
      if (mounted) _toast(context, 'Could not export file');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }



  Future<void> _open(Map<String, dynamic> item) async {
    final Widget page = _needsUpload(item)
        ? SeizedUploadInventoryPage(
      item: item,
      token: widget.token,
      adminName: widget.adminName,
      adminPhone: widget.adminPhone,
      onChanged: () {
        if (mounted) _fetch(reset: true);
      },
    )
        : SeizedConfirmedDetailPage(
      item: item,
      token: widget.token,
      adminName: widget.adminName,
      adminPhone: widget.adminPhone,
      // additional upload hone par list khud refresh ho jayegi
      onChanged: () {
        if (mounted) _fetch(reset: true);
      },
    );
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => page));
    if (changed == true && mounted) _fetch(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final list = _filtered;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text(widget.title,
            style: TextStyle(
                color: c.text, fontSize: 17, fontWeight: FontWeight.w900)),
        actions: [
          if (!_loading && !_error)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.dark
                        ? Colors.white.withOpacity(.08)
                        : const Color(0xffE9EEF4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$_total cases',
                      style: TextStyle(
                          color: c.text,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _searchBar(c),
          Expanded(child: _body(c, list)),
        ],
      ),
    );
  }

  Widget _searchBar(_C c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(color: c.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search vehicle, customer, bank, case code…',
                hintStyle: TextStyle(
                    color: c.dark ? Colors.white38 : const Color(0xff94A3B8),
                    fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                ),
                filled: true,
                fillColor: c.card,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: c.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: c.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _blue)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'Download Excel',
            child: Material(
              color: _green,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _exporting ? null : _exportExcel,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: _exporting
                        ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_rounded,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(_C c, List<Map<String, dynamic>> list) {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: 6,
        itemBuilder: (_, __) => _SkeletonCard(c: c),
      );
    }

    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 42, color: c.dark ? Colors.white30 : Colors.black26),
            const SizedBox(height: 10),
            Text('Unable to load confirmed cases',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.muted)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _fetch(reset: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _blue, foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }

    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _fetch(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Icon(Icons.inbox_rounded,
                size: 44, color: c.dark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 10),
            Center(
              child: Text(
                  _query.isEmpty
                      ? (_inventoryMode
                      ? 'No confirmed inventory yet'
                      : 'No confirmed cases')
                      : 'No matches found',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.muted)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetch(reset: true),
      color: _blue,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: list.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= list.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            );
          }
          final item = list[i];
          final sNo = _query.isEmpty ? _total - i : list.length - i;
          return _CaseCard(
              item: item,
              sNo: sNo,
              c: c,
              inventoryMode: _inventoryMode,
              onTap: () => _open(item));
        },
      ),
    );
  }
}

/// Sidebar ke "Inventory confirmed" page ke liye ready screen.
/// GET /api/confirmations?status=CONFIRMED&page=1&limit=50&view=inventory-confirmed
///
/// Navigate:
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => InventoryConfirmedPage(
///       token: token, adminName: name, adminPhone: phone)));
class SeizedInventoryConfirmedPage extends StatelessWidget {
  final String? token;
  final String? adminName;
  final String? adminPhone;
  const SeizedInventoryConfirmedPage({
    super.key,
    required this.token,
    this.adminName,
    this.adminPhone,
  });

  @override
  Widget build(BuildContext context) => SeizedConfirmedCases(
    token: token,
    adminName: adminName,
    adminPhone: adminPhone,
    view: 'inventory-confirmed',
    title: 'Inventory confirmed',
  );
}

class _CaseCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int sNo;
  final _C c;
  final VoidCallback onTap;
  final bool inventoryMode;
  const _CaseCard(
      {required this.item,
        required this.sNo,
        required this.c,
        required this.onTap,
        this.inventoryMode = false});

  Widget _inventorySummary() {
    int n(String k) => (item[k] as List? ?? []).length;
    final yard = _str(item['parkingYardName']);

    Widget chip(IconData i, String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.tile,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 13, color: _blue),
          const SizedBox(width: 5),
          Text(t,
              style: TextStyle(
                  color: c.text,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            chip(Icons.photo_rounded, '${n('inventoryImages')} photos'),
            chip(Icons.videocam_rounded, '${n('inventoryVideos')} videos'),
            chip(Icons.picture_as_pdf_rounded, '${n('inventoryPdfs')} PDFs'),
          ],
        ),
        if (yard != '-') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.local_parking_rounded, size: 15, color: c.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(yard,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: c.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.verified_rounded, size: 15, color: _green),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  'Inventory confirmed ${_formatDate(item['inventoryConfirmedAt'])}',
                  style: TextStyle(color: c.muted, fontSize: 11.5)),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final inv = _invStatus(item);
    final upload = !inventoryMode && _needsUpload(item);
    final note = _str(item['requestNote']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(c.dark ? .22 : .04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _blue.withOpacity(.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('#$sNo',
                    style: const TextStyle(
                        color: _blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_formatVehicle(item['vehicleNumber']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: c.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .3)),
              ),
              _StatusChip(_str(item['status'])),
            ],
          ),
          const SizedBox(height: 10),
          Text(_str(item['customerName']),
              style: TextStyle(
                  color: c.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('${_str(item['bankName'])} • ${_str(item['branchName'])}',
              style: TextStyle(
                  color: c.muted, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(_str(item['caseCode']),
              style: TextStyle(
                  color: c.muted, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Divider(height: 1, color: c.border),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_pin_rounded, size: 16, color: c.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    '${_str(item['requestedByName'])} (${_str(item['requestedByRoleLabel'])})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: c.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              InkWell(
                onTap: () => _call(context, _str(item['requestedByPhone'])),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      const Icon(Icons.call_rounded, size: 14, color: _blue),
                      const SizedBox(width: 4),
                      Text(_str(item['requestedByPhone']),
                          style: const TextStyle(
                              color: _blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 15, color: c.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_formatDate(item['createdAt']),
                    style: TextStyle(color: c.muted, fontSize: 11.5)),
              ),
              _Pill(inv.label, inv.bg, inv.fg),
            ],
          ),
          if (inventoryMode) ...[
            const SizedBox(height: 10),
            _inventorySummary(),
          ],
          if (note != '-') ...[
            const SizedBox(height: 8),
            Text(note, style: TextStyle(color: c.muted, fontSize: 11.5)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: upload ? _green : _blue,
                backgroundColor: (upload ? _green : _blue).withOpacity(.07),
                side: BorderSide(
                    color: (upload ? _green : _blue).withOpacity(.35)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(upload ? 'Upload Inventory' : 'View',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final _C c;
  const _SkeletonCard({required this.c});

  @override
  Widget build(BuildContext context) {
    final base = c.dark ? Colors.white12 : const Color(0xffE9EEF4);
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
          color: base, borderRadius: BorderRadius.circular(6)),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      height: 150,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(160, 16),
          const SizedBox(height: 14),
          bar(110, 12),
          const SizedBox(height: 8),
          bar(190, 12),
          const Spacer(),
          bar(double.infinity, 36),
        ],
      ),
    );
  }
}

// =============================================================
// DETAIL PAGE
//   GET  /api/confirmations/:id
//   POST /api/repo-cases/bank-notify-message
// =============================================================

class SeizedConfirmedDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final String? token;
  final String? adminName;
  final String? adminPhone;

  /// Inventory upload / additional upload ke baad list refresh karne ke liye
  final VoidCallback? onChanged;
  const SeizedConfirmedDetailPage({
    super.key,
    required this.item,
    required this.token,
    this.adminName,
    this.adminPhone,
    this.onChanged,
  });

  @override
  State<SeizedConfirmedDetailPage> createState() => _SeizedConfirmedDetailPageState();
}

class _SeizedConfirmedDetailPageState extends State<SeizedConfirmedDetailPage> {
  bool _loading = true;
  bool _error = false;
  bool _requesting = false;

  Map<String, dynamic> _conf = {};
  Map<String, dynamic> _case = {};
  Map<String, dynamic> _notify = {};

  final _updateNoteCtrl = TextEditingController();

  String get _id => widget.item['_id'].toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _updateNoteCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // LOAD: confirmation -> bank notify message
  // ---------------------------------------------------------
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final b = await _loadBundle(
        id: _id,
        token: widget.token,
        adminName: widget.adminName,
        adminPhone: widget.adminPhone,
      );
      if (!mounted) return;
      setState(() {
        _conf = b.conf;
        _case = b.cs;
        _notify = b.notify;
        _loading = false;
      });
    } catch (e) {
      debugPrint('DETAIL LOAD ERROR: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  // ---------------------------------------------------------
  // derived
  // ---------------------------------------------------------
  Map<String, dynamic> get _item => _conf.isNotEmpty ? _conf : widget.item;
  String get _message => (_notify['message'] ?? '').toString();
  String get _subject => (_notify['subject'] ?? '').toString();

  List<Map<String, dynamic>> get _recipients =>
      _asMapList(_notify['recipientOptions']);

  /// Repo admin: message se (Contact person / Mobile), warna login wale se.
  Map<String, String> get _admin {
    String g(RegExp r, String fallback) {
      final v = r.firstMatch(_message)?.group(1)?.trim();
      return (v == null || v.isEmpty) ? fallback : v;
    }

    return {
      'agency':
      g(RegExp(r'Greetings from (.+?)[.\n]', caseSensitive: false), '-'),
      'name': g(RegExp(r'Contact person\s*:\s*(.+)', caseSensitive: false),
          _str(widget.adminName)),
      'phone': g(RegExp(r'Mobile\s*:\s*\+?(\d[\d\s-]*)', caseSensitive: false),
          _str(widget.adminPhone)),
    };
  }

  // ---------------------------------------------------------
  // NOTIFY BANK
  // ---------------------------------------------------------
  Future<void> _whatsApp(String rawPhone) async {
    final phone = _normPhone(rawPhone);
    if (_message.isEmpty) return _toast(context, 'Message not available');
    if (phone.isEmpty) {
      return _toast(context, 'No phone number for this recipient');
    }
    await _launch(
      context,
      Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(_message)}'),
      'Could not open WhatsApp',
    );
  }

  Future<void> _sms(String rawPhone) async {
    final phone = _normPhone(rawPhone);
    if (_message.isEmpty) return _toast(context, 'Message not available');
    if (phone.isEmpty) {
      return _toast(context, 'No phone number for this recipient');
    }
    final sep = Platform.isIOS ? '&' : '?';
    await _launch(
      context,
      Uri.parse('sms:$phone${sep}body=${Uri.encodeComponent(_message)}'),
      'Could not open SMS app',
    );
  }

  Future<void> _email() async {
    if (_message.isEmpty) return _toast(context, 'Message not available');
    var to = (_notify['bankNotifyEmail'] ?? '').toString().trim();
    if (to.isEmpty) {
      for (final r in _recipients) {
        final e = (r['email'] ?? '').toString().trim();
        if (e.isNotEmpty) {
          to = e;
          break;
        }
      }
    }
    // email nahi mila to bhi popup nahi: mail app seedha khulta hai (To khali),
    // subject + message bhara hua.
    await _launch(
      context,
      Uri.parse(
          'mailto:$to?subject=${Uri.encodeComponent(_subject)}&body=${Uri.encodeComponent(_message)}'),
      'Could not open email app',
    );
  }

  Future<void> _pickRecipient(
      String id, Future<void> Function(String phone) send) async {
    if (id == 'custom') {
      final typed = await _askText(
          context, 'Phone number', 'Enter phone number', TextInputType.phone);
      if (typed == null || typed.isEmpty) return;
      await send(typed);
      return;
    }
    final r = _recipients.firstWhere((e) => e['id'].toString() == id,
        orElse: () => <String, dynamic>{});
    final phone = (r['phone'] ?? _notify['bankNotifyPhone'] ?? '').toString();
    await send(phone);
  }

  // ---------------------------------------------------------
  // REQUEST INVENTORY UPDATE
  // ---------------------------------------------------------
  Future<void> _requestInventoryUpdate() async {
    setState(() => _requesting = true);
    try {
      final res = await http
          .post(
        Uri.parse(_requestInventoryUpdateUrl(_id)),
        headers: _headers(widget.token),
        body: jsonEncode({
          'note': _updateNoteCtrl.text.trim(),
          'revisionNote': _updateNoteCtrl.text.trim(),
        }),
      )
          .timeout(const Duration(seconds: 20));

      dynamic body;
      try {
        body = jsonDecode(res.body);
      } catch (_) {}

      final ok = res.statusCode >= 200 &&
          res.statusCode < 300 &&
          (body is! Map || body['success'] != false);

      if (!mounted) return;
      if (ok) {
        _toast(
            context,
            body is Map && body['message'] != null
                ? body['message'].toString()
                : 'Inventory update requested',
            error: false);
        _updateNoteCtrl.clear();
        _load();
        widget.onChanged?.call();
      } else {
        _toast(
            context,
            body is Map && body['message'] != null
                ? body['message'].toString()
                : 'Request failed (${res.statusCode})');
      }
    } catch (e) {
      debugPrint('REQUEST UPDATE ERROR: $e');
      _toast(context, 'Unable to submit right now');
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  // ---------------------------------------------------------
  // ADD MORE FILES (additional inventory)
  // ---------------------------------------------------------
  Future<void> _openAdditionalUpload() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SeizedUploadInventoryPage(
          item: _item,
          token: widget.token,
          adminName: widget.adminName,
          adminPhone: widget.adminPhone,
          additional: true,
          existing: _conf,
        ),
      ),
    );
    if (changed == true) {
      _load();
      widget.onChanged?.call();
    }
  }

  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: c.dark
                        ? Colors.white.withOpacity(.08)
                        : const Color(0xffE9EEF4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: c.text),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: c.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error)
                      _errorView(c)
                    else ...[
                        _contactSection(c),
                        Divider(height: 1, color: c.border),
                        _fieldsSection(c),
                        Divider(height: 1, color: c.border),
                        _inventorySection(c),
                        if (_message.isNotEmpty) ...[
                          Divider(height: 1, color: c.border),
                          _notifySection(c),
                        ],
                      ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final item = _item;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff06162D), Color(0xff1D4ED8)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text('REPOSSESSION — TRACE CONFIRMATION',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5)),
              ),
              _StatusChip(_str(item['status'])),
            ],
          ),
          const SizedBox(height: 8),
          Text(_formatVehicle(item['vehicleNumber']),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            '${_str(item['bankName'])} / ${_str(item['branchName'])} · Traced by ${_str(item['requestedByName'])}',
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _errorView(_C c) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      children: [
        Icon(Icons.cloud_off_rounded, size: 40, color: c.muted),
        const SizedBox(height: 10),
        Text('Unable to load details',
            style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
              backgroundColor: _blue, foregroundColor: Colors.white),
        ),
      ],
    ),
  );

  // ---------- Contact details ----------
  Widget _contactSection(_C c) {
    final admin = _admin;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Contact details', c),
          const SizedBox(height: 10),
          _ContactCard(
            title: 'TRACER (FIELD REPORT)',
            name: _str(
                _conf['requestedByName'] ?? widget.item['requestedByName']),
            sub: _str(_conf['requestedByRoleLabel'] ??
                widget.item['requestedByRoleLabel']),
            phone: _str(
                _conf['requestedByPhone'] ?? widget.item['requestedByPhone']),
            accent: const Color(0xffF59E0B),
            icon: Icons.person_rounded,
            c: c,
          ),
          const SizedBox(height: 10),
          _ContactCard(
            title: 'REPO ADMIN',
            name: admin['name']!,
            sub: admin['agency']!,
            phone: admin['phone']!,
            accent: _blue,
            icon: Icons.apartment_rounded,
            c: c,
          ),
        ],
      ),
    );
  }

  Widget _fieldsSection(_C c) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _vehicleFields(
        c,
        caseMap: _case,
        notify: _notify,
        requestNote: _str(_conf['requestNote']),
      ),
    );
  }

  // ---------- Inventory ----------
  /// kind (image/video/pdf) ke files category-wise group karta hai.
  /// inventoryFileMeta me jo path nahi hai (purane records) wo raw list se
  /// '' category me aa jate hain, taaki koi file chhoote nahi.
  Map<String, List<String>> _group(String kind, String rawKey) {
    final out = <String, List<String>>{};
    final seen = <String>{};
    for (final m in _asMapList(_conf['inventoryFileMeta'])) {
      final p = (m['path'] ?? '').toString();
      if (m['kind'] == kind && p.isNotEmpty) {
        out.putIfAbsent((m['category'] ?? '').toString(), () => []).add(p);
        seen.add(p);
      }
    }
    for (final raw in (_conf[rawKey] as List? ?? [])) {
      final p = raw.toString();
      if (p.isNotEmpty && !seen.contains(p)) {
        out.putIfAbsent('', () => []).add(p);
      }
    }
    return out;
  }

  Widget _inventorySection(_C c) {
    final submitted = _conf['inventorySubmitted'] == true;

    if (!submitted) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('Tracer inventory (pre/post)', c),
            const SizedBox(height: 8),
            Text('Inventory has not been uploaded yet.',
                style: TextStyle(color: c.muted, fontSize: 12.5)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => SeizedUploadInventoryPage(
                      item: _item,
                      token: widget.token,
                      adminName: widget.adminName,
                      adminPhone: widget.adminPhone,
                      onChanged: widget.onChanged,
                    ),
                  ),
                );
                if (changed == true) {
                  _load();
                  widget.onChanged?.call();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Upload Inventory',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
    }

    final images = _group('image', 'inventoryImages');
    final videos = _group('video', 'inventoryVideos');
    final pdfs = _group('pdf', 'inventoryPdfs');
    final allImages = images.values.expand((e) => e).toList();
    final confirmed = _conf['inventoryConfirmed'] == true;
    final yardName = _str(_conf['parkingYardName']);
    final revNote = _str(_conf['inventoryRevisionNote']);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Tracer inventory (pre/post)', c),
          const SizedBox(height: 4),
          Text('Submitted ${_formatDate(_conf['inventorySubmittedAt'])}',
              style: TextStyle(color: c.muted, fontSize: 12)),
          const SizedBox(height: 12),
          if (yardName != '-') _yardCard(c, yardName),
          if (confirmed)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xffE6FAEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                  'Inventory confirmed ${_formatDate(_conf['inventoryConfirmedAt'])}.',
                  style: const TextStyle(
                      color: Color(0xff065F46),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ),
          if (_conf['inventoryRevisionRequested'] == true)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xffFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                  'Update requested${revNote != '-' ? ': $revNote' : '.'}',
                  style: const TextStyle(
                      color: Color(0xff9A3412),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.tile,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (images.isNotEmpty) ...[
                  _sectionTitle('Photos', c),
                  const SizedBox(height: 8),
                  ...images.entries
                      .map((e) => _photoGroup(c, e.key, e.value, allImages)),
                ],
                if (videos.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _sectionTitle('Videos', c),
                  const SizedBox(height: 8),
                  ...videos.entries
                      .map((e) => _fileGroup(c, e.key, e.value, 'video')),
                ],
                if (pdfs.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _sectionTitle('PDFs', c),
                  const SizedBox(height: 8),
                  ...pdfs.entries
                      .map((e) => _fileGroup(c, e.key, e.value, 'pdf')),
                ],
                if (images.isEmpty && videos.isEmpty && pdfs.isEmpty)
                  Text('No files attached.',
                      style: TextStyle(color: c.muted, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openAdditionalUpload,
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
              label: const Text('Add more files',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _blue,
                backgroundColor: _blue.withOpacity(.06),
                side: BorderSide(color: _blue.withOpacity(.35)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: c.border),
          const SizedBox(height: 14),
          _sectionTitle('Ask tracer to update inventory', c),
          const SizedBox(height: 4),
          Text(
              'Sends a notification so they can add more photos, videos, or PDFs to this case.',
              style: TextStyle(color: c.muted, fontSize: 12)),
          const SizedBox(height: 10),
          _tiny('Note to tracer (optional)', c),
          const SizedBox(height: 6),
          TextField(
            controller: _updateNoteCtrl,
            minLines: 2,
            maxLines: 4,
            style: TextStyle(color: c.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g. Please add yard photos and RC copy',
              hintStyle: TextStyle(color: c.muted, fontSize: 13),
              filled: true,
              fillColor: c.card,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.border)),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: _requesting ? null : _requestInventoryUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _requesting
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Text('Request inventory update',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _yardCard(_C c, String name) {
    Widget row(String l, String v, {VoidCallback? onTap}) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 70,
              child: Text(l,
                  style: TextStyle(color: c.muted, fontSize: 12))),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Text(v,
                  style: TextStyle(
                      color: onTap == null ? c.text : _blue,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );

    final address = _str(_conf['parkingYardAddress']);
    final area = _str(_conf['parkingYardArea']);
    final pin = _str(_conf['parkingYardPincode']);
    final phone = _str(_conf['parkingYardPhone']);
    final mgrName = _str(_conf['parkingYardManagerName']);
    final mgrPhone = _str(_conf['parkingYardManagerPhone']);
    final mapQuery = [address, area, pin].where((e) => e != '-').join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.dark ? const Color(0xff1B2140) : const Color(0xffE8EBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: c.dark ? const Color(0xff3A4380) : const Color(0xffC7CCF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PARKING YARD',
              style: TextStyle(
                  color: Color(0xff3730A3),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5)),
          const SizedBox(height: 4),
          Text(name,
              style: TextStyle(
                  color: c.text, fontSize: 15, fontWeight: FontWeight.w900)),
          if (area != '-')
            Text(area, style: TextStyle(color: c.muted, fontSize: 11.5)),
          const SizedBox(height: 4),
          if (address != '-') row('Address', address),
          if (area != '-') row('Area', area),
          if (pin != '-') row('PIN', pin),
          if (phone != '-')
            row('Phone No', phone, onTap: () => _call(context, phone)),
          if (mgrName != '-') row('Manager', mgrName),
          if (mgrPhone != '-')
            row('Mgr Phone', mgrPhone, onTap: () => _call(context, mgrPhone)),
          if (mapQuery.isNotEmpty)
            row(
              'Location',
              'View on Map',
              onTap: () => _launch(
                  context,
                  Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$name, $mapQuery')}'),
                  'Could not open maps'),
            ),
        ],
      ),
    );
  }

  Widget _photoGroup(
      _C c, String category, List<String> paths, List<String> all) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_catLabel(category, fallback: 'Photos'),
              style: TextStyle(
                  color: c.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: paths.map((p) {
              final idx = all.indexOf(p);
              return GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _GalleryPage(
                    paths: all,
                    initial: idx < 0 ? 0 : idx,
                    token: widget.token,
                  ),
                )),
                child: _NetImage(
                  path: p,
                  token: widget.token,
                  c: c,
                  width: 90,
                  height: 90,
                  radius: 10,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _fileGroup(_C c, String category, List<String> paths, String kind) {
    final isVideo = kind == 'video';
    final icon = isVideo
        ? Icons.play_circle_fill_rounded
        : Icons.picture_as_pdf_rounded;
    final iconColor =
    isVideo ? const Color(0xff6610F2) : const Color(0xffD00F1F);
    final label = _catLabel(category, fallback: isVideo ? 'Videos' : 'PDFs');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: c.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ...List.generate(paths.length, (i) {
            final p = paths[i];
            final title = '$label ${i + 1}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  if (isVideo) {
                    _openVideo(context, p, widget.token);
                  } else {
                    _openPdf(context, p, widget.token);
                  }
                },
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 22, color: iconColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                color: _blue,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 20, color: c.muted),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---------- Notify bank ----------
  Widget _notifySection(_C c) {
    Widget btn(String label, IconData icon, Color color) => Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
          if (label != 'Email')
            const Icon(Icons.arrow_drop_down_rounded,
                size: 18, color: Colors.white),
        ],
      ),
    );

    PopupMenuButton<String> menu(String label, IconData icon, Color color,
        Future<void> Function(String phone) send) {
      return PopupMenuButton<String>(
        onSelected: (id) => _pickRecipient(id, send),
        itemBuilder: (_) => _recipients.map((r) {
          final id = r['id'].toString();
          final name = (r['name'] ?? '').toString();
          final lbl = id == 'custom'
              ? 'Other (enter manually)'
              : '${name.isNotEmpty ? name : (r['label'] ?? '')}'
              '${(r['phone'] ?? '').toString().isNotEmpty ? ' • ${r['phone']}' : ''}';
          return PopupMenuItem<String>(value: id, child: Text(lbl));
        }).toList(),
        child: btn(label, icon, color),
      );
    }

    final hasOptions = _recipients.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Notify bank', c),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: hasOptions
                    ? menu('WhatsApp', Icons.chat_rounded,
                    const Color(0xff1A9A3C), _whatsApp)
                    : GestureDetector(
                    onTap: () => _whatsApp(
                        (_notify['bankNotifyPhone'] ?? '').toString()),
                    child: btn('WhatsApp', Icons.chat_rounded,
                        const Color(0xff1A9A3C))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: hasOptions
                    ? menu('SMS', Icons.sms_rounded, const Color(0xff6610F2),
                    _sms)
                    : GestureDetector(
                    onTap: () =>
                        _sms((_notify['bankNotifyPhone'] ?? '').toString()),
                    child: btn('SMS', Icons.sms_rounded,
                        const Color(0xff6610F2))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                    onTap: _email,
                    child: btn('Email', Icons.email_rounded,
                        const Color(0xff1D4ED8))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================
// UPLOAD INVENTORY PAGE
//   POST /api/confirmations/:id/inventory   (multipart)
//   GET  /api/parking-yards/search?q=...
//
//   additional = false : pehli baar inventory submit (yard + vehicle details)
//   additional = true  : already submit inventory me aur files jodna
//                        (existing = GET /confirmations/:id ka `confirmation`)
// =============================================================

class _Slot {
  final String category;
  final String label;
  String? path;
  _Slot(this.category, this.label);
  String get fileName => path == null ? '' : path!.split('/').last;
}

class SeizedUploadInventoryPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final String? token;
  final String? adminName;
  final String? adminPhone;
  final bool additional;
  final Map<String, dynamic> existing;

  /// Submit ke baad jo ConfirmedDetailPage khulta hai, usse list refresh ke liye
  final VoidCallback? onChanged;
  const SeizedUploadInventoryPage({
    super.key,
    required this.item,
    required this.token,
    this.adminName,
    this.adminPhone,
    this.additional = false,
    this.existing = const {},
    this.onChanged,
  });

  @override
  State<SeizedUploadInventoryPage> createState() => _UploadInventoryPageState();
}

class _UploadInventoryPageState extends State<SeizedUploadInventoryPage> {
  static const _photoCats = <List<String>>[
    ['front', 'Front Photo'],
    ['side', 'Side Photo'],
    ['back', 'Back Photo'],
    ['tire', 'Tire Photo'],
    ['chassis', 'Chassis'],
    ['engine', 'Engine'],
    ['meter', 'Meter'],
    ['glass', 'Glass'],
    ['crack', 'Crack Item'],
    ['key', 'Key'],
    ['rc', 'RC'],
    ['insurance', 'Insurance'],
    ['bilty', 'Bilty'],
    ['jack_rod', 'Jack Rod'],
    ['stepney', 'Stepney'],
    ['driver', 'Driver Photo'],
  ];
  static const _videoCats = <List<String>>[
    ['vehicle_condition', 'Vehicle Condition'],
    ['videos', 'Videos'],
  ];
  static const _pdfCats = <List<String>>[
    ['pre_post', 'Pre/Post Inventory'],
    ['inventory_sheet', 'Inventory Sheet'],
    ['crane_bill', 'Crane Bill'],
    ['other_bills', 'Other Bills'],
  ];
  static const _limits = {'images': 30, 'videos': 15, 'pdfs': 15};

  final Map<String, List<_Slot>> _slots = {};
  final _picker = ImagePicker();

  // parking yard
  final _yardSearchCtrl = TextEditingController();
  Timer? _debounce;
  int _yardReq = 0;
  bool _searchingYard = false;
  List<Map<String, String>> _yardResults = [];
  Map<String, String>? _yard;
  bool _manual = false;
  final _mName = TextEditingController();
  final _mAddress = TextEditingController();
  final _mArea = TextEditingController();
  final _mPin = TextEditingController();
  final _mPhone = TextEditingController();
  String? _manualError;

  bool _submitting = false;

  // vehicle & trace details (web page jaisa)
  Map<String, dynamic> _dConf = {};
  Map<String, dynamic> _dCase = {};
  bool _dLoading = true;
  bool _dError = false;

  String get _id => widget.item['_id'].toString();

  // ---------- already saved files (additional mode) ----------
  int _saved(String kind) {
    if (!widget.additional) return 0;
    const keys = {
      'images': 'inventoryImages',
      'videos': 'inventoryVideos',
      'pdfs': 'inventoryPdfs',
    };
    return (widget.existing[keys[kind]] as List? ?? []).length;
  }

  /// is kind me abhi aur kitni files jud sakti hain
  int _cap(String kind) => _limits[kind]! - _saved(kind);

  @override
  void initState() {
    super.initState();
    _slots['images'] = _photoCats.map((e) => _Slot(e[0], e[1])).toList();
    _slots['videos'] = _videoCats.map((e) => _Slot(e[0], e[1])).toList();
    _slots['pdfs'] = _pdfCats.map((e) => _Slot(e[0], e[1])).toList();

    if (widget.additional) {
      // yard already saved hai; vehicle details dobara load nahi karte
      final y = _yardFromConfirmation(widget.existing);
      if ((y['name'] ?? '').isNotEmpty) _yard = y;
      _dLoading = false;
    } else {
      _loadDetails();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _yardSearchCtrl.dispose();
    _mName.dispose();
    _mAddress.dispose();
    _mArea.dispose();
    _mPin.dispose();
    _mPhone.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _dLoading = true;
      _dError = false;
    });
    try {
      final b = await _loadBundle(
        id: _id,
        token: widget.token,
        adminName: widget.adminName,
        adminPhone: widget.adminPhone,
        withNotify: false,
      );
      if (!mounted) return;
      setState(() {
        _dConf = b.conf;
        _dCase = b.cs;
        _dLoading = false;
      });
    } catch (e) {
      debugPrint('UPLOAD DETAILS ERROR: $e');
      if (!mounted) return;
      setState(() {
        _dLoading = false;
        _dError = true;
      });
    }
  }

  Widget _detailsSection(_C c) {
    if (_dLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (_dError) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Expanded(
              child: Text('Could not load vehicle details.',
                  style: TextStyle(color: c.muted, fontSize: 12.5)),
            ),
            TextButton(onPressed: _loadDetails, child: const Text('Retry')),
          ],
        ),
      );
    }

    final revNote = _str(_dConf['inventoryRevisionNote']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Vehicle & trace details', c),
        const SizedBox(height: 10),
        if (_dConf['inventoryRevisionRequested'] == true)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xffFFF3E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
                'Update requested${revNote != '-' ? ': $revNote' : '.'}',
                style: const TextStyle(
                    color: Color(0xff9A3412),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ),
        _traceTable(c),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Web ke user page jaisa "Field | Value" table (Vehicle & trace details)
  Widget _traceTable(_C c) {
    final k = _dCase;
    final f = _dConf.isNotEmpty ? _dConf : widget.item;

    // pehli non-empty value, warna '—'
    String first(List<dynamic> xs) {
      for (final x in xs) {
        final s = (x ?? '').toString().trim();
        if (s.isNotEmpty && s != 'null' && s != '-') return s;
      }
      return '—';
    }

    final status = first([f['status'], k['confirmationStatus']]);
    final statusNice = status == '—'
        ? status
        : status[0].toUpperCase() + status.substring(1).toLowerCase();

    final rows = <List<String>>[
      ['Traced By', first([f['requestedByName']])],
      ['Tracer Role', first([f['requestedByRoleLabel']])],
      ['Reporter Mobile', first([f['requestedByPhone']])],
      ['Field Note', first([f['requestNote'], f['reviewNote']])],
      ['Reported At', _formatDateTable(f['createdAt'])],
      ['Confirmation Status', first([f['status'], k['confirmationStatus']])],
      ['Agency / Company',
        first([k['companyName'], k['agencyName'], f['companyName']])],
      ['Registration No', first([k['vehicleNumber'], f['vehicleNumber']])],
      ['Customer Name', first([k['customerName'], f['customerName']])],
      ['Father Name', first([k['fatherName']])],
      ['Mobile No', first([k['mobileNumber']])],
      ['Alternate Mobile No', first([k['alternateMobileNumber']])],
      ['Reference No', first([k['referenceNumber']])],
      ['Engine No', first([k['engineNumber']])],
      ['Chassis No', first([k['chassisNumber']])],
      ['Vehicle Brand', first([k['vehicleBrand']])],
      ['Vehicle Model', first([k['vehicleModel']])],
      ['Registration State', first([k['registrationState']])],
      ['City', first([k['city']])],
      ['District', first([k['district']])],
      ['State', first([k['state']])],
      ['Pincode', first([k['pincode']])],
      ['Outstanding Amount',
        first([k['totalOutstandingAmount'], k['dueAmount']])],
      ['Priority', first([k['priority']])],
      ['Field Notes', first([k['fieldNotes']])],
      ['Loaded details', first([k['loadedDetail'], k['loadedShort']])],
      ['Status', statusNice],
    ];

    Widget cell(String t, {bool bold = false, bool head = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Text(
        t,
        textAlign: head ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          color: c.text,
          fontSize: head ? 13 : 12.5,
          fontWeight: (bold || head) ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.text.withOpacity(.55), width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(1.25),
        },
        border: TableBorder.symmetric(inside: BorderSide(color: c.border)),
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: c.dark ? const Color(0xff1A2440) : const Color(0xffE5E7EB),
            ),
            children: [
              cell('Field', head: true),
              cell('Value', head: true),
            ],
          ),
          for (var i = 0; i < rows.length; i++)
            TableRow(
              decoration: BoxDecoration(color: i.isEven ? c.card : c.tile),
              children: [
                cell(rows[i][0], bold: true),
                cell(rows[i][1]),
              ],
            ),
        ],
      ),
    );
  }

  int _selected(String kind) =>
      _slots[kind]!.where((s) => s.path != null).length;

  void _addMore(String kind, _Slot like) {
    final list = _slots[kind]!;
    if (list.length >= _limits[kind]!) {
      return _toast(context, 'Slot limit reached');
    }
    final last = list.lastIndexWhere((s) => s.category == like.category);
    setState(() => list.insert(last + 1, _Slot(like.category, like.label)));
  }

  Future<void> _pick(String kind, _Slot slot) async {
    // naya slot bharne se pehle limit check (change karne par nahi)
    if (slot.path == null && _selected(kind) >= _cap(kind)) {
      return _toast(context, 'Slot limit reached');
    }
    try {
      if (kind == 'images') {
        final src = await showModalBottomSheet<ImageSource>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Wrap(children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ]),
          ),
        );
        if (src == null) return;
        final f = await _picker.pickImage(source: src, imageQuality: 85);
        if (f != null) setState(() => slot.path = f.path);
      } else if (kind == 'videos') {
        final f = await _picker.pickVideo(source: ImageSource.gallery);
        if (f != null) setState(() => slot.path = f.path);
      } else {
        final p = await _pickPdfPath();
        if (p != null) setState(() => slot.path = p);
      }
    } catch (e) {
      debugPrint('PICK ERROR: $e');
      _toast(context, 'Could not pick file');
    }
  }

  // ---------- parking yard ----------
  void _onYardSearch(String q) {
    _debounce?.cancel();
    final query = q.trim();
    if (query.length < 2) {
      setState(() {
        _yardResults = [];
        _searchingYard = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final req = ++_yardReq; // purana response naye ko overwrite na kare
      setState(() => _searchingYard = true);
      try {
        final res = await http
            .get(Uri.parse(_parkingYardSearchUrl(query)),
            headers: _headers(widget.token))
            .timeout(const Duration(seconds: 15));
        final body = jsonDecode(res.body);
        final data = body is Map ? body['data'] : null;
        final raw = data is Map ? (data['yards'] ?? data['items']) : data;
        final list = _asMapList(raw).map(_yardFromJson).toList();
        if (!mounted || req != _yardReq) return;
        setState(() => _yardResults = list);
      } catch (e) {
        debugPrint('YARD SEARCH ERROR: $e');
      } finally {
        if (mounted && req == _yardReq) {
          setState(() => _searchingYard = false);
        }
      }
    });
  }

  void _addManualYard() {
    if (_mName.text.trim().isEmpty) {
      setState(() => _manualError = 'Enter parking yard name.');
      return;
    }
    setState(() {
      _yard = {
        'id': '',
        'name': _mName.text.trim(),
        'address': _mAddress.text.trim(),
        'area': _mArea.text.trim(),
        'pincode': _mPin.text.trim(),
        'phone': _mPhone.text.trim(),
        'managerName': '',
        'managerPhone': '',
        'code': '',
      };
      _manual = false;
      _manualError = null;
    });
  }

  // ---------- submit ----------
  Future<void> _submit() async {
    final total = _selected('images') + _selected('videos') + _selected('pdfs');
    if (total == 0) return _toast(context, 'Add at least one file');
    if (!widget.additional && _yard == null) {
      return _toast(context, 'Select or add a parking yard');
    }

    setState(() => _submitting = true);
    try {
      final req =
      http.MultipartRequest('POST', Uri.parse(_submitInventoryUrl(_id)));
      req.headers.addAll(_headers(widget.token, json: false));

      final y = _yard ?? const <String, String>{};
      void put(String field, String? v) {
        if ((v ?? '').trim().isNotEmpty) req.fields[field] = v!.trim();
      }

      put('parkingYardId', y['id']);
      put('parkingYardName', y['name']);
      put('parkingYardAddress', y['address']);
      put('parkingYardArea', y['area']);
      put('parkingYardPincode', y['pincode']);
      put('parkingYardPhone', y['phone']);
      put('parkingYardManagerName', y['managerName']);
      put('parkingYardManagerPhone', y['managerPhone']);
      put('parkingYardCode', y['code']);

      for (final kind in ['images', 'videos', 'pdfs']) {
        final cats = <String>[];
        for (final s in _slots[kind]!.where((s) => s.path != null)) {
          req.files.add(await http.MultipartFile.fromPath(kind, s.path!));
          cats.add(s.category);
        }
        // file order ke hisaab se category list:
        // imageCategories / videoCategories / pdfCategories
        if (cats.isNotEmpty || !widget.additional) {
          req.fields['${kind.substring(0, kind.length - 1)}Categories'] =
              jsonEncode(cats);
        }
      }

      final streamed = await req.send().timeout(const Duration(minutes: 5));
      final res = await http.Response.fromStream(streamed);

      dynamic body;
      try {
        body = jsonDecode(res.body);
      } catch (_) {}
      final ok = res.statusCode >= 200 &&
          res.statusCode < 300 &&
          (body is! Map || body['success'] != false);

      if (!mounted) return;
      if (ok) {
        _toast(
            context,
            body is Map && body['message'] != null
                ? body['message'].toString()
                : (widget.additional
                ? 'Additional files uploaded'
                : 'Inventory submitted'),
            error: false);

        if (widget.additional) {
          Navigator.of(context).pop(true);
        } else {
          // Submit ke baad inventory seedha dikhao (response data = confirmation)
          final data =
          body is Map ? _asMap(body['data']) : <String, dynamic>{};
          final item = <String, dynamic>{...widget.item, ...data};
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SeizedConfirmedDetailPage(
                item: item,
                token: widget.token,
                adminName: widget.adminName,
                adminPhone: widget.adminPhone,
                onChanged: widget.onChanged,
              ),
            ),
            result: true, // list ko refresh karne ke liye
          );
        }
      } else {
        _toast(
            context,
            body is Map && body['message'] != null
                ? body['message'].toString()
                : 'Submit failed (${res.statusCode})');
      }
    } catch (e) {
      debugPrint('SUBMIT INVENTORY ERROR: $e');
      _toast(context, 'Unable to submit right now');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final it = widget.item;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text(widget.additional ? 'Add more files' : 'Inventory pre/post',
            style: TextStyle(
                color: c.text, fontSize: 17, fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatVehicle(it['vehicleNumber']),
                    style: TextStyle(
                        color: c.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                    '${_str(it['customerName'])} • ${_str(it['bankName'])} / ${_str(it['branchName'])}',
                    style: TextStyle(color: c.muted, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _detailsSection(c),
          if (!widget.additional) ...[
            _sectionTitle('Repossessed Assets', c),
            const SizedBox(height: 4),
            Text(
                'Each box has its own Upload button. Use + Add More on a category to add another box of the same type.',
                style: TextStyle(color: c.muted, fontSize: 11.5)),
            const SizedBox(height: 14),
          ],
          _group(c, 'Repossessed Assets Photos', 'images', _photoCats,
              Icons.photo_rounded, _blue, 'image'),
          _group(c, 'Repossessed Assets Videos', 'videos', _videoCats,
              Icons.videocam_rounded, const Color(0xff6610F2), 'video'),
          _group(c, 'Pre/Post Inventory & Bills', 'pdfs', _pdfCats,
              Icons.picture_as_pdf_rounded, const Color(0xffD00F1F), 'PDF'),
          const SizedBox(height: 8),
          if (!widget.additional) _yardSection(c),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : Text(
                  widget.additional
                      ? 'Upload additional files'
                      : 'Submit inventory',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(_C c, String title, String kind, List<List<String>> cats,
      IconData icon, Color color, String noun) {
    final slots = _slots[kind]!;
    final left = _cap(kind) - _selected(kind);
    final savedTxt = widget.additional ? ' · ${_saved(kind)} saved' : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title, c),
          const SizedBox(height: 2),
          Text('${_selected(kind)} selected$savedTxt · $left $noun slots left',
              style: TextStyle(color: c.muted, fontSize: 11.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(slots.length, (i) {
              final s = slots[i];
              final n = slots
                  .sublist(0, i + 1)
                  .where((e) => e.category == s.category)
                  .length;
              return Container(
                width: 158,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${s.label} #$n',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.text,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _pick(kind, s),
                      icon: Icon(icon, size: 15),
                      label: Text(s.path == null ? 'Upload' : 'Change',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                              s.path == null ? 'No file selected' : s.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: s.path == null ? c.muted : c.text,
                                  fontSize: 11)),
                        ),
                        if (s.path != null)
                          GestureDetector(
                            onTap: () => setState(() => s.path = null),
                            child: Icon(Icons.close_rounded,
                                size: 15, color: c.muted),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton(
                      onPressed: () => _addMore(kind, s),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _blue,
                        backgroundColor: _blue.withOpacity(.06),
                        side: BorderSide(color: _blue.withOpacity(.3)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('+ Add More ${s.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10.5, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  InputDecoration _deco(_C c, String hint) => InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: c.card,
    hintStyle: TextStyle(color: c.muted, fontSize: 13),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border)),
  );

  Widget _yardSection(_C c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('All India Parking Yard', c),
        const SizedBox(height: 2),
        Text(
            'Search and select a parking yard, or enter the yard name manually, before submitting inventory.',
            style: TextStyle(color: c.muted, fontSize: 11.5)),
        const SizedBox(height: 10),
        TextField(
          controller: _yardSearchCtrl,
          onChanged: _onYardSearch,
          style: TextStyle(color: c.text, fontSize: 14),
          decoration: _deco(c, 'Search Parking Yard by Name, Area or Pincode')
              .copyWith(
            suffixIcon: _searchingYard
                ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
                : null,
          ),
        ),
        ..._yardResults.take(6).map((y) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(y['name'] ?? '',
              style: TextStyle(
                  color: c.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          subtitle: Text(
              [y['area'], y['pincode']]
                  .where((e) => (e ?? '').isNotEmpty)
                  .join(' • '),
              style: TextStyle(color: c.muted, fontSize: 11.5)),
          onTap: () => setState(() {
            _yard = y;
            _yardResults = [];
            _yardSearchCtrl.clear();
          }),
        )),
        const SizedBox(height: 8),
        if (_yard == null)
          Text('No parking yard selected',
              style: TextStyle(color: c.muted, fontSize: 12))
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.dark ? const Color(0xff1B2140) : const Color(0xffE8EBFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_parking_rounded, color: _blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_yard!['name'] ?? '',
                          style: TextStyle(
                              color: c.text,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800)),
                      Text(
                          [_yard!['address'], _yard!['area'], _yard!['pincode']]
                              .where((e) => (e ?? '').isNotEmpty)
                              .join(', '),
                          style: TextStyle(color: c.muted, fontSize: 11.5)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() => _yard = null),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        if (!_manual)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _manual = true),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add parking yard manually'),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('ADD PARKING YARD MANUALLY',
                    style: TextStyle(
                        color: Color(0xff3730A3),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5)),
                const SizedBox(height: 10),
                TextField(
                    controller: _mName,
                    decoration:
                    _deco(c, 'Parking Yard Name (e.g. Ram Parking Yard)')),
                const SizedBox(height: 8),
                TextField(
                    controller: _mAddress, decoration: _deco(c, 'Address')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: _mArea, decoration: _deco(c, 'Area'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: _mPin,
                            keyboardType: TextInputType.number,
                            decoration: _deco(c, 'Pincode'))),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                    controller: _mPhone,
                    keyboardType: TextInputType.phone,
                    decoration: _deco(c, 'Phone')),
                if (_manualError != null) ...[
                  const SizedBox(height: 6),
                  Text(_manualError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _addManualYard,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white),
                      child: const Text('Add'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() {
                        _manual = false;
                        _manualError = null;
                      }),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}