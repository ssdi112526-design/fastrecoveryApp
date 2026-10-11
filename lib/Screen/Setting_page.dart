import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
// ── Apne project ke hisaab se in 3 imports ka path check karo ───────────────
import '../Service/Location_tracking_permission.dart';
import '../main.dart'; // themeNotifier, toggleTheme
import '../theme/app_theme.dart'; // AppColors

// ═════════════════════════════════════════════════════════════════════════════
//  1. LINKS  (Play Store ke liye REAL links daalna zaroori hai)
// ═════════════════════════════════════════════════════════════════════════════

abstract final class _Links {
  static const privacyPolicy = 'https://www.fastrecovery.in/privacy-policy';
  static const terms = 'https://www.fastrecovery.in/terms';
  static const supportEmail = 'support@fastrecovery.in';
  static const appName = 'FastRecovery';
}

// ═════════════════════════════════════════════════════════════════════════════
//  2. COLORS
// ═════════════════════════════════════════════════════════════════════════════

class _C {
  final bool dark;
  const _C._(this.dark);

  factory _C.of(BuildContext context) =>
      _C._(Theme.of(context).brightness == Brightness.dark);

  Color get scaffold => dark ? const Color(0xff0B1220) : const Color(0xffF8FAFC);
  Color get card => dark ? const Color(0xff111827) : Colors.white;
  Color get divider => dark ? const Color(0xff334155) : const Color(0xffE2E8F0);
  Color get primaryText => dark ? Colors.white : const Color(0xff0F172A);
  Color get secondaryText =>
      dark ? const Color(0xff8A97B0) : const Color(0xff64748B);
}

// ═════════════════════════════════════════════════════════════════════════════
//  3. PAGE
// ═════════════════════════════════════════════════════════════════════════════

class SettingsPage extends StatefulWidget {
  /// Logout confirm hone ke baad chalega. Yahin token clear karo, location
  /// tracking band karo aur LoginScreen par bhejo.
  final Future<void> Function() onLogout;

  /// Delete account confirm hone ke baad chalega (API call yahan lagao).
  /// Na do to support email ka request khulega.
  final Future<void> Function()? onDeleteAccount;

  const SettingsPage({
    super.key,
    required this.onLogout,
    this.onDeleteAccount,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  String get _versionLabel =>
      _info == null ? '...' : '${_info!.version} (${_info!.buildNumber})';

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _open(String url, {LaunchMode? mode}) async {
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: mode ?? LaunchMode.externalApplication,
      );
      if (!ok) _snack('Could not open link');
    } catch (_) {
      _snack('Could not open link');
    }
  }

  Future<void> _emailSupport(String subject) async {
    final body = 'App version: $_versionLabel\n\n';
    final uri = Uri(
      scheme: 'mailto',
      path: _Links.supportEmail,
      query: 'subject=${Uri.encodeComponent(subject)}'
          '&body=${Uri.encodeComponent(body)}',
    );
    try {
      final ok = await launchUrl(uri);
      if (!ok) _snack('No email app found on this device');
    } catch (_) {
      _snack('No email app found on this device');
    }
  }

  Future<void> _rateApp() async {
    final pkg = _info?.packageName;
    if (pkg == null) return;
    try {
      final ok = await launchUrl(
        Uri.parse('market://details?id=$pkg'),
        mode: LaunchMode.externalApplication,
      );
      if (ok) return;
    } catch (_) {/* Play Store app nahi hai, browser try karte hain */}
    await _open('https://play.google.com/store/apps/details?id=$pkg');
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: _Links.appName,
      applicationVersion: _versionLabel,
      applicationIcon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.blue600.withOpacity(.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.local_shipping_rounded,
          color: AppColors.blue600,
          size: 28,
        ),
      ),
      applicationLegalese: '© ${DateTime.now().year} ${_Links.appName}',
      children: const [
        SizedBox(height: 14),
        Text(
          'FastRecovery helps repo agencies search vehicles, share '
              'confirmations and manage their field team.',
        ),
      ],
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Logout?',
      message: 'Are you sure you want to logout from this device?',
      confirmText: 'Logout',
      icon: Icons.logout_rounded,
      tone: ConfirmTone.danger,
    );
    if (ok && mounted) await widget.onLogout();
  }

  Future<void> _confirmDeleteAccount() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete account?',
      message: 'Your account and its data will be permanently deleted. '
          'This cannot be undone.',
      confirmText: 'Delete',
      icon: Icons.delete_outline_rounded,
      tone: ConfirmTone.danger,
    );
    if (!ok || !mounted) return;

    final onDelete = widget.onDeleteAccount;
    if (onDelete == null) {
      await _emailSupport('Account deletion request');
      return;
    }
    try {
      await onDelete();
    } catch (e) {
      _snack('Could not delete account. Please try again.');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.card,
        elevation: 0.5,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: c.primaryText),
        centerTitle: false,
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: c.primaryText,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ── Appearance ──
            const _SectionLabel('Appearance'),
            _Tile(
              leading: ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, mode, _) {
                  final dark = mode == ThemeMode.dark;
                  return _IconBadge(
                    icon: dark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: dark ? AppColors.gold400 : AppColors.blue600,
                  );
                },
              ),
              title: 'Dark Mode',
              subtitle: 'Appearance',
              trailing: ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, mode, _) {
                  final dark = mode == ThemeMode.dark;
                  return Switch(
                    value: dark,
                    activeColor: AppColors.gold400,
                    activeTrackColor: AppColors.gold400.withOpacity(.25),
                    inactiveThumbColor: AppColors.blue600,
                    inactiveTrackColor: AppColors.blue600.withOpacity(.12),
                    onChanged: toggleTheme,
                  );
                },
              ),
            ),

            // ── Privacy ──
            const _SectionLabel('Privacy & Permissions'),
            // _Tile(
            //   icon: Icons.my_location_rounded,
            //   color: const Color(0xff2563EB),
            //   title: 'Location sharing',
            //   subtitle: 'Manage location permission',
            //   onTap: Geolocator.openAppSettings,
            // ),
            // const SizedBox(height: 8),
            // _Tile(
            //   icon: Icons.privacy_tip_outlined,
            //   color: const Color(0xff7C3AED),
            //   title: 'Privacy Policy',
            //   subtitle: 'How we use your data',
            //   onTap: () => _open(_Links.privacyPolicy),
            // ),
            const SizedBox(height: 8),
            _Tile(
              icon: Icons.description_outlined,
              color: const Color(0xff0D9488),
              title: 'Terms & Conditions',
              subtitle: 'Rules of using the app',
              onTap: () => _open(_Links.terms),
            ),

            // ── Support ──
            const _SectionLabel('Support'),
            _Tile(
              icon: Icons.support_agent_rounded,
              color: const Color(0xff16A34A),
              title: 'Contact support',
              subtitle: _Links.supportEmail,
              onTap: () => _emailSupport('${_Links.appName} support'),
            ),
            if (isAndroid) ...[
              const SizedBox(height: 8),
              _Tile(
                icon: Icons.star_rate_rounded,
                color: const Color(0xffF59E0B),
                title: 'Rate this app',
                subtitle: 'Tell us how we are doing',
                onTap: _rateApp,
              ),
            ],

            // ── About ──
             const _SectionLabel('About'),
            // _Tile(
            //   icon: Icons.info_outline_rounded,
            //   color: const Color(0xff2563EB),
            //   title: 'About ${_Links.appName}',
            //   subtitle: 'App details and licenses',
            //   onTap: _showAbout,
            // ),
            const SizedBox(height: 8),
            _Tile(
              icon: Icons.verified_outlined,
              color: const Color(0xff64748B),
              title: 'App version',
              subtitle: 'Current installed version',
              trailing: Text(
                _versionLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: c.primaryText,
                ),
              ),
            ),

            // ── Account ──
            const _SectionLabel('Account'),
            _LogoutTile(onTap: _confirmLogout),
            const SizedBox(height: 8),
            _Tile(
              icon: Icons.delete_outline_rounded,
              color: Colors.redAccent,
              title: 'Delete account',
              subtitle: 'Permanently remove your account',
              onTap: _confirmDeleteAccount,
            ),

            const SizedBox(height: 18),
            Center(
              child: Text(
                'FastRecovery • ${DateTime.now().year}',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: c.secondaryText.withOpacity(.7),
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
//  4. SMALL WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: c.secondaryText,
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(c.dark ? .14 : .10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 19, color: color),
    );
  }
}

/// Ek settings row. `leading` do to custom widget, warna `icon` + `color`.
class _Tile extends StatelessWidget {
  final IconData? icon;
  final Color? color;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Tile({
    this.icon,
    this.color,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  }) : assert(leading != null || (icon != null && color != null));

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);

    return Material(
      color: c.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: c.divider),
      ),
      child: ListTile(
        dense: true,
        onTap: onTap,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
        leading: leading ?? _IconBadge(icon: icon!, color: color!),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: c.primaryText,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
          subtitle!,
          style: TextStyle(fontSize: 10.5, color: c.secondaryText),
        ),
        trailing: trailing ??
            (onTap == null
                ? null
                : Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: c.secondaryText,
            )),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(.06),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.redAccent.withOpacity(.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  size: 19,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.redAccent.shade100 : Colors.redAccent,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: Colors.redAccent.withOpacity(.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}