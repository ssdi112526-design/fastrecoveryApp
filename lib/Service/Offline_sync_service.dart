// lib/Service/Offline_sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../db_helper/Offline_DB_helper.dart';

enum SyncStatus { idle, syncing, paused, completed, error }

class _Unauthorized implements Exception {}

class _Offline implements Exception {}

class _Page {
  final List<Map<String, dynamic>> items;
  final bool hasNext;
  final String nextCursor;
  const _Page({
    required this.items,
    required this.hasNext,
    required this.nextCursor,
  });
}

// compute() ke liye top-level function chahiye.
Map<String, dynamic> _decodeJson(String s) =>
    Map<String, dynamic>.from(jsonDecode(s) as Map);

/// Offline data sync + Online/Offline mode.
///
/// - Pehla sync: cursor se page-by-page download, har page ke baad cursor save
///   (net jaye ya app band ho to wahin se resume). Complete hone par popup.
/// - Uske baad: sirf silent incremental sync (`since` se naya data),
///   UI/status nahi badalta, aur [_minIncrementalGap] se pehle dobara nahi chalta.
/// - Online/Offline switch hi sync control karta hai: Offline ON -> sync chalta hai,
///   Online -> pause. Search ka source bhi isi switch se decide hota hai.
class OfflineSyncService extends ChangeNotifier {
  OfflineSyncService._();
  static final OfflineSyncService instance = OfflineSyncService._();

  static const String _url =
      'https://www.fastrecovery.in/api/repo-cases/offline-sync/records';
  static const int _pageSize = 10000;

  // Phone aur server ki clock ka farq cover karne ke liye. Upsert hai, duplicate safe.
  static const Duration _sinceBuffer = Duration(minutes: 5);
  static const Duration _retryDelay = Duration(seconds: 30);
  static const Duration _minIncrementalGap = Duration(minutes: 10);

  // SharedPreferences keys
  static const String _kCursor = 'offline_sync_cursor';
  static const String _kDone = 'offline_sync_done';
  static const String _kSince = 'offline_sync_since';
  static const String _kLastAt = 'offline_sync_last_at';
  static const String _kOfflineMode = 'offline_mode_enabled';
  static const String _kDoneAck = 'offline_sync_done_ack';

  // ---------------- Public state ----------------
  SyncStatus status = SyncStatus.idle;
  bool isOnline = true;
  bool offlineMode = false; // user ka manual switch
  int localCount = 0;
  int sessionDownloaded = 0;
  int totalEstimate = 0; // Home se set hota hai (companyTotalRecords)
  String? error;
  DateTime? lastSyncedAt;

  /// User ne "Sync Complete" popup par OK dabaya ya nahi.
  bool doneAcknowledged = true;

  bool get isSyncing => status == SyncStatus.syncing;
  bool get hasData => localCount > 0;

  /// Pehla sync complete hua aur user ne OK nahi dabaya.
  bool get showDonePopup =>
      status == SyncStatus.completed && !doneAcknowledged;

  /// Search local DB se ho: user ne Offline mode ON kiya ho ya net na ho.
  bool get useOffline => offlineMode || !isOnline;

  double? get progress {
    if (status == SyncStatus.completed) return 1;
    if (totalEstimate <= 0) return null;
    return (localCount / totalEstimate).clamp(0.0, 1.0);
  }

  // ---------------- Private ----------------
  bool _running = false;
  bool _stop = false;
  bool _inited = false;
  bool _resetting = false;
  bool _incremental = false; // chal raha sync silent (since) wala hai ya nahi
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _retryTimer;

  void _log(String m) {
    if (kDebugMode) debugPrint('[OFFLINE-SYNC] $m');
  }

  // ============================================================
  // INIT / RESET
  // ============================================================
  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    final prefs = await SharedPreferences.getInstance();
    offlineMode = prefs.getBool(_kOfflineMode) ?? false;

    final last = prefs.getString(_kLastAt);
    if (last != null) lastSyncedAt = DateTime.tryParse(last)?.toLocal();

    final done = prefs.getBool(_kDone) ?? false;
    final hasCursor = (prefs.getString(_kCursor) ?? '').isNotEmpty;
    if (done) {
      status = SyncStatus.completed;
    } else if (hasCursor) {
      status = SyncStatus.paused; // adhoora sync -> UI mein "Resume"
    }

    // Purane users (sync pehle hi done) ko popup nahi aayega.
    doneAcknowledged = prefs.getBool(_kDoneAck) ?? done;

    localCount = await OfflineDb.instance.count();

    final c = await Connectivity().checkConnectivity();
    isOnline = !c.contains(ConnectivityResult.none);
    _log('init done=$done cursor="${prefs.getString(_kCursor)}" '
        'local=$localCount online=$isOnline offlineMode=$offlineMode');

    _sub = Connectivity().onConnectivityChanged.listen((r) {
      final on = !r.contains(ConnectivityResult.none);
      final was = isOnline;
      isOnline = on;
      _log('connectivity online=$on');
      if (!on && _running) {
        // Net gaya: in-flight request ke lamba timeout ka wait mat karo.
        _stop = true;
        // Silent (incremental) sync ka status mat badlo.
        if (!_incremental) status = SyncStatus.paused;
      }
      notifyListeners();
      // Net wapas aaya -> sync resume, lekin sirf Offline mode ON ho tab
      if (on && !was && offlineMode) start();
    });

    notifyListeners();
  }

  /// Logout par call karo: DB, prefs aur state sab saaf.
  Future<void> reset() async {
    _resetting = true;
    _stop = true;
    _retryTimer?.cancel();

    // Chalta sync khatam hone do, warna clear ke baad page insert ho sakta hai.
    for (var i = 0; _running && i < 50; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    await OfflineDb.instance.clear();

    final prefs = await SharedPreferences.getInstance();
    for (final k in [
      _kCursor,
      _kDone,
      _kSince,
      _kLastAt,
      _kOfflineMode,
      _kDoneAck,
    ]) {
      await prefs.remove(k);
    }

    localCount = 0;
    sessionDownloaded = 0;
    lastSyncedAt = null;
    error = null;
    offlineMode = false;
    doneAcknowledged = true;
    status = SyncStatus.idle;
    _resetting = false;
    notifyListeners();
  }

  // ============================================================
  // MODE SWITCH
  // ============================================================
  Future<void> setOfflineMode(bool value) async {
    offlineMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOfflineMode, value);
    _log('offlineMode=$value');

    // Switch hi sync ko control karta hai:
    // Offline ON -> sync start/resume, Online -> sync pause.
    if (value) {
      start();
    } else {
      pause();
    }
  }

  /// Popup par OK dabane par call hota hai.
  Future<void> acknowledgeDone() async {
    doneAcknowledged = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDoneAck, true);
  }

  // ============================================================
  // SYNC
  // ============================================================
  void pause() {
    _retryTimer?.cancel();
    if (_running) _stop = true;
  }

  Future<void> start({bool forceFull = false}) async {
    // Flag sabse pehle (await se pehle), warna do jagah se ek saath
    // start() aane par do sync parallel chal jaate hain.
    if (_resetting) return;
    if (_running) {
      // Pending pause ho to cancel (jaldi Offline->Online->Offline ya net flicker par)
      _stop = false;
      if (!_incremental && status == SyncStatus.paused) {
        status = SyncStatus.syncing;
        notifyListeners();
      }
      return;
    }
    _running = true;
    _stop = false;
    _retryTimer?.cancel();
    var incremental = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        _log('no token, skip');
        return;
      }

      if (!isOnline) {
        if (status != SyncStatus.completed) {
          status = SyncStatus.paused;
          notifyListeners();
        }
        _log('offline, skip');
        return;
      }

      if (forceFull) {
        await prefs.remove(_kCursor);
        await prefs.remove(_kSince);
        await prefs.setBool(_kDone, false);
        await OfflineDb.instance.clear();
        localCount = 0;
        lastSyncedAt = null;
      }

      final wasDone = prefs.getBool(_kDone) ?? false;
      incremental = wasDone;
      _incremental = incremental;

      // Ek baar sync ho chuka hai: bar-bar mat chalao.
      if (incremental &&
          lastSyncedAt != null &&
          DateTime.now().difference(lastSyncedAt!) < _minIncrementalGap) {
        _log('recent sync, skip');
        return;
      }

      // Pehla sync: saved cursor se resume. Baad mein: sirf naya data (since).
      var cursor = wasDone ? '' : (prefs.getString(_kCursor) ?? '');
      final since = wasDone ? (prefs.getString(_kSince) ?? '') : '';
      final startedAt = DateTime.now().toUtc();

      _log('START incremental=$incremental cursor="$cursor" since="$since"');

      if (!incremental) {
        status = SyncStatus.syncing;
        sessionDownloaded = 0;
        error = null;
        notifyListeners();
      }

      var pageNo = 0;
      while (true) {
        if (_stop) {
          if (!incremental) status = SyncStatus.paused;
          break;
        }

        final page = await _fetchWithRetry(token, cursor, since);
        pageNo++;
        _log('page#$pageNo items=${page.items.length} '
            'hasNext=${page.hasNext} next=${page.nextCursor}');

        // Pause/reset ke baad stale page insert na ho.
        if (_stop) {
          if (!incremental) status = SyncStatus.paused;
          break;
        }

        await OfflineDb.instance.upsert(page.items);

        sessionDownloaded += page.items.length;
        // Incremental sync mein count end par exact aata hai.
        if (!incremental) localCount += page.items.length;

        final next = page.nextCursor;
        if (!incremental) {
          await prefs.setString(_kCursor, next);
          notifyListeners();
        }

        if (!page.hasNext || next.isEmpty) {
          final syncPoint = startedAt.subtract(_sinceBuffer).toIso8601String();
          await prefs.setBool(_kDone, true);
          await prefs.setString(_kSince, syncPoint);
          await prefs.setString(_kLastAt, startedAt.toIso8601String());
          await prefs.remove(_kCursor);
          lastSyncedAt = DateTime.now();
          localCount = await OfflineDb.instance.count();

          if (!incremental) {
            // Pehla full sync complete -> popup dikhao
            doneAcknowledged = false;
            await prefs.setBool(_kDoneAck, false);
          }
          status = SyncStatus.completed;
          _log('DONE local=$localCount');
          break;
        }

        // Server same cursor lautaye to infinite loop na ho.
        if (next == cursor) {
          throw StateError('nextCursor did not advance ($next)');
        }
        cursor = next;
      }
    } on _Unauthorized {
      if (!incremental) {
        status = SyncStatus.error;
        error = 'Session expired. Please login again.';
      }
      _log('401 unauthorized');
    } on _Offline {
      if (!incremental) {
        status = SyncStatus.paused;
        error = null;
        _scheduleRetry();
      }
      _log('network lost');
    } catch (e, st) {
      _log('ERROR: $e\n$st');
      if (!incremental) {
        status = SyncStatus.error;
        error = 'Sync failed. Tap to retry.';
      }
    } finally {
      _running = false;
      _incremental = false;
      if (status != SyncStatus.completed) {
        try {
          localCount = await OfflineDb.instance.count();
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  // Weak net par connectivity event nahi aata, isliye timer se retry.
  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () {
      if (isOnline && !_running && status == SyncStatus.paused) start();
    });
  }

  Future<_Page> _fetchWithRetry(
      String token,
      String cursor,
      String since,
      ) async {
    const maxAttempts = 3;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (!isOnline) throw _Offline();
      try {
        final uri = Uri.parse(_url).replace(queryParameters: {
          'source': 'agency',
          if (cursor.isNotEmpty) 'cursor': cursor,
          'since': since,
          'limit': '$_pageSize',
        });
        _log('GET cursor="$cursor" since="$since" (attempt $attempt)');

        final res = await http.get(uri, headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        }).timeout(const Duration(seconds: 30));

        if (res.statusCode == 401) throw _Unauthorized();
        if (res.statusCode < 200 || res.statusCode >= 300) {
          _log('HTTP ${res.statusCode}');
          throw HttpException('HTTP ${res.statusCode}');
        }

        // Bada JSON background isolate mein decode (UI jank nahi).
        final body = await compute(_decodeJson, res.body);
        if (cursor.isEmpty) _log('response keys: ${body.keys.toList()}');

        final raw = body['items'];
        final items = raw is List
            ? raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
            : <Map<String, dynamic>>[];

        return _Page(
          items: items,
          hasNext: body['hasNext'] == true,
          nextCursor: (body['nextCursor'] ?? '').toString(),
        );
      } on _Unauthorized {
        rethrow;
      } on SocketException {
        if (attempt == maxAttempts) throw _Offline();
      } on TimeoutException {
        if (attempt == maxAttempts) throw _Offline();
      } on HandshakeException {
        if (attempt == maxAttempts) throw _Offline();
      } on http.ClientException {
        if (attempt == maxAttempts) throw _Offline();
      } catch (_) {
        if (attempt == maxAttempts) rethrow;
      }
      await Future.delayed(Duration(seconds: attempt * 2));
    }
    throw _Offline();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}