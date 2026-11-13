// lib/Service/offline_db.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class OfflineDb {
  OfflineDb._();
  static final OfflineDb instance = OfflineDb._();

  static const int vehicleDigits = 4;
  static const int chassisDigits = 6;
  static const int _maxResults = 2000;

  Database? _db;
  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'offline_records.db');
    return openDatabase(
      path,
      version: 3,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA synchronous = NORMAL');
      },
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE records(
            id TEXT PRIMARY KEY,
            row_id INTEGER,
            vehicle TEXT,
            vehicle_last4 TEXT,
            chassis TEXT,
            chassis_last6 TEXT,
            dedupe_key TEXT,
            json TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_vehicle4 ON records(vehicle_last4)');
        await db.execute('CREATE INDEX idx_chassis6 ON records(chassis_last6)');
        await db.execute(
            'CREATE UNIQUE INDEX idx_dedupe ON records(dedupe_key)');
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 3) {
          final cols = await db.rawQuery('PRAGMA table_info(records)');
          if (!cols.any((c) => c['name'] == 'dedupe_key')) {
            await db.execute('ALTER TABLE records ADD COLUMN dedupe_key TEXT');
          }
          await db.execute('''
            UPDATE records SET dedupe_key =
              CASE
                WHEN TRIM(COALESCE(vehicle,'')) = ''
                 AND TRIM(COALESCE(chassis,'')) = ''
                THEN 'id:' || id
                ELSE UPPER(TRIM(COALESCE(vehicle,''))) || '|' ||
                     UPPER(TRIM(COALESCE(chassis,'')))
              END
          ''');
          await db.execute('''
            DELETE FROM records WHERE rowid NOT IN (
              SELECT MAX(rowid) FROM records GROUP BY dedupe_key
            )
          ''');
          await db.execute(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_dedupe ON records(dedupe_key)');
        }
      },
    );
  }

  static String _tail(dynamic value, int n) {
    final s = (value?.toString() ?? '').trim().toUpperCase();
    return s.length <= n ? s : s.substring(s.length - n);
  }

  static String _keyOf(Map<String, dynamic> it) {
    final a = it['_id']?.toString() ?? '';
    if (a.isNotEmpty) return a;
    return it['searchRowId']?.toString() ?? '';
  }

  static String _norm(dynamic v) =>
      (v?.toString() ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static String _dedupeKey(Map<String, dynamic> it, String id) {
    final v = _norm(it['vehicleNumber']);
    final c = _norm(it['chassisNumber']);
    if (v.isNotEmpty) return 'v:$v';   // vehicle hi asli identity
    if (c.isNotEmpty) return 'c:$c';
    return 'id:$id';
  }

  Future<void> upsert(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    final db = await _database;
    final prepared = await compute(_prepareRows, items);

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final row in prepared) {
        batch.insert('records', row,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> count() async {
    final db = await _database;
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM records');
    return (r.first['c'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> search({
    required bool isVehicle,
    required String digits,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'records',
      columns: ['dedupe_key', 'json'],
      where: isVehicle ? 'vehicle_last4 = ?' : 'chassis_last6 = ?',
      whereArgs: [digits.trim().toUpperCase()],
      orderBy: 'rowid DESC',
      limit: _maxResults,
    );

    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      final key = (r['dedupe_key'] ?? '').toString();
      if (key.isNotEmpty && !seen.add(key)) continue;
      out.add(Map<String, dynamic>.from(jsonDecode(r['json'] as String)));
    }
    if (kDebugMode) {
      debugPrint('[SEARCH] digits=$digits dbRows=${rows.length} afterDedupe=${out.length}');
      for (final r in rows) {
        debugPrint('  key=${r['dedupe_key']}');
      }
    }
    return out;
  }

  Future<void> clear() async {
    final db = await _database;
    await db.delete('records');
  }
}

List<Map<String, Object?>> _prepareRows(List<Map<String, dynamic>> items) {
  final out = <Map<String, Object?>>[];
  for (final it in items) {
    final id = OfflineDb._keyOf(it);
    if (id.isEmpty) continue;
    out.add({
      'id': id,
      'row_id': int.tryParse('${it['searchRowId']}'),
      'vehicle': it['vehicleNumber']?.toString(),
      'vehicle_last4':
      OfflineDb._tail(it['vehicleNumber'], OfflineDb.vehicleDigits),
      'chassis': it['chassisNumber']?.toString(),
      'chassis_last6':
      OfflineDb._tail(it['chassisNumber'], OfflineDb.chassisDigits),
      'dedupe_key': OfflineDb._dedupeKey(it, id),
      'json': jsonEncode(it),
    });
  }
  return out;
}