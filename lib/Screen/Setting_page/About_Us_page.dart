import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// About Us screen.
/// Settings page ke saath same folder mein rakho.
///
/// Logo assets (RefundPolicyPage wale hi):
///   assets/images/fastrecovery_logo_light.png
///   assets/images/fastrecovery_logo_dark.png
class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  static const _logoLight = 'assets/images/fastrecovery_logo_light.png';
  static const _logoDark = 'assets/images/fastrecovery_logo_dark.png';

  static const _company = 'Software Solutions Development India';
  static const _founder = 'Ashwani Kumar';
  static const _phones = ['+91 8796814100', '+91 8796824100'];
  static const _website = 'www.fastrecovery.in';
  static const _emails = ['fastrecovery26@gmail.com', 'admin@ssdi.co.in'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = _Palette.of(context);

    return Scaffold(
      backgroundColor: p.scaffold,
      appBar: AppBar(
        backgroundColor: p.card,
        elevation: 0.5,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: p.primary),
        centerTitle: false,
        title: Text(
          'About Us',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800, color: p.primary),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            // _Header(p: p, logo: p.dark ? _logoDark : _logoLight),
            Image.asset(
              isDark
                  ? 'assets/images/fastrecovery_logo_2dark.png'
                  : 'assets/images/fastrecovery_logo-2.png',
              width: 125,
              height: 38,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
            ),
            const SizedBox(height: 14),
            _SectionCard(
              p: p,
              icon: Icons.apartment_rounded,
              color: const Color(0xff2563EB),
              title: 'Who We Are',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Body(
                    p: p,
                    text: 'Software Solutions Development India (SSDI) is the '
                        'company behind Fast Recovery — a platform designed '
                        'specifically for India\'s loan legal repossession '
                        'industry.',
                  ),
                  const SizedBox(height: 12),
                  _Body(
                    p: p,
                    text: 'We build technology that connects banks, legal '
                        'repossession agencies, and field tracers in a '
                        'single, secure ecosystem — reducing paperwork, '
                        'improving visibility, and speeding up the legal '
                        'recovery process.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              p: p,
              icon: Icons.flag_rounded,
              color: const Color(0xffF59E0B),
              title: 'Our Mission',
              child: _Body(
                p: p,
                text: 'To digitise and streamline loan legal recovery '
                    'operations across India — giving every party in the '
                    'chain real-time information, accountability, and '
                    'control.',
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              p: p,
              icon: Icons.support_agent_rounded,
              color: const Color(0xff16A34A),
              title: 'Contact',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    p: p,
                    icon: Icons.business_rounded,
                    label: 'Company Name',
                    value: _company,
                  ),
                  _InfoRow(
                    p: p,
                    icon: Icons.person_outline_rounded,
                    label: 'Founder Name',
                    value: _founder,
                  ),
                  for (final ph in _phones)
                    _InfoRow(
                      p: p,
                      icon: Icons.call_outlined,
                      label: 'Phone',
                      value: ph,
                      uri: Uri(scheme: 'tel', path: ph.replaceAll(' ', '')),
                    ),
                  _InfoRow(
                    p: p,
                    icon: Icons.language_rounded,
                    label: 'Website',
                    value: _website,
                    uri: Uri.parse('https://$_website'),
                  ),
                  for (var i = 0; i < _emails.length; i++)
                    _InfoRow(
                      p: p,
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      value: _emails[i],
                      uri: Uri(scheme: 'mailto', path: _emails[i]),
                      isLast: i == _emails.length - 1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '© ${DateTime.now().year} $_company',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: p.secondary.withOpacity(.8),
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
//  Palette (Settings page ke colors se match)
// ═════════════════════════════════════════════════════════════════════════════

class _Palette {
  final bool dark;
  const _Palette._(this.dark);

  factory _Palette.of(BuildContext context) =>
      _Palette._(Theme.of(context).brightness == Brightness.dark);

  Color get scaffold => dark ? const Color(0xff0B1220) : const Color(0xffF8FAFC);
  Color get card => dark ? const Color(0xff111827) : Colors.white;
  Color get divider => dark ? const Color(0xff334155) : const Color(0xffE2E8F0);
  Color get primary => dark ? Colors.white : const Color(0xff0F172A);
  Color get secondary =>
      dark ? const Color(0xff8A97B0) : const Color(0xff64748B);
  Color get link => dark ? const Color(0xff7EA2FF) : const Color(0xff1F4FD8);
}

BoxDecoration _cardDecoration(_Palette p) => BoxDecoration(
  color: p.card,
  borderRadius: BorderRadius.circular(15),
  border: Border.all(color: p.divider),
);

// ═════════════════════════════════════════════════════════════════════════════
//  Widgets
// ═════════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final _Palette p;
  final String logo;
  const _Header({required this.p, required this.logo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: _cardDecoration(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            logo,
            height: 34,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            semanticLabel: 'FastRecovery logo',
            errorBuilder: (_, __, ___) => Text(
              'FastRecovery',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: p.primary),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'About Us',
            style: TextStyle(
              fontSize: 21,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: p.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Software Solutions Development India (SSDI)',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: p.secondary),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final _Palette p;
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.p,
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(p.dark ? .14 : .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: p.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final _Palette p;
  final String text;
  const _Body({required this.p, required this.text});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 13.5, height: 1.65, color: p.primary),
  );
}

/// Contact ki ek row. `uri` do to tap par open hoga.
class _InfoRow extends StatelessWidget {
  final _Palette p;
  final IconData icon;
  final String label;
  final String value;
  final Uri? uri;
  final bool isLast;

  const _InfoRow({
    required this.p,
    required this.icon,
    required this.label,
    required this.value,
    this.uri,
    this.isLast = false,
  });

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onTap(BuildContext context) async {
    try {
      final ok = await launchUrl(uri!, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) _toast(context, 'Could not open link');
    } catch (_) {
      if (context.mounted) _toast(context, 'Could not open link');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: uri != null ? () => _onTap(context) : null,
        onLongPress: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (context.mounted) _toast(context, '$label copied');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 18, color: p.secondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: p.secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: uri != null ? p.link : p.primary,
                        fontWeight:
                        uri != null ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}