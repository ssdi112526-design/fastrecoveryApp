import 'package:flutter/material.dart';

// ============================================================
// EDIT THESE VALUES BEFORE RELEASE
// ============================================================
const String kPolicyEffectiveDate = '[DD Month YYYY]';
const String kPaymentGateway = '[PAYMENT GATEWAY NAME]';
const String kRetentionDays = '30';
const String kContactEmail = '[PRIVACY / SUPPORT EMAIL]';
const String kContactAddress = '[FULL OFFICE ADDRESS]';
const String kContactPhone = '[PHONE NUMBER]';
const String kContactWebsite = 'https://fastrecovery.in';

// ============================================================
// SCREEN
// ============================================================
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const _PolicyHeader(),
            const SizedBox(height: 16),
            for (int i = 0; i < _sections.length; i++)
              _SectionCard(number: i + 1, section: _sections[i]),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// WIDGETS
// ============================================================
class _PolicyHeader extends StatelessWidget {
  const _PolicyHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.privacy_tip_outlined, color: _kBlue),
              SizedBox(width: 8),
              Text(
                'FastRecovery Privacy Policy',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Effective date: $kPolicyEffectiveDate',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final int number;
  final _PolicySection section;

  const _SectionCard({required this.number, required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBlue.withOpacity(0.35)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: number == 1,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: _NumberBadge(number: number),
          title: Row(
            children: [
              Icon(section.icon, size: 18, color: _kBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          children: [
            for (final block in section.blocks) _BlockView(block: block),
          ],
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  final int number;
  const _NumberBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        number.toString().padLeft(2, '0'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BlockView extends StatelessWidget {
  final _Block block;
  const _BlockView({required this.block});

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      height: 1.5,
    );

    if (block.bullets != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in block.bullets!)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 10),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: _kBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(child: Text(item, style: bodyStyle)),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text.rich(
        TextSpan(
          style: bodyStyle,
          children: [
            if (block.lead != null)
              TextSpan(
                text: '${block.lead} ',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            TextSpan(text: block.text),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DATA MODEL
// ============================================================
const Color _kBlue = Color(0xFF2347E5);

class _PolicySection {
  final String title;
  final IconData icon;
  final List<_Block> blocks;
  const _PolicySection(this.title, this.icon, this.blocks);
}

class _Block {
  final String? lead;
  final String? text;
  final List<String>? bullets;

  const _Block.p(this.text)
      : lead = null,
        bullets = null;
  const _Block.lead(this.lead, this.text) : bullets = null;
  const _Block.bullets(this.bullets)
      : lead = null,
        text = null;
}

// ============================================================
// POLICY CONTENT
// ============================================================
final List<_PolicySection> _sections = [
  // 1
  _PolicySection('Introduction', Icons.description_outlined, [
    _Block.p(
        'Software Solutions Development India ("SSDI", "we", "us", "our") operates the FastRecovery mobile application and website (the "Platform"). This Privacy Policy explains what Personal Data we collect, why we collect it, how we use and share it, and the choices you have.'),
    _Block.p(
        'By registering for or using FastRecovery, you agree to this Privacy Policy. It should be read together with our Terms and Conditions and Refund Policy.'),
    _Block.p(
        'FastRecovery is a technology platform that facilitates the authorized sharing of finance-related vehicle information between banks, NBFCs, authorized legal recovery agencies and their permitted users. We handle Personal Data in accordance with the Information Technology Act, 2000, the Digital Personal Data Protection Act, 2023, and other applicable Indian laws.'),
  ]),

  // 2
  _PolicySection('Information We Collect', Icons.folder_open_outlined, [
    _Block.lead('Account and profile information:',
        'name, mobile number, email address, agency or company name, address, role, and login credentials.'),
    _Block.lead('KYC and business documents:',
        'Aadhaar, PAN, GST registration details, business information and authorization documents submitted for account activation and compliance verification.'),
    _Block.lead('Vehicle and case data:',
        'vehicle registration numbers, chassis numbers, loan and finance details, and bank or NBFC information uploaded by participating banks, NBFCs and authorized agencies. This data is provided by those organizations, and they are responsible for its accuracy and lawful authorization.'),
    _Block.lead('Search and activity data:',
        'vehicle searches, case confirmations, usage history and related logs.'),
    _Block.lead('Location information:',
        'location data may be collected or recorded when tracking or search features are enabled and lawfully authorized for a relevant case. [Location is collected only while the app is in use. Edit this line if background location is used.]'),
    _Block.lead('Photos, videos and documents:',
        'images, videos and PDFs that users upload as inventory records or supporting evidence during an authorized recovery operation.'),
    _Block.lead('Payment information:',
        'transaction details for packages and subscriptions. Card, UPI and bank credentials are processed by our payment provider, $kPaymentGateway, and are not stored by us.'),
    _Block.lead('Device and technical information:',
        'device model, operating system, app version, IP address and crash or diagnostic data.'),
  ]),

  // 3
  _PolicySection('How We Use Your Information', Icons.tune_outlined, [
    _Block.bullets([
      'To create and verify accounts and complete KYC and onboarding',
      'To provide vehicle search, case coordination, confirmations and inventory features',
      'To share information with permitted users according to their role and authorization',
      'To process payments, issue invoices and manage subscriptions',
      'To provide customer support and respond to requests',
      'To maintain security, prevent fraud and misuse, and enforce our Terms',
      'To comply with legal obligations and respond to lawful requests',
      'To improve and maintain the Platform',
    ]),
    _Block.p('We do not sell your Personal Data.'),
  ]),

  // 4
  _PolicySection('Permissions Used by the App', Icons.phone_android_outlined, [
    _Block.p(
        'The app may request the following permissions. Each is used only for the purpose stated.'),
    _Block.lead('Location:',
        'to record search or tracking location for authorized cases.'),
    _Block.lead(
        'Camera:', 'to capture photos and videos for inventory and evidence.'),
    _Block.lead('Photos, media and files:',
        'to upload inventory images, videos and PDFs, and to save or share downloaded files.'),
    _Block.lead(
        'Notifications:', 'to send alerts about cases and account activity.'),
    _Block.lead('Internet and network state:',
        'to connect to our servers and manage offline sync.'),
    _Block.lead('Phone, SMS and WhatsApp sharing:',
        'vehicle details are shared through the Call, SMS or WhatsApp apps on your device, only when you tap the relevant button.'),
  ]),

  // 5
  _PolicySection(
      'Data Stored on Your Device', Icons.storage_outlined, [
    _Block.p(
        'To allow vehicle search when the internet is unavailable (offline mode), the app downloads authorized records and stores them in a local database on your device.'),
    _Block.p(
        'This data is accessible only through the app and is subject to your account permissions. Logging out or deleting your account may remove locally stored data. Please keep your device secure with a screen lock.'),
  ]),

  // 6
  _PolicySection('Sharing and Disclosure', Icons.share_outlined, [
    _Block.p(
        'We may share Personal Data only where there is a lawful basis:'),
    _Block.lead('With banks, NBFCs and authorized agencies,',
        'according to the roles, permissions and agreements applicable to each user.'),
    _Block.lead('With service providers',
        'that help us operate the Platform, such as hosting and cloud providers, payment gateways and messaging services.'),
    _Block.lead('For legal reasons:',
        'to comply with law, court orders or valid requests from public authorities, to protect our rights and the safety of users or the public, and to detect or prevent fraud and wrongdoing.'),
    _Block.lead('In business transactions',
        'such as a merger, acquisition or sale of assets, subject to applicable law.'),
    _Block.p(
        "SSDI's own administrative panel is designed not to provide access to individual vehicle-tracing locations."),
  ]),

  // 7
  _PolicySection('Data Retention', Icons.schedule_outlined, [
    _Block.p(
        'We keep Personal Data for as long as your account is active and as needed to provide the services.'),
    _Block.p(
        'After an account deletion request, we delete or anonymize your data within $kRetentionDays days, except where retention is required by law, for security and fraud prevention, to resolve disputes, to maintain financial and business records, or to establish, exercise or defend legal claims.'),
  ]),

  // 8
  _PolicySection('Data Security', Icons.lock_outline, [
    _Block.p(
        'We use reasonable technical and organizational measures, including access controls, authentication, permission restrictions and encrypted transmission (HTTPS), to protect Personal Data.'),
    _Block.p(
        'No method of transmission or storage is completely secure, so we cannot guarantee absolute security. Please keep your login credentials confidential and report any suspected unauthorized access to us immediately.'),
  ]),

  // 9
  _PolicySection('Your Rights and Choices', Icons.manage_accounts_outlined, [
    _Block.p(
        'You may request access to, correction of, or deletion of your Personal Data, subject to applicable law. You can:'),
    _Block.bullets([
      'Delete your account in the app: Settings > Delete Account',
      'Or email us at $kContactEmail with the subject "Account Deletion Request" from your registered email or mobile number',
    ]),
    _Block.p(
        'Deleting your account may remove access to case information, search history and other features. Deletion does not automatically cancel outstanding payments or create a right to a refund (see our Refund Policy).'),
    _Block.p(
        'You may also withdraw permissions such as location or camera at any time from your device settings, but some features may then stop working.'),
  ]),

  // 10
  _PolicySection("Children's Privacy", Icons.family_restroom_outlined, [
    _Block.p(
        'FastRecovery is intended for users aged 18 and above. We do not knowingly collect Personal Data from anyone under 18.'),
    _Block.p(
        'If you believe a child has provided us data, contact us and we will take appropriate steps, including deletion where required by law.'),
  ]),

  // 11
  _PolicySection('Third-Party Links and Services', Icons.link, [
    _Block.p(
        'The Platform may link to third-party websites, payment services or apps that we do not own or control. We are not responsible for their privacy practices, and we encourage you to read their policies.'),
  ]),

  // 12
  _PolicySection('Cookies', Icons.cookie_outlined, [
    _Block.p(
        'Our website may use cookies, such as a persistent cookie that remembers whether you accepted the cookie notice. You can manage or delete cookies through your browser settings. Disabling some cookies may affect website features.'),
  ]),

  // 13
  _PolicySection('Changes to This Policy', Icons.update, [
    _Block.p(
        'We may update this Privacy Policy from time to time. The updated version will be published on our website and in the app with a revised effective date.'),
    _Block.p(
        'Where required by law, we will notify you of material changes or obtain consent. Continued use of FastRecovery after an update means you accept the updated policy.'),
  ]),

  // 14
  _PolicySection('Contact Us', Icons.mail_outline, [
    _Block.lead('Company:', 'Software Solutions Development India (SSDI)'),
    _Block.lead('Address:', kContactAddress),
    _Block.lead('Email:', kContactEmail),
    _Block.lead('Phone:', kContactPhone),
    _Block.lead('Website:', kContactWebsite),
    _Block.p(
        'Please do not send Aadhaar details, passwords or payment credentials by email unless specifically requested through a secure channel.'),
  ]),
];