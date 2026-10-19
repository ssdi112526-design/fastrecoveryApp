import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
// ── Apne project ke hisaab se in imports ka path check karo ─────────────────
import '../../Service/Location_tracking_permission.dart';
import '../../main.dart'; // themeNotifier, toggleTheme
import '../../theme/app_theme.dart'; // AppColors
import 'About_Us_page.dart';
import 'ContactSupportPage.dart';
import 'FAQs.dart';
import 'Privacy_policy.dart';
import 'RefundPolicyPage.dart';

abstract final class _Links {
  static const privacyPolicy = 'https://www.fastrecovery.in/privacy-policy';
  static const terms = 'https://www.fastrecovery.in/terms';
  static const appName = 'FastRecovery';

  static const removeUser = 'https://www.fastrecovery.in/api/repo-users/remove';
}


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


class SettingsPage extends StatefulWidget {
  /// Logout confirm hone ke baad chalega. Yahin token clear karo, location
  /// tracking band karo aur LoginScreen par bhejo.
  final Future<void> Function() onLogout;

  /// Optional: custom delete-account logic. Na do to default API call
  /// (`_Links.removeUser`) chalegi aur success par `onLogout` call hoga.
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
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  String get _versionLabel =>
      _info == null ? '...' : '${_info!.version} (${_info!.buildNumber})';

  // ── Delete account API ─────────────────────────────────────────────────────
  /// Success par null, fail par user ko dikhane wala message.
  Future<String?> _removeAccountApi() async {
    final prefs = await SharedPreferences.getInstance();
    final agentId = (prefs.getString('userId') ?? '').trim();
    final token = prefs.getString('token') ?? '';

    debugPrint('🗑️ [DELETE ACCOUNT] agentId  : "$agentId"');
    debugPrint('🗑️ [DELETE ACCOUNT] hasToken : ${token.isNotEmpty}');

    if (agentId.isEmpty) {
      debugPrint('🗑️ [DELETE ACCOUNT] agentId missing in prefs (key: userId)');
      return 'Account details not found. Please login again.';
    }

    final url = Uri.parse(_Links.removeUser);
    final body = jsonEncode({'agentId': agentId});

    debugPrint('🗑️ [DELETE ACCOUNT] URL     : $url');
    debugPrint('🗑️ [DELETE ACCOUNT] Payload : $body');

    try {
      final res = await http
          .post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: body,
      )
          .timeout(const Duration(seconds: 20));

      debugPrint('🗑️ [DELETE ACCOUNT] Status  : ${res.statusCode}');
      debugPrint('🗑️ [DELETE ACCOUNT] Response: ${res.body}');

      dynamic json;
      try {
        json = jsonDecode(res.body);
      } catch (_) {}

      final serverMsg = json is Map ? json['message']?.toString() : null;
      final is2xx = res.statusCode >= 200 && res.statusCode < 300;

      if (is2xx && json is Map && json['success'] == true) return null;

      return serverMsg ?? 'Could not delete account (${res.statusCode})';
    } catch (e, st) {
      debugPrint('🗑️ [DELETE ACCOUNT] ERROR   : $e');
      debugPrint('$st');
      return 'Network error. Please check your internet and try again.';
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
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

    setState(() => _deleting = true);
    try {
      final onDelete = widget.onDeleteAccount;

      // Agar parent ne custom callback diya hai to wahi chalega
      if (onDelete != null) {
        await onDelete();
        return;
      }

      // Default: direct API call (real agentId prefs se aata hai)
      final error = await _removeAccountApi();
      if (!mounted) return;

      if (error == null) {
        _snack('Account deleted successfully');
        await widget.onLogout(); // token clear + login screen
      } else {
        _snack(error); // server ka message ya network error
      }
    } catch (e) {
      debugPrint('🗑️ [DELETE ACCOUNT] Exception: $e');
      if (mounted) _snack('Could not delete account. Please try again.');
    } finally {
      if (mounted) setState(() => _deleting = false);
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
            _Group(children: [
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
                subtitle: 'Switch between light and dark theme',
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
            ]),

            // ── Privacy & Permissions ──
            // const _SectionLabel('Privacy & Permissions'),
            // ── Legal ──
            const _SectionLabel('Legal'),
            _Group(children: [
              _Tile(
                icon: Icons.description_outlined,
                color: const Color(0xff0D9488),
                title: 'Terms & Conditions',
                subtitle: 'Rules of using the app',
                onTap: () => _open(_Links.terms),
              ),
               _Tile(
                icon: Icons.policy,
                color: const Color(0xff0D9488),
                title: 'Privacy Policy',
                subtitle: 'Rules of using the app',
                onTap: () =>  _push( const PrivacyPolicyScreen()),
              ),

              _Tile(
                icon: Icons.receipt_long_outlined,
                color: const Color(0xffF59E0B),
                title: 'Refund Policy',
                subtitle: 'Refund and cancellation terms',
                onTap: () => _push(const RefundPolicyPage()),
              ),
            ]),

            // ── Support ──
            const _SectionLabel('Support'),
            _Group(children: [
              _Tile(
                icon: Icons.support_agent_rounded,
                color: const Color(0xff16A34A),
                title: 'Contact Us',
                subtitle: 'Phone, email and office address',
                onTap: () => _push(const ContactSupportPage()),
              ),
              if (isAndroid)
                _Tile(
                  icon: Icons.star_rate_rounded,
                  color: const Color(0xffF59E0B),
                  title: 'Rate this app',
                  subtitle: 'Tell us how we are doing',
                  onTap: _rateApp,
                ),
            ]),

            // ── About ──
            const _SectionLabel('About'),
            _Group(children: [
              _Tile(
                icon: Icons.info_outline_rounded,
                color: const Color(0xff2563EB),
                title: 'About Us',
                subtitle: 'Who we are and our mission',
                onTap: () => _push(const AboutUsPage()),
              ),
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
              _Tile(
                icon: Icons.help_outline_rounded,
                color: const Color(0xff7C3AED),
                title: 'FAQs',
                subtitle: 'Answers to common questions',
                onTap: () => _push(const FaqPage()),
              ),
            ]),

            // ── Account ──
            const _SectionLabel('Logout Account'),
            _Group(children: [
              _LogoutTile(onTap: _confirmLogout),
              ],),
            const _SectionLabel('Delete Account'),
              _Tile(
                icon: Icons.delete_outline_rounded,
                color: Colors.redAccent,
                title: 'Delete account',
                subtitle: _deleting
                    ? 'Deleting...'
                    : 'Permanently remove your account',
                onTap: _deleting ? null : _confirmDeleteAccount,
              ),

            const SizedBox(height: 22),
            Center(
              child: Text(
                '${_Links.appName} • ${DateTime.now().year}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: c.secondaryText.withOpacity(.8),
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

/// Tiles ke beech apne aap 8px gap deta hai.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          children[i],
        ],
      ],
    );
  }
}

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
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