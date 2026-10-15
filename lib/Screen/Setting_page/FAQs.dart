import 'package:flutter/material.dart';

/// Frequently Asked Questions screen.
/// Settings page ke saath same folder mein rakho.
///
/// Logo assets (RefundPolicyPage / AboutUsPage wale hi):
///   assets/images/fastrecovery_logo_light.png
///   assets/images/fastrecovery_logo_dark.png
class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  static const _logoLight = 'assets/images/fastrecovery_logo_light.png';
  static const _logoDark = 'assets/images/fastrecovery_logo_dark.png';

  static const List<(String, String)> _faqs = [
    (
    'What is Fast Recovery?',
    'Fast Recovery is a SaaS platform for loan repossession agencies, '
        'banks, and field tracers. It connects all parties in the recovery '
        'chain — bank uploads data, agency assigns cases, tracers work in '
        'the field.',
    ),
    (
    'How does a bank connect with an agency?',
    'SSDI (our admin team) manually creates the link between a bank and an '
        'agency after both are registered on the platform. Once linked, the '
        'agency can see the bank\'s uploaded recovery data.',
    ),
    (
    'Is the data secure?',
    'Yes. Every record is tagged to the bank and uploader. Agencies only '
        'see data from banks linked to them. Tracers only see cases '
        'assigned to them. All data is stored in MongoDB Atlas with '
        'JWT-secured APIs.',
    ),
    (
    'How do I upload recovery data as a bank?',
    'Log into the Bank Panel and go to Records. Upload your Excel file — it '
        'goes directly to AWS S3 and is processed in the background. Files '
        'with 400,000+ rows are fully supported.',
    ),
    (
    'How do I register my agency?',
    'Contact SSDI or register via the APK register link on the home page. '
        'SSDI activates your account after verifying payment.',
    ),
    (
    'What file formats are supported for upload?',
    'Excel files (.xlsx and .xls) are supported. The system automatically '
        'maps common column names like \'Registration Numbers\', \'Loan '
        'Number\', \'Mobile No\', etc.',
    ),
    (
    'How do I contact support?',
    'Call 8796814100 or email us. You can also use the Contact Us page.',
    ),
  ];

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
          'FAQs',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800, color: p.primary),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
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
                const SizedBox(height: 14),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: p.divider),
                  ),
                  child: Theme(
                    // ExpansionTile ki default divider lines hata di
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      splashColor: Colors.transparent,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < _faqs.length; i++) ...[
                          _FaqTile(
                            p: p,
                            question: _faqs[i].$1,
                            answer: _faqs[i].$2,
                            initiallyExpanded: i == 0,
                          ),
                          if (i != _faqs.length - 1)
                            Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: p.divider,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    '© ${DateTime.now().year} Software Solutions Development India',
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
  Color get accent => dark ? const Color(0xff7EA2FF) : const Color(0xff1D4ED8);
}

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
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: p.divider),
      ),
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
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 21,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: p.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Everything you need to know about Fast Recovery.',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: p.secondary),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final _Palette p;
  final String question;
  final String answer;
  final bool initiallyExpanded;

  const _FaqTile({
    required this.p,
    required this.question,
    required this.answer,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: p.accent,
      collapsedIconColor: p.secondary,
      title: Text(
        question,
        style: TextStyle(
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: p.primary,
        ),
      ),
      children: [
        Text(
          answer,
          style: TextStyle(fontSize: 13.5, height: 1.65, color: p.secondary),
        ),
      ],
    );
  }
}