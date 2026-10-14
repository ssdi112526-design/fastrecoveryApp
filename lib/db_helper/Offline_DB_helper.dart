// lib/Service/offline_db.dart
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite store for offline-synced repo cases.
/// Vehicle ke last 4 aur chassis ke last 6 digits par index hai,
/// isliye 8 lakh records mein bhi search turant hota hai.
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
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE records(
            id TEXT PRIMARY KEY,
            row_id INTEGER,
            vehicle TEXT,
            vehicle_last4 TEXT,
            chassis TEXT,
            chassis_last6 TEXT,
            json TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_vehicle4 ON records(vehicle_last4)');
        await db.execute('CREATE INDEX idx_chassis6 ON records(chassis_last6)');
      },
    );
  }

  static String _tail(dynamic value, int n) {
    final s = (value?.toString() ?? '').trim().toUpperCase();
    return s.length <= n ? s : s.substring(s.length - n);
  }

  /// Insert/update ek page ke items (ek hi transaction mein).
  Future<void> upsert(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    final db = await _database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final it in items) {
        final id = (it['_id'] ?? it['searchRowId'] ?? '').toString();
        if (id.isEmpty) continue;
        batch.insert(
          'records',
          {
            'id': id,
            'row_id': int.tryParse('${it['searchRowId']}'),
            'vehicle': it['vehicleNumber']?.toString(),
            'vehicle_last4': _tail(it['vehicleNumber'], vehicleDigits),
            'chassis': it['chassisNumber']?.toString(),
            'chassis_last6': _tail(it['chassisNumber'], chassisDigits),
            'json': jsonEncode(it),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> count() async {
    final db = await _database;
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM records');
    return (r.first['c'] as int?) ?? 0;
  }

  /// Offline search. Same shape ki maps return karta hai jo API deti hai,
  /// isliye VehicleItem.fromJson seedha chalega.
  Future<List<Map<String, dynamic>>> search({
    required bool isVehicle,
    required String digits,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'records',
      columns: ['json'],
      where: isVehicle ? 'vehicle_last4 = ?' : 'chassis_last6 = ?',
      whereArgs: [digits.trim().toUpperCase()],
      limit: _maxResults,
    );
    return rows
        .map((r) => Map<String, dynamic>.from(jsonDecode(r['json'] as String)))
        .toList();
  }

  Future<void> clear() async {
    final db = await _database;
    await db.delete('records');
  }
}