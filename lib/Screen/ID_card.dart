import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Profile_page.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  1. CONFIG
// ═════════════════════════════════════════════════════════════════════════════

abstract final class _Api {
  /// login jis host par hota hai wahi use karo (www ke saath ya bina).
  static const baseUrl = 'https://www.fastrecovery.in';
  static const idCardUrl = '$baseUrl/api/Auth/id-card-data';
  static const timeout = Duration(seconds: 20);

  /// login screen jis key mein token save karti hai (pehla non-empty milega).
  static const tokenKeys = [
    'authToken',
    'token',
    'access_token',
    'accessToken',
    'jwt',
    'userToken',
    'auth_token',
  ];

  /// "/api/files/x.jpg" -> "https://host/api/files/x.jpg"
  static String absolute(String path) {
    if (path.startsWith('http')) return path;
    return '$baseUrl${path.startsWith('/') ? '' : '/'}$path';
  }
}

/// Card ke fixed texts (API se nahi aate).
abstract final class _CardText {
  static const tagline = 'AUTHORISED VEHICLE REPOSSESSION AGENCY';
  static const subtitle = 'Bank / NBFC';
}

/// ID card ke colors. Card physical ID jaisa hai, isliye dark/light dono
/// theme mein same rehta hai.
abstract final class _Ink {
  static const navy = Color(0xff152B4D);
  static const text = Color(0xff0F172A);
  static const label = Color(0xff475569);
  static const border = Color(0xffD5DCE8);
  static const footer = Color(0xffF3F6FA);
  static const accent = Color(0xff1D4ED8);
  static const placeholder = Color(0xff94A3B8);
}

// ═════════════════════════════════════════════════════════════════════════════
//  2. MODELS
// ═════════════════════════════════════════════════════════════════════════════

String _str(dynamic v) {
  final s = v?.toString().trim() ?? '';
  return s == 'null' ? '' : s;
}

class IdCardCompany {
  final String name;
  final String code;
  final String phone;
  final String photoUrl;

  const IdCardCompany({
    required this.name,
    required this.code,
    required this.phone,
    required this.photoUrl,
  });

  factory IdCardCompany.fromJson(Map<String, dynamic> j) {
    final phone = _str(j['phone']);
    return IdCardCompany(
      name: _str(j['companyName']),
      code: _str(j['companyCode']),
      phone: phone.isNotEmpty ? phone : _str(j['firstAgencyNumber']),
      photoUrl: _str(j['photoUrl']),
    );
  }
}

class IdCardUser {
  final String id;
  final String name;
  final String phone;
  final String dateOfBirth;
  final String post;
  final String pincode;
  final String photoUrl;
  final IdCardCompany company;

  const IdCardUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.dateOfBirth,
    required this.post,
    required this.pincode,
    required this.photoUrl,
    required this.company,
  });

  factory IdCardUser.fromJson(Map<String, dynamic> j) {
    final company = j['company'];
    return IdCardUser(
      id: _str(j['id']),
      name: _str(j['name']),
      phone: _str(j['phone']),
      dateOfBirth: _str(j['dateOfBirth']),
      post: _str(j['post']),
      pincode: _str(j['pincode']),
      photoUrl: _str(j['photoUrl']),
      company: IdCardCompany.fromJson(
        company is Map ? Map<String, dynamic>.from(company) : const {},
      ),
    );
  }

  /// "1982-02-07" -> "07/02/1982"
  String get dobLabel {
    final d = DateTime.tryParse(dateOfBirth);
    if (d == null) return dateOfBirth;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  3. SERVICE
// ═════════════════════════════════════════════════════════════════════════════

class IdCardException implements Exception {
  final String message;
  const IdCardException(this.message);

  @override
  String toString() => message;
}

class IdCardService {
  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _Api.tokenKeys) {
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) return value;
    }
    debugPrint('ID CARD: token not found. Saved keys: ${prefs.getKeys()}');
    return null;
  }

  Future<IdCardUser> fetchUser(String token) async {
    final http.Response res;
    try {
      res = await http.get(
        Uri.parse(_Api.idCardUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_Api.timeout);
    } on TimeoutException {
      throw const IdCardException('Request timed out. Please try again.');
    } on http.ClientException {
      throw const IdCardException('No internet connection.');
    }

    Map<String, dynamic> body = const {};
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {/* non-JSON response */}

    final message = _str(body['message']);

    if (res.statusCode == 200 && body['success'] == true) {
      final user = (body['data'] as Map?)?['user'];
      if (user is Map) {
        return IdCardUser.fromJson(Map<String, dynamic>.from(user));
      }
      throw const IdCardException('ID card data is missing.');
    }
    if (res.statusCode == 401) {
      throw IdCardException(
        message.isEmpty ? 'Session expired. Please login again.' : message,
      );
    }
    throw IdCardException(
      message.isEmpty ? 'Unable to load ID card.' : message,
    );
  }

  /// Image ko token ke saath download karta hai. Fail hone par null.
  Future<Uint8List?> fetchImage(String path, String token) async {
    if (path.isEmpty) return null;
    final url = _Api.absolute(path);
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(_Api.timeout);

      final type = res.headers['content-type'] ?? '';
      final looksLikeImage = !type.contains('html') && !type.contains('json');

      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty && looksLikeImage) {
        return res.bodyBytes;
      }
      debugPrint('ID CARD IMAGE FAILED: ${res.statusCode} $type <- $url');
    } catch (e) {
      debugPrint('ID CARD IMAGE ERROR: $e <- $url');
    }
    return null;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  4. PAGE THEME (sirf page / buttons, card nahi)
// ═════════════════════════════════════════════════════════════════════════════

class _Palette {
  final bool dark;
  const _Palette._(this.dark);

  factory _Palette.of(BuildContext context) =>
      _Palette._(Theme.of(context).brightness == Brightness.dark);

  Color get scaffold => dark ? const Color(0xff0A0F1C) : const Color(0xffF4F6FA);
  Color get title => dark ? Colors.white : const Color(0xff0F172A);
  Color get muted => dark ? const Color(0xff8B98B3) : const Color(0xff64748B);
  Color get grayButton =>
      dark ? const Color(0xff1E293B) : const Color(0xffE2E5EA);
}

// ═════════════════════════════════════════════════════════════════════════════
//  5. PAGE
// ═════════════════════════════════════════════════════════════════════════════

class IdCardPage extends StatefulWidget {
  const IdCardPage({super.key});

  @override
  State<IdCardPage> createState() => _IdCardPageState();
}

class _IdCardPageState extends State<IdCardPage> {
  final _service = IdCardService();

  IdCardUser? _user;
  Uint8List? _photo;
  Uint8List? _logo;

  bool _loading = true;
  bool _busy = false; // PDF banate waqt
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _service.readToken();
      if (token == null) {
        throw const IdCardException('You are not logged in. Please login again.');
      }

      final user = await _service.fetchUser(token);
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });

      // Card turant dikh jaye; images baad mein aa jayengi.
      final images = await Future.wait([
        _service.fetchImage(user.photoUrl, token),
        _service.fetchImage(user.company.photoUrl, token),
      ]);
      if (!mounted) return;
      setState(() {
        _photo = images[0];
        _logo = images[1];
      });
    } on IdCardException catch (e) {
      _fail(e.message);
    } catch (e) {
      debugPrint('ID CARD ERROR: $e');
      _fail('Something went wrong. Please try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _withPdf(
      Future<void> Function(Uint8List bytes, IdCardUser user) action,
      String failMessage,
      ) async {
    final user = _user;
    if (user == null || _busy) return;

    setState(() => _busy = true);
    try {
      final bytes = await _IdCardPdf.build(user, photo: _photo, logo: _logo);
      await action(bytes, user);
    } catch (e, st) {
      debugPrint('ID CARD PDF ERROR: $e\n$st');
      _snack(failMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadPdf() => _withPdf(
        (bytes, user) => Printing.sharePdf(
      bytes: bytes,
      filename: 'id_card_${user.id}.pdf',
    ),
    'PDF download failed. Try again.',
  );

  Future<void> _printCard() => _withPdf(
        (bytes, user) => Printing.layoutPdf(
      name: 'ID Card ${user.name}',
      onLayout: (_) async => bytes,
    ),
    'Print failed. Try again.',
  );

  Future<void> _editProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    if (mounted) _load(); // profile badla ho to card refresh ho
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);

    return Scaffold(
      backgroundColor: p.scaffold,
      appBar: AppBar(
        title: Text(
          'ID Card',
          style: TextStyle(fontWeight: FontWeight.w700, color: p.title),
        ),
        centerTitle: false,
        backgroundColor: p.scaffold,
        foregroundColor: p.title,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _Ink.accent, strokeWidth: 2.6),
      );
    }

    final user = _user;
    if (_error != null || user == null) {
      return _ErrorState(
        message: _error ?? 'Unable to load ID card.',
        onRetry: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _Ink.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                _ActionsBar(
                  busy: _busy,
                  onEdit: _editProfile,
                  onPrint: _printCard,
                  onDownload: _downloadPdf,
                ),
                const SizedBox(height: 20),
                _IdCardPair(user: user, photo: _photo, logo: _logo),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  6. ACTION BUTTONS
// ═════════════════════════════════════════════════════════════════════════════

class _ActionsBar extends StatelessWidget {
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onPrint;
  final VoidCallback onDownload;

  const _ActionsBar({
    required this.busy,
    required this.onEdit,
    required this.onPrint,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.edit_outlined,
              label: 'Edit',
              background: p.grayButton,
              foreground: p.title,
              onTap: onEdit,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              icon: Icons.print_outlined,
              label: 'Print',
              background: p.grayButton,
              foreground: p.title,
              loading: busy,
              onTap: busy ? null : onPrint,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              icon: Icons.file_download_outlined,
              label: 'Download',
              background: _Ink.accent,
              foreground: Colors.white,
              loading: busy,
              onTap: busy ? null : onDownload,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withOpacity(.6),
          disabledForegroundColor: foreground.withOpacity(.7),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            else
              Icon(icon, size: 16),
            const SizedBox(width: 7),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  7. ID CARD (front + back)
// ═════════════════════════════════════════════════════════════════════════════

/// Wide screen par side-by-side, phone par ek ke neeche ek.
class _IdCardPair extends StatelessWidget {
  final IdCardUser user;
  final Uint8List? photo;
  final Uint8List? logo;

  const _IdCardPair({required this.user, this.photo, this.logo});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final front = _FrontCard(user: user, photo: photo);
        final back = _BackCard(logo: logo);

        if (constraints.maxWidth >= 720) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: front),
                const SizedBox(width: 24),
                Expanded(child: back),
              ],
            ),
          );
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              front,
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 240),
                child: back,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;

  const _CardShell({required this.child, this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Ink.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _FrontCard extends StatelessWidget {
  final IdCardUser user;
  final Uint8List? photo;

  const _FrontCard({required this.user, this.photo});

  @override
  Widget build(BuildContext context) {
    final company = user.company;

    return _CardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            color: _Ink.navy,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company.name.isEmpty ? 'Company' : company.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                if (company.code.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    company.code,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.80),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Photo + details
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Photo(bytes: photo),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isEmpty ? 'Employee' : user.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _Ink.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(label: 'Post', value: user.post),
                      const SizedBox(height: 7),
                      _InfoRow(label: 'Date of birth', value: user.dobLabel),
                      const SizedBox(height: 7),
                      _InfoRow(label: 'Pincode', value: user.pincode),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Footer
          Container(
            decoration: const BoxDecoration(
              color: _Ink.footer,
              border: Border(top: BorderSide(color: _Ink.border)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FooterRow(
                  icon: Icons.apartment_rounded,
                  label: 'Office:',
                  value: company.phone,
                ),
                const SizedBox(height: 9),
                _FooterRow(
                  icon: Icons.smartphone_rounded,
                  label: 'Mobile:',
                  value: user.phone,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  final Uint8List? bytes;
  const _Photo({this.bytes});

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: Color(0xffE2E8F0),
      child: Center(
        child: Icon(Icons.person_rounded, size: 46, color: _Ink.placeholder),
      ),
    );

    return Container(
      width: 96,
      height: 124,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _Ink.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? placeholder
          : Image.memory(
        bytes!,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(color: _Ink.label, fontSize: 12.5),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              color: _Ink.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _FooterRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _FooterRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _Ink.label),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: _Ink.label, fontSize: 13.5)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _Ink.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _BackCard extends StatelessWidget {
  final Uint8List? logo;
  const _BackCard({this.logo});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color(0xffEEF2F7)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoundLogo(bytes: logo),
              const SizedBox(height: 22),
              const Text(
                _CardText.tagline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _Ink.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .3,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                _CardText.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _Ink.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundLogo extends StatelessWidget {
  final Uint8List? bytes;
  const _RoundLogo({this.bytes});

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(Icons.business_rounded, size: 34, color: _Ink.navy);

    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _Ink.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: ClipOval(
        child: bytes == null
            ? fallback
            : Image.memory(
          bytes!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  8. ERROR STATE
// ═════════════════════════════════════════════════════════════════════════════

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xffEF4444).withOpacity(.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 34,
                color: Color(0xffEF4444),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: p.title,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _Ink.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  9. PDF (front + back, A4 par ek ke neeche ek)
//  Note: default PDF font Unicode (jaise Hindi) support nahi karta.
// ═════════════════════════════════════════════════════════════════════════════

abstract final class _IdCardPdf {
  static const _cardWidth = 400.0;
  static final _navy = PdfColor.fromInt(0xff152B4D);
  static final _text = PdfColor.fromInt(0xff0F172A);
  static final _label = PdfColor.fromInt(0xff475569);
  static final _border = PdfColor.fromInt(0xffD5DCE8);
  static final _footer = PdfColor.fromInt(0xffF3F6FA);

  static pw.MemoryImage? _image(Uint8List? bytes) {
    if (bytes == null) return null;
    try {
      return pw.MemoryImage(bytes); // sirf JPG / PNG supported
    } catch (e) {
      debugPrint('PDF: unsupported image -> $e');
      return null;
    }
  }

  static Future<Uint8List> build(
      IdCardUser user, {
        Uint8List? photo,
        Uint8List? logo,
      }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              _front(user, _image(photo)),
              pw.SizedBox(height: 28),
              _back(_image(logo)),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }

  static pw.BoxDecoration _cardBox({PdfColor? color}) => pw.BoxDecoration(
    color: color ?? PdfColors.white,
    border: pw.Border.all(color: _border, width: 1),
    borderRadius: pw.BorderRadius.circular(10),
  );

  static pw.Widget _front(IdCardUser u, pw.MemoryImage? photo) {
    String v(String s) => s.isEmpty ? '-' : s;

    return pw.Container(
      width: _cardWidth,
      decoration: _cardBox(),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.fromLTRB(20, 16, 20, 14),
            decoration: pw.BoxDecoration(
              color: _navy,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(10),
                topRight: pw.Radius.circular(10),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  u.company.name.isEmpty ? 'Company' : u.company.name,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (u.company.code.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    u.company.code,
                    style: const pw.TextStyle(
                      color: PdfColors.grey300,
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Photo + details
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 90,
                  height: 116,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _border),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: photo != null
                      ? pw.ClipRRect(
                    horizontalRadius: 4,
                    verticalRadius: 4,
                    child: pw.Image(photo, fit: pw.BoxFit.cover),
                  )
                      : pw.Center(
                    child: pw.Text(
                      'No Photo',
                      style: pw.TextStyle(fontSize: 9, color: _label),
                    ),
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        u.name.isEmpty ? 'Employee' : u.name,
                        style: pw.TextStyle(
                          fontSize: 19,
                          fontWeight: pw.FontWeight.bold,
                          color: _text,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      _row('Post', v(u.post)),
                      _row('Date of birth', v(u.dobLabel)),
                      _row('Pincode', v(u.pincode)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Footer (top line alag se, kyunki pdf package mein non-uniform
          // border ke saath borderRadius allowed nahi hai)
          pw.Container(width: double.infinity, height: 1, color: _border),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: pw.BoxDecoration(
              color: _footer,
              borderRadius: const pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(10),
                bottomRight: pw.Radius.circular(10),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _footerRow('Office:', v(u.company.phone)),
                pw.SizedBox(height: 6),
                _footerRow('Mobile:', v(u.phone)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _row(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 78,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: _label),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: _text,
            ),
          ),
        ),
      ],
    ),
  );

  static pw.Widget _footerRow(String label, String value) => pw.Row(
    children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 10.5, color: _label)),
      pw.SizedBox(width: 6),
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: _text,
        ),
      ),
    ],
  );

  static pw.Widget _back(pw.MemoryImage? logo) {
    return pw.Container(
      width: _cardWidth,
      height: 230,
      decoration: _cardBox(color: PdfColor.fromInt(0xffF8FAFC)),
      child: pw.Center(
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Container(
              width: 70,
              height: 70,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                shape: pw.BoxShape.circle,
                border: pw.Border.all(color: _border, width: 1.2),
              ),
              child: logo != null
                  ? pw.ClipOval(child: pw.Image(logo, fit: pw.BoxFit.contain))
                  : pw.SizedBox(),
            ),
            pw.SizedBox(height: 18),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 30),
              child: pw.Text(
                _CardText.tagline,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _text,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              _CardText.subtitle,
              style: pw.TextStyle(fontSize: 14, color: _navy),
            ),
          ],
        ),
      ),
    );
  }
}