/// SQLite store — local-first storage for CogniTrack mobile.
/// Mirrors the desktop's sqliteStore.ts schema exactly.
library;

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../cognitive_engine/models.dart';

// ─── Row types ───────────────────────────────────────────────────────────────

class RawEventInsert {
  final int timestamp;
  final String appId;
  final String category;
  final String eventType;
  final int durationMs;
  final String deviceType;

  const RawEventInsert({
    required this.timestamp,
    required this.appId,
    required this.category,
    required this.eventType,
    required this.durationMs,
    this.deviceType = 'phone',
  });

  Map<String, dynamic> toMap() => {
        'timestamp': timestamp,
        'appId': appId,
        'category': category,
        'eventType': eventType,
        'durationMs': durationMs,
        'deviceType': deviceType,
      };
}

class DailyMetricsRow {
  final String date;
  final double cognitiveDebt;
  final double cognitiveLoadPct;
  final double wmCapacityRemaining;
  final double residueAtEOD;
  final int totalSwitches;
  final int totalPickups;
  final double totalScreenTime; // hours
  final double switchVelocityPeak;
  // BUG-08: nullable — -1 is the SQLite sentinel meaning "no events today".
  // fromMap converts -1 → null; toMap converts null → -1.
  final int? peakLoadHour;
  final String hourlyLoad; // JSON array [24 numbers]
  final String categoryBreakdown; // JSON object
  final int synced; // 0 = pending, 1 = synced
  final int updatedAt;

  const DailyMetricsRow({
    required this.date,
    required this.cognitiveDebt,
    required this.cognitiveLoadPct,
    required this.wmCapacityRemaining,
    required this.residueAtEOD,
    required this.totalSwitches,
    required this.totalPickups,
    required this.totalScreenTime,
    required this.switchVelocityPeak,
    required this.peakLoadHour,
    required this.hourlyLoad,
    required this.categoryBreakdown,
    required this.synced,
    required this.updatedAt,
  });

  factory DailyMetricsRow.fromMap(Map<String, dynamic> m) => DailyMetricsRow(
        date: m['date'] as String,
        cognitiveDebt: (m['cognitiveDebt'] as num).toDouble(),
        cognitiveLoadPct: (m['cognitiveLoadPct'] as num).toDouble(),
        wmCapacityRemaining: (m['wmCapacityRemaining'] as num).toDouble(),
        residueAtEOD: (m['residueAtEOD'] as num).toDouble(),
        totalSwitches: m['totalSwitches'] as int,
        totalPickups: m['totalPickups'] as int? ?? 0,
        totalScreenTime: (m['totalScreenTime'] as num?)?.toDouble() ?? 0,
        switchVelocityPeak: (m['switchVelocityPeak'] as num).toDouble(),
        // BUG-08: -1 is the sentinel stored for "no events" days.
        peakLoadHour: (m['peakLoadHour'] as int) == -1
            ? null
            : (m['peakLoadHour'] as int),
        hourlyLoad: m['hourlyLoad'] as String,
        categoryBreakdown: m['categoryBreakdown'] as String,
        synced: m['synced'] as int,
        updatedAt: m['updatedAt'] as int,
      );

  Map<String, dynamic> toMap() => {
        'date': date,
        'cognitiveDebt': cognitiveDebt,
        'cognitiveLoadPct': cognitiveLoadPct,
        'wmCapacityRemaining': wmCapacityRemaining,
        'residueAtEOD': residueAtEOD,
        'totalSwitches': totalSwitches,
        'totalPickups': totalPickups,
        'totalScreenTime': totalScreenTime,
        'switchVelocityPeak': switchVelocityPeak,
        // BUG-08: store -1 for null (no-events day); never a valid clock hour
        'peakLoadHour': peakLoadHour ?? -1,
        'hourlyLoad': hourlyLoad,
        'categoryBreakdown': categoryBreakdown,
        'synced': synced,
        'updatedAt': updatedAt,
      };

  List<double> get hourlyLoadList => (jsonDecode(hourlyLoad) as List)
      .map((e) => (e as num).toDouble())
      .toList();

  CategoryBreakdown get categoryBreakdownObj => CategoryBreakdown.fromMap(
      jsonDecode(categoryBreakdown) as Map<String, dynamic>);
}

class PendingSyncRow {
  final int? id;
  final String date;
  final String payload; // JSON PhoneSyncPayload
  final int retryCount;
  final int nextRetryAt;

  const PendingSyncRow({
    this.id,
    required this.date,
    required this.payload,
    required this.retryCount,
    required this.nextRetryAt,
  });

  factory PendingSyncRow.fromMap(Map<String, dynamic> m) => PendingSyncRow(
        id: m['id'] as int?,
        date: m['date'] as String,
        payload: m['payload'] as String,
        retryCount: m['retryCount'] as int,
        nextRetryAt: m['nextRetryAt'] as int,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'payload': payload,
        'retryCount': retryCount,
        'nextRetryAt': nextRetryAt,
      };
}

// ─── SQLiteStore ─────────────────────────────────────────────────────────────

/// Crash-safe local storage for CogniTrack mobile agent.
/// Uses sqflite with WAL journal mode for power-loss safety.
///
/// Tables:
///   app_events       — raw tracking events; 7-day TTL
///   daily_metrics    — computed 11-scalar summaries ready for Firestore sync
///   pending_sync     — offline queue with exponential backoff
class SQLiteStore {
  final String _dbName;
  static const _dbVersion = 1;
  static const _sevenDaysMs = 604800000; // 7 * 24 * 60 * 60 * 1000

  Database? _db;

  SQLiteStore({String dbName = 'cognitrack.db'}) : _dbName = dbName;

  Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onOpen: (db) async {
        // WAL mode for write safety
        await db.execute('PRAGMA journal_mode=WAL');
        await db.execute('PRAGMA foreign_keys=ON');
        await db.execute('PRAGMA synchronous=NORMAL');
        // Enforce 7-day TTL once at startup rather than on every insert.
        // insertEvent() is called up to 100× per minute on Android (60-second
        // poll cycle returning 20–100 UsageStats events). Running a full-table
        // DELETE scan on every insert wastes CPU and IO unnecessarily.
        await db.delete(
          'app_events',
          where: 'timestamp < ?',
          whereArgs: [
            DateTime.now().millisecondsSinceEpoch - _sevenDaysMs,
          ],
        );
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── Raw events (local-only, 7-day TTL) ──────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_events (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp   INTEGER NOT NULL,
        appId       TEXT    NOT NULL,
        category    TEXT    NOT NULL,
        eventType   TEXT    NOT NULL,
        durationMs  INTEGER NOT NULL DEFAULT 0,
        deviceType  TEXT    NOT NULL DEFAULT 'phone'
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_events_timestamp
        ON app_events(timestamp)
    ''');

    // ── Daily metrics (synced to Firestore as 11 scalars) ───────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_metrics (
        date                TEXT    PRIMARY KEY,
        cognitiveDebt       REAL    NOT NULL DEFAULT 0,
        cognitiveLoadPct    REAL    NOT NULL DEFAULT 0,
        wmCapacityRemaining REAL    NOT NULL DEFAULT 100,
        residueAtEOD        REAL    NOT NULL DEFAULT 0,
        totalSwitches       INTEGER NOT NULL DEFAULT 0,
        totalPickups        INTEGER NOT NULL DEFAULT 0,
        totalScreenTime     REAL    NOT NULL DEFAULT 0,
        switchVelocityPeak  REAL    NOT NULL DEFAULT 0,
        peakLoadHour        INTEGER NOT NULL DEFAULT 0,
        hourlyLoad          TEXT    NOT NULL DEFAULT '[]',
        categoryBreakdown   TEXT    NOT NULL DEFAULT '{}',
        synced              INTEGER NOT NULL DEFAULT 0,
        updatedAt           INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_daily_metrics_date
        ON daily_metrics(date DESC)
    ''');

    // ── Offline sync queue with backoff ──────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_sync (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        date        TEXT    NOT NULL,
        payload     TEXT    NOT NULL,
        retryCount  INTEGER NOT NULL DEFAULT 0,
        nextRetryAt INTEGER NOT NULL
      )
    ''');
  }

  // ── Raw Events ─────────────────────────────────────────────────────────────

  /// Insert a single raw app event.
  /// TTL enforcement (7-day cleanup) is handled once at DB open, not per insert.
  Future<void> insertEvent(RawEventInsert event) async {
    final db = await _database;
    await db.insert('app_events', event.toMap());
  }

  /// Fetch all raw events for a given date (local midnight → next midnight).
  Future<List<AppEvent>> getEventsForDate(String date) async {
    final db = await _database;
    final start = DateTime.parse(date)
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    final end = start.add(const Duration(days: 1));

    final rows = await db.query(
      'app_events',
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'timestamp ASC',
    );

    return rows
        .map((r) => AppEvent(
              id: r['id'].toString(),
              timestamp: r['timestamp'] as int,
              appId: r['appId'] as String,
              category: Category.fromString(r['category'] as String),
              durationMs: r['durationMs'] as int,
              eventType: EventTypeExt.fromString(r['eventType'] as String),
              deviceType: DeviceType.values.firstWhere(
                (d) => d.name == (r['deviceType'] as String),
                orElse: () => DeviceType.phone,
              ),
            ))
        .toList();
  }

  /// Count of raw switch events today.
  Future<int> getSwitchCountToday() async {
    final db = await _database;
    final today =
        DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM app_events WHERE timestamp >= ? AND eventType = 'switch'",
      [today.millisecondsSinceEpoch],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Count of pickup events today.
  Future<int> getPickupCountToday() async {
    final db = await _database;
    final today =
        DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM app_events WHERE timestamp >= ? AND eventType = 'pickup'",
      [today.millisecondsSinceEpoch],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  // ── Daily Metrics ──────────────────────────────────────────────────────────

  /// Upsert computed daily metrics for a given date.
  Future<void> upsertDailyMetrics(DailyMetricsRow metrics) async {
    final db = await _database;
    await db.insert(
      'daily_metrics',
      {
        ...metrics.toMap(),
        'synced': 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Fetch daily metrics row for a specific date. Null if not yet computed.
  Future<DailyMetricsRow?> getDailyMetrics(String date) async {
    final db = await _database;
    final rows = await db.query(
      'daily_metrics',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (rows.isEmpty) return null;
    return DailyMetricsRow.fromMap(rows.first);
  }

  /// Fetch all unsynced daily metrics (synced = 0).
  Future<List<DailyMetricsRow>> getUnsyncedMetrics() async {
    final db = await _database;
    final rows = await db.query(
      'daily_metrics',
      where: 'synced = 0',
      orderBy: 'date DESC',
    );
    return rows.map(DailyMetricsRow.fromMap).toList();
  }

  /// Mark a date's metrics as successfully synced to Firestore.
  Future<void> markSynced(String date) async {
    final db = await _database;
    await db.update(
      'daily_metrics',
      {'synced': 1, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  /// Fetch last N days of daily metrics for history chart.
  Future<List<DailyMetricsRow>> getMetricsHistory({int days = 7}) async {
    final db = await _database;
    final rows = await db.query(
      'daily_metrics',
      orderBy: 'date DESC',
      limit: days,
    );
    return rows.map(DailyMetricsRow.fromMap).toList();
  }

  // ── Pending Sync Queue ─────────────────────────────────────────────────────

  /// Enqueue a sync payload for retry.
  Future<void> enqueuePendingSync(PendingSyncRow row) async {
    final db = await _database;
    await db.insert('pending_sync', row.toMap());
  }

  /// Fetch all pending syncs ready to retry (nextRetryAt <= now).
  Future<List<PendingSyncRow>> getReadyPendingSyncs() async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'pending_sync',
      where: 'nextRetryAt <= ?',
      whereArgs: [now],
      orderBy: 'nextRetryAt ASC',
    );
    return rows.map(PendingSyncRow.fromMap).toList();
  }

  /// Fetch a pending sync entry by date.
  Future<PendingSyncRow?> getPendingSyncForDate(String date) async {
    final db = await _database;
    final rows = await db.query(
      'pending_sync',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (rows.isEmpty) return null;
    return PendingSyncRow.fromMap(rows.first);
  }

  /// Remove a pending sync entry after successful delivery.
  Future<void> deletePendingSync(int id) async {
    final db = await _database;
    await db.delete('pending_sync', where: 'id = ?', whereArgs: [id]);
  }

  /// Update retry count and next retry time for a failed sync.
  Future<void> updatePendingSyncRetry(int id, int retryCount,
      {int? nextRetryAt}) async {
    final db = await _database;
    final delay = nextRetryAt ??
        (DateTime.now().millisecondsSinceEpoch +
            30000 * (1 << (retryCount - 1)));
    await db.update(
      'pending_sync',
      {
        'retryCount': retryCount,
        'nextRetryAt': nextRetryAt ?? delay,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// B2 FIX: Replace the payload of an existing pending-sync row with a
  /// fresher one, while preserving the existing retryCount and backoff
  /// schedule. Called by _enqueuePendingSync() when the device stays offline
  /// across multiple 15-min sync cycles so the final reconnect push sends
  /// end-of-day data rather than the stale 09:00 snapshot.
  Future<void> updatePendingSyncPayload(int id, String payload) async {
    final db = await _database;
    await db.update(
      'pending_sync',
      {'payload': payload},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Fetch break events for a specific date from app_events.
  Future<List<AppEvent>> getBreaksForDate(String date) async {
    final db = await _database;
    final start = DateTime.parse(date)
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    final end = start.add(const Duration(days: 1));

    final rows = await db.query(
      'app_events',
      where: "timestamp >= ? AND timestamp < ? AND eventType = 'break'",
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'timestamp ASC',
    );

    return rows
        .map((r) => AppEvent(
              id: r['id'].toString(),
              timestamp: r['timestamp'] as int,
              appId: r['appId'] as String,
              category: Category.fromString(r['category'] as String),
              durationMs: r['durationMs'] as int,
              eventType: EventTypeExt.fromString(r['eventType'] as String),
              deviceType: DeviceType.values.firstWhere(
                (d) => d.name == (r['deviceType'] as String),
                orElse: () => DeviceType.phone,
              ),
            ))
        .toList();
  }

  /// Fetch metrics for a date range (inclusive) — for week-over-week comparison.
  Future<List<DailyMetricsRow>> getMetricsRange(String from, String to) async {
    final db = await _database;
    final rows = await db.query(
      'daily_metrics',
      where: "date >= ? AND date <= ?",
      whereArgs: [from, to],
      orderBy: 'date ASC',
    );
    return rows.map(DailyMetricsRow.fromMap).toList();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
