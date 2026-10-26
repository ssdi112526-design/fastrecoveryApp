import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/login/login_page.dart';

class ContactSupportPage extends StatelessWidget {
  const ContactSupportPage({super.key});

  // =========================================================
  // CONTACT DATA  — keep this 100% accurate (Google checks it)
  // =========================================================
  static const String _appName = 'FastRecovery';
  static const String _companyName = 'Software Solutions Development India';

  static const String _address =
      'P 155/A Gali, Plot No. Q 52, S/F, KH No. 18/8, Gali No. 5, Phase-4, '
      'Shiv Vihar, Karawal Nagar, Near Rathor Dharamshala, Delhi – 110094';

  static const List<String> _phones = ['+918796814100', '+918796824100'];
  static const List<String> _phoneLabels = ['+91 8796814100', '+91 8796824100'];

  static const List<String> _emails = [
    'fastrecovery26@gmail.com',
    'admin@ssdi.co.in',
  ];

  static const String _website = 'https://www.ssdi.co.in/';
  static const String _websiteLabel = 'www.ssdi.co.in';

  // TODO: apni REAL support timing daalo. Khali ('') chhodoge to card hide ho jayega.
  static const String _supportHours = '';

  // TODO: apne live Privacy Policy / Terms page ka URL daalo.
  // Khali ('') chhodoge to link hide ho jayega.
  static const String _privacyUrl = '';
  static const String _termsUrl = '';

  static const String _logoLight = 'assets/images/fastrecovery_logo-2.png';
  static const String _logoDark = 'assets/images/fastrecovery_logo_2dark.png';

  static const Color _primary = Color(0xff1D4ED8);

  // =========================================================
  // ACTIONS
  // =========================================================
  Future<void> _open(BuildContext context, Uri uri, String errorMsg) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) _snack(context, errorMsg);
    } catch (_) {
      if (context.mounted) _snack(context, errorMsg);
    }
  }

  void _call(BuildContext c, String phone) =>
      _open(c, Uri.parse('tel:$phone'), 'Could not open dialer');

  void _mail(BuildContext c, String email) => _open(
    c,
    Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': '$_appName Support'},
    ),
    'Could not open email app',
  );

  void _web(BuildContext c, [String url = _website]) =>
      _open(c, Uri.parse(url), 'Could not open link');

  void _map(BuildContext c) => _open(
    c,
    Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_address)}',
    ),
    'Could not open maps',
  );

  Future<void> _copy(BuildContext c, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (c.mounted) _snack(c, 'Copied to clipboard');
  }

  void _snack(BuildContext c, String msg) {
    ScaffoldMessenger.of(c)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _backToLogin(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // =========================================================
  // BUILD
  // =========================================================
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
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _backToLogin(context),
        ),
        title: Text(
          'Contact Us',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: p.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _intro(p),
                const SizedBox(height: 14),
                _quickActions(context, p),

                const _SectionLabel('Contact details'),
                _contactDetailsCard(context, p),

                if (_supportHours.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _hoursCard(p),
                ],

                const _SectionLabel('Meet our team'),
                _pair(
                  _teamCard(p, 'AK', 'Mr Ashwani Kumar', 'Founder'),
                  _teamCard(p, 'A', 'Mrs Anju', 'Co-Founder'),
                ),

                const _SectionLabel('Developed & operated by'),
                _aboutCard(context, p),

                _legalLinks(context),

                const SizedBox(height: 20),
                Center(
                  child: Text(
                    '© ${DateTime.now().year} $_companyName. All rights reserved.',
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
        ),
      ),
    );
  }

  // =========================================================
  // INTRO (logo + heading)
  // =========================================================
  Widget _intro(_Palette p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: p.card_(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            p.dark ? _logoDark : _logoLight,
            height: 34,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            semanticLabel: '$_appName logo',
            errorBuilder: (context, error, stackTrace) => Text(
              _appName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: p.primary,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'How can we help you?',
            style: TextStyle(
              fontSize: 21,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: p.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Reach out to our team for support, queries, or any '
                'assistance with your $_appName account.',
            style: TextStyle(fontSize: 13, height: 1.5, color: p.secondary),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // QUICK ACTIONS  (Call / Email / Website)
  // =========================================================
  Widget _quickActions(BuildContext c, _Palette p) {
    return Row(
      children: [
        Expanded(
          child: _quickAction(
            p: p,
            icon: Icons.phone_rounded,
            label: 'Call',
            color: const Color(0xff059669),
            onTap: () => _call(c, _phones.first),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _quickAction(
            p: p,
            icon: Icons.mail_rounded,
            label: 'Email',
            color: _primary,
            onTap: () => _mail(c, _emails.first),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _quickAction(
            p: p,
            icon: Icons.language_rounded,
            label: 'Website',
            color: const Color(0xffD97706),
            onTap: () => _web(c),
          ),
        ),
      ],
    );
  }

  Widget _quickAction({
    required _Palette p,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: p.cardColor,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: p.divider),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                _IconBadge(p: p, icon: icon, color: color),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: p.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // CONTACT DETAILS
  // =========================================================
  Widget _contactDetailsCard(BuildContext c, _Palette p) {
    final rows = <Widget>[
      for (int i = 0; i < _phones.length; i++)
        _contactRow(
          p: p,
          icon: Icons.phone_outlined,
          label: i == 0 ? 'Phone' : 'Alternate Phone',
          value: _phoneLabels[i],
          onTap: () => _call(c, _phones[i]),
          onCopy: () => _copy(c, _phoneLabels[i]),
        ),
      for (int i = 0; i < _emails.length; i++)
        _contactRow(
          p: p,
          icon: Icons.mail_outline_rounded,
          label: i == 0 ? 'Support Email' : 'Admin Email',
          value: _emails[i],
          onTap: () => _mail(c, _emails[i]),
          onCopy: () => _copy(c, _emails[i]),
        ),
      _contactRow(
        p: p,
        icon: Icons.location_on_outlined,
        label: 'Office Address',
        value: _address,
        onTap: () => _map(c),
        onCopy: () => _copy(c, _address),
        trailingIcon: Icons.map_outlined,
      ),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: p.card_(),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              Divider(height: 1, indent: 66, color: p.divider),
          ],
        ],
      ),
    );
  }

  Widget _contactRow({
    required _Palette p,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required VoidCallback onCopy,
    IconData trailingIcon = Icons.copy_rounded,
  }) {
    final isCopy = trailingIcon == Icons.copy_rounded;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBadge(p: p, icon: icon, color: _primary),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
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
                        fontWeight: FontWeight.w600,
                        color: p.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: isCopy ? 'Copy' : 'Open in Maps',
              onPressed: isCopy ? onCopy : onTap,
              icon: Icon(trailingIcon, size: 18, color: p.secondary),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // SUPPORT HOURS
  // =========================================================
  Widget _hoursCard(_Palette p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: p.card_(),
      child: Row(
        children: [
          _IconBadge(
            p: p,
            icon: Icons.schedule_rounded,
            color: const Color(0xff059669),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Support hours',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: p.secondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _supportHours,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: p.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // TEAM
  // =========================================================
  Widget _pair(Widget a, Widget b) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          const SizedBox(width: 12),
          Expanded(child: b),
        ],
      ),
    );
  }

  Widget _teamCard(_Palette p, String initials, String name, String role) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: p.card_(),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primary.withOpacity(p.dark ? .20 : .10),
            ),
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: p.dark ? const Color(0xff9DB8FF) : _primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: p.primary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            role,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: p.secondary,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ABOUT / DEVELOPED BY
  // =========================================================
  Widget _aboutCard(BuildContext c, _Palette p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: p.card_(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _companyName,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: p.primary,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _web(c),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _websiteLabel,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: p.link,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.open_in_new_rounded, size: 14, color: p.link),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // LEGAL LINKS  (shown only when URLs are filled)
  // =========================================================
  Widget _legalLinks(BuildContext c) {
    final links = <Widget>[
      if (_privacyUrl.isNotEmpty) _legalLink(c, 'Privacy Policy', _privacyUrl),
      if (_termsUrl.isNotEmpty) _legalLink(c, 'Terms & Conditions', _termsUrl),
    ];

    if (links.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          children: links,
        ),
      ),
    );
  }

  Widget _legalLink(BuildContext c, String label, String url) {
    return InkWell(
      onTap: () => _web(c, url),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: _primary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Palette + small widgets (Settings page ke colors se match)
// ═════════════════════════════════════════════════════════════════════════════

class _Palette {
  final bool dark;
  const _Palette._(this.dark);

  factory _Palette.of(BuildContext context) =>
      _Palette._(Theme.of(context).brightness == Brightness.dark);

  Color get scaffold => dark ? const Color(0xff0B1220) : const Color(0xffF8FAFC);
  Color get card => dark ? const Color(0xff111827) : Colors.white;
  Color get cardColor => card;
  Color get divider => dark ? const Color(0xff334155) : const Color(0xffE2E8F0);
  Color get primary => dark ? Colors.white : const Color(0xff0F172A);
  Color get secondary =>
      dark ? const Color(0xff8A97B0) : const Color(0xff64748B);
  Color get link => dark ? const Color(0xff7EA2FF) : const Color(0xff1D4ED8);

  BoxDecoration card_() => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(15),
    border: Border.all(color: divider),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: p.secondary,
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final _Palette p;
  final IconData icon;
  final Color color;

  const _IconBadge({required this.p, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(p.dark ? .14 : .10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 19, color: color),
    );
  }
}