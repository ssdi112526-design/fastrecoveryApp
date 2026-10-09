// pubspec.yaml needs: geolocator, http, shared_preferences
//   flutter pub add geolocator
//
// Use:
//   login success / auto-login : await LocationTrackingService.instance.start(context);
//   logout                     : await LocationTrackingService.instance.stop();

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
        foregroundNotificationConfig: ForegroundNotificationConfig(
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
      final open = await _dialog(
        context,
        title: 'Turn on GPS',
        message: 'Please turn on device location (GPS) to continue.',
        action: 'Open Settings',
      );
      if (open == true) await Geolocator.openLocationSettings();
      return false;
    }

    var perm = await Geolocator.checkPermission();

    // 2. Pehli baar: pehle batao kyun chahiye (Play Store policy ke liye bhi
    //    zaroori), phir system ka popup.
    if (perm == LocationPermission.denied) {
      if (!context.mounted) return false;
      final agree = await _dialog(
        context,
        title: 'Location permission',
        message: _disclosure,
        action: 'Allow',
        cancel: 'Not now',
      );
      if (agree != true) return false;
      perm = await Geolocator.requestPermission();
    }

    // 3. "Don't ask again" ho chuka hai -> sirf app settings se on hoga.
    if (perm == LocationPermission.deniedForever) {
      if (!context.mounted) return false;
      final open = await _dialog(
        context,
        title: 'Location permission needed',
        message:
        'Location permission is turned off for this app. Please enable it from App Settings.',
        action: 'Open App Settings',
      );
      if (open == true) await Geolocator.openAppSettings();
      return false;
    }

    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  Future<bool?> _dialog(
      BuildContext context, {
        required String title,
        required String message,
        required String action,
        String cancel = 'Cancel',
      }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
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