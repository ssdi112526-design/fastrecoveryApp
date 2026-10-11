import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LocationTrackingService {
  LocationTrackingService._();
  static final LocationTrackingService instance = LocationTrackingService._();

  static const _url =
      'https://www.fastrecovery.in/api/field-tracking/me/location';

  /// Itna move karne par naya location jayega.
  static const int _minDistanceMeters = 25;

  /// User ruka ho tab bhi itne time baad last location dobara jayegi,
  /// taaki admin ko "online" + latest position dikhe.
  static const Duration _heartbeat = Duration(seconds: 60);

  static const _disclosure =
      'FastRecovery collects your location, including when the app is in the '
      'background, so your admin can see where you are during work. '
      'Your location is shared only while you are logged in.';

  StreamSubscription<Position>? _sub;
  Timer? _timer;
  Position? _last;
  bool _sending = false;

  bool get isRunning => _sub != null;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Permission maangta hai aur tracking shuru karta hai.
  /// `true` = tracking chalu, `false` = permission/GPS nahi mila.
  Future<bool> start(BuildContext context) async {
    if (isRunning) return true;

    final ok = await _ensurePermission(context);
    if (!ok) return false;

    _sub = Geolocator.getPositionStream(locationSettings: _settings()).listen(
          (pos) {
        _last = pos;
        _send(pos);
      },
      onError: (_) {}, // GPS beech me band ho jaye to crash na ho
    );

    _timer = Timer.periodic(_heartbeat, (_) {
      final p = _last;
      if (p != null) _send(p);
    });

    // Stream pehla update movement par deta hai, isliye abhi ki location turant bhejo.
    unawaited(_sendNow());
    return true;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _timer?.cancel();
    _timer = null;
    _last = null;
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _minDistanceMeters,
        intervalDuration: const Duration(seconds: 30),
        // Foreground service: app minimize hone par bhi location chalti rahegi.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'FastRecovery',
          notificationText: 'Location sharing is active',
          enableWakeLock: false,
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.otherNavigation,
        distanceFilter: _minDistanceMeters,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _minDistanceMeters,
    );
  }

  Future<bool> _ensurePermission(BuildContext context) async {
    // 1. GPS on hai?
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!context.mounted) return false;
      final open = await showConfirmDialog(
        context,
        title: 'Turn on GPS',
        message: 'Please turn on device location (GPS) to continue.',
        confirmText: 'Open Settings',
        icon: Icons.location_off_rounded,
        tone: ConfirmTone.warning,
        barrierDismissible: false,
      );
      if (open) await Geolocator.openLocationSettings();
      return false;
    }

    var perm = await Geolocator.checkPermission();

    // 2. Pehli baar: pehle batao kyun chahiye (Play Store policy ke liye bhi
    //    zaroori), phir system ka popup.
    if (perm == LocationPermission.denied) {
      if (!context.mounted) return false;
      final agree = await showConfirmDialog(
        context,
        title: 'Location permission',
        message: _disclosure,
        confirmText: 'Allow',
        cancelText: 'Not now',
        icon: Icons.my_location_rounded,
        tone: ConfirmTone.primary,
        barrierDismissible: false,
      );
      if (!agree) return false;
      perm = await Geolocator.requestPermission();
    }

    // 3. "Don't ask again" ho chuka hai -> sirf app settings se on hoga.
    if (perm == LocationPermission.deniedForever) {
      if (!context.mounted) return false;
      final open = await showConfirmDialog(
        context,
        title: 'Location permission needed',
        message: 'Location permission is turned off for this app. '
            'Please enable it from App Settings.',
        confirmText: 'Open App Settings',
        icon: Icons.lock_outline_rounded,
        tone: ConfirmTone.warning,
        barrierDismissible: false,
      );
      if (open) await Geolocator.openAppSettings();
      return false;
    }

    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  Future<void> _sendNow() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      _last = pos;
      await _send(pos);
    } catch (_) {}
  }

  /// POST /api/field-tracking/me/location {latitude, longitude, accuracy}
  Future<void> _send(Position p) async {
    if (_sending) return;
    _sending = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) return;

      await http
          .post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': p.latitude,
          'longitude': p.longitude,
          'accuracy': p.accuracy,
        }),
      )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Network issue: agla update / heartbeat par dobara try hoga.
    } finally {
      _sending = false;
    }
  }
}

/// Dialog ka rang / mood.
enum ConfirmTone { primary, danger, success, warning }

extension _ToneColor on ConfirmTone {
  Color get color => switch (this) {
    ConfirmTone.primary => const Color(0xff2563EB),
    ConfirmTone.danger => const Color(0xffEF4444),
    ConfirmTone.success => const Color(0xff16A34A),
    ConfirmTone.warning => const Color(0xffF59E0B),
  };
}

/// Confirm dialog dikhata hai. User "confirm" dabaye to `true`,
/// cancel ya bahar tap kare to `false` milta hai.
///
/// final ok = await showConfirmDialog(
///   context,
///   title: 'Block user?',
///   message: 'Are you sure you want to block "Ashwani"?',
///   confirmText: 'Block',
///   icon: Icons.block_rounded,
///   tone: ConfirmTone.danger,
/// );
/// if (ok) { ... }
Future<bool> showConfirmDialog(
    BuildContext context, {
      required String title,
      required String message,
      String confirmText = 'Confirm',
      String cancelText = 'Cancel',
      IconData icon = Icons.help_outline_rounded,
      ConfirmTone tone = ConfirmTone.primary,
      bool barrierDismissible = true,
    }) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withOpacity(.5),
    builder: (_) => ConfirmDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      icon: icon,
      tone: tone,
    ),
  );
  return result ?? false;
}

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final IconData icon;
  final ConfirmTone tone;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = tone.color;

    final surface = dark ? const Color(0xff111827) : Colors.white;
    final titleColor = dark ? Colors.white : const Color(0xff0F172A);
    final bodyColor = dark ? const Color(0xff9AA7C0) : const Color(0xff64748B);
    final borderColor = dark ? const Color(0xff334155) : const Color(0xffCBD5E1);

    return Dialog(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon: bahar halka ring, andar gol rang wala badge
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: color.withOpacity(dark ? .16 : .10),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: color.withOpacity(dark ? .30 : .18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 30, color: color),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: bodyColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: titleColor,
                          side: BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        child: Text(cancelText),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        child: Text(confirmText),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}