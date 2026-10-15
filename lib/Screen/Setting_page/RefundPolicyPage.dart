import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Refund and Cancellation Policy screen.
/// Settings page ke saath same folder mein rakho.
///
/// pubspec.yaml mein ye assets add karna zaroori hai:
///   flutter:
///     assets:
///       - assets/images/fastrecovery_logo_light.png
///       - assets/images/fastrecovery_logo_dark.png
class RefundPolicyPage extends StatelessWidget {
  const RefundPolicyPage({super.key});

  static const _logoLight = 'assets/images/fastrecovery_logo_light.png';
  static const _logoDark = 'assets/images/fastrecovery_logo_dark.png';

  static const _company = 'Software Solutions Development India';
  static const _founder = 'Ashwani Kumar';
  static const _emails = ['fastrecovery26@gmail.com', 'admin@ssdi.co.in'];
  static const _phones = ['+91 8796814100', '+91 8796824100'];
  static const _address =
      'P 155/A Gali, Plot No. Q 52, S/F, KH No. 18/8, Gali No. 5, Phase-4, '
      'Shiv Vihar, Karawal Nagar, Near Rathor Dharamshala, Delhi – 110094';

  @override
  Widget build(BuildContext context) {
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
          'Refund Policy',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800, color: p.primary),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _Header(p: p, logo: p.dark ? _logoDark : _logoLight),
            const SizedBox(height: 14),
            _Highlights(p: p),
            const SizedBox(height: 14),
            _SectionCard(
              p: p,
              icon: Icons.receipt_long_rounded,
              color: const Color(0xffF59E0B),
              title: 'Refund and Cancellation Policy',
              child: _Body(
                p: p,
                text: 'We do not provide any return or refund of the '
                    'purchased SaaS product. In case of extreme situation or '
                    'request dispute, the refund will be credited to the '
                    'client\'s account between 5 to 7 days.',
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              p: p,
              icon: Icons.payments_rounded,
              color: const Color(0xff2563EB),
              title: 'Payment Flow',
              child: _Body(
                p: p,
                text: 'Our website is integrated with the Razorpay payment '
                    'gateway, through which clients can make their monthly '
                    'payment subscription through the website itself. There '
                    'are different payment methods provided for consumers, '
                    'including payment through Debit card, UPI, Net banking, '
                    'and others.',
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              p: p,
              icon: Icons.support_agent_rounded,
              color: const Color(0xff16A34A),
              title: 'Contact Us',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Body(
                    p: p,
                    text: 'If you have any questions about this policy, you '
                        'can contact us:',
                  ),
                  const SizedBox(height: 14),
                  _InfoRow(
                    p: p,
                    icon: Icons.business_rounded,
                    label: 'Company Name',
                    value: '$_company (FastRecovery App/Web)',
                  ),
                  _InfoRow(
                    p: p,
                    icon: Icons.person_outline_rounded,
                    label: 'Founder Name',
                    value: _founder,
                  ),
                  for (final e in _emails)
                    _InfoRow(
                      p: p,
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      value: e,
                      uri: Uri(scheme: 'mailto', path: e),
                    ),
                  for (final ph in _phones)
                    _InfoRow(
                      p: p,
                      icon: Icons.call_outlined,
                      label: 'Phone number',
                      value: ph,
                      uri: Uri(scheme: 'tel', path: ph.replaceAll(' ', '')),
                    ),
                  _InfoRow(
                    p: p,
                    icon: Icons.location_on_outlined,
                    label: 'Address',
                    value: _address,
                    copyOnTap: true,
                    isLast: true,
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

// ═════════════════════════════════════════════════════════════════════════════
//  Widgets
// ═════════════════════════════════════════════════════════════════════════════

BoxDecoration _cardDecoration(_Palette p) => BoxDecoration(
  color: p.card,
  borderRadius: BorderRadius.circular(15),
  border: Border.all(color: p.divider),
);

class _Header extends StatelessWidget {
  final _Palette p;
  final String logo;
  const _Header({required this.p, required this.logo});

  @override
  Widget build(BuildContext context,) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: _cardDecoration(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            isDark
                ? 'assets/images/fastrecovery_logo_2dark.png'
                : 'assets/images/fastrecovery_logo-2.png',
            width: 125,
            height: 38,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
          ),
          // Image.asset(
          //   logo,
          //   height: 34,
          //   fit: BoxFit.contain,
          //   alignment: Alignment.centerLeft,
          //   semanticLabel: 'FastRecovery logo',
          //   errorBuilder: (_, __, ___) => Text(
          //     'FastRecovery',
          //     style: TextStyle(
          //         fontSize: 24, fontWeight: FontWeight.w900, color: p.primary),
          //   ),
          // ),
          const SizedBox(height: 18),
          Text(
            'Refund and Cancellation Policy',
            style: TextStyle(
              fontSize: 21,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: p.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'FastRecovery App/Web (Software Solutions Development India)',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: p.secondary),
          ),
        ],
      ),
    );
  }
}

/// Policy ka quick summary (sirf wahi jo policy mein likha hai).
class _Highlights extends StatelessWidget {
  final _Palette p;
  const _Highlights({required this.p});

  @override
  Widget build(BuildContext context) {
    final items = const [
      (Icons.block_rounded, Color(0xffDC2626), 'No refund on purchased SaaS product'),
      (Icons.schedule_rounded, Color(0xffF59E0B), 'Extreme cases or disputes: refund in 5 to 7 days'),
      (Icons.lock_outline_rounded, Color(0xff2563EB), 'Payments processed via Razorpay'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: _cardDecoration(p),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  _IconBadge(p: p, icon: items[i].$1, color: items[i].$2, size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      items[i].$3,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: p.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i != items.length - 1) Divider(height: 1, color: p.divider),
          ],
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
              _IconBadge(p: p, icon: icon, color: color),
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

class _IconBadge extends StatelessWidget {
  final _Palette p;
  final IconData icon;
  final Color color;
  final double size;

  const _IconBadge({
    required this.p,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(p.dark ? .14 : .10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: size * .48, color: color),
    );
  }
}

/// Contact detail ki ek row. `uri` do to tap par open hoga,
/// `copyOnTap` do to tap par clipboard mein copy hoga.
class _InfoRow extends StatelessWidget {
  final _Palette p;
  final IconData icon;
  final String label;
  final String value;
  final Uri? uri;
  final bool copyOnTap;
  final bool isLast;

  const _InfoRow({
    required this.p,
    required this.icon,
    required this.label,
    required this.value,
    this.uri,
    this.copyOnTap = false,
    this.isLast = false,
  });

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onTap(BuildContext context) async {
    if (uri != null) {
      try {
        final ok = await launchUrl(uri!);
        if (!ok && context.mounted) _toast(context, 'Could not open link');
      } catch (_) {
        if (context.mounted) _toast(context, 'Could not open link');
      }
    } else if (copyOnTap) {
      await Clipboard.setData(ClipboardData(text: value));
      if (context.mounted) _toast(context, '$label copied');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tappable = uri != null || copyOnTap;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: tappable ? () => _onTap(context) : null,
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