import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cognitrack_mobile/core/database/sqlite_store.dart';
import 'package:cognitrack_mobile/core/cognitive_engine/models.dart';

void main() {
  setUpAll(() {
    // Use in-memory SQLite for tests
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late SQLiteStore store;

  setUp(() async {
    store = SQLiteStore(dbName: inMemoryDatabasePath);
  });

  tearDown(() async {
    await store.close();
  });

  group('SQLiteStore — app_events', () {
    test('insertEvent and getEventsForDate round-trips correctly', () async {
      final now = DateTime(2024, 11, 14, 10, 30).millisecondsSinceEpoch;
      await store.insertEvent(RawEventInsert(
        timestamp: now,
        appId: 'android.instagram',
        category: 'social',
        eventType: 'switch',
        durationMs: 30000,
      ));

      final events = await store.getEventsForDate('2024-11-14');
      expect(events.length, equals(1));
      expect(events.first.appId, equals('android.instagram'));
      expect(events.first.category, equals(Category.social));
      expect(events.first.eventType, equals(EventType.switch_));
      expect(events.first.durationMs, equals(30000));
    });

    test('getEventsForDate filters by date boundary', () async {
      final day1 = DateTime(2024, 11, 14, 12, 0).millisecondsSinceEpoch;
      final day2 = DateTime(2024, 11, 15, 12, 0).millisecondsSinceEpoch;

      await store.insertEvent(RawEventInsert(
        timestamp: day1,
        appId: 'android.notion',
        category: 'productive',
        eventType: 'switch',
        durationMs: 0,
      ));
      await store.insertEvent(RawEventInsert(
        timestamp: day2,
        appId: 'android.youtube',
        category: 'entertainment',
        eventType: 'switch',
        durationMs: 0,
      ));

      final day1Events = await store.getEventsForDate('2024-11-14');
      final day2Events = await store.getEventsForDate('2024-11-15');

      expect(day1Events.length, equals(1));
      expect(day2Events.length, equals(1));
      expect(day1Events.first.appId, equals('android.notion'));
      expect(day2Events.first.appId, equals('android.youtube'));
    });

    test('getSwitchCountToday counts only switch events', () async {
      final today = DateTime.now().copyWith(hour: 10).millisecondsSinceEpoch;
      await store.insertEvent(RawEventInsert(
        timestamp: today,
        appId: 'android.chrome',
        category: 'tools',
        eventType: 'switch',
        durationMs: 0,
      ));
      await store.insertEvent(RawEventInsert(
        timestamp: today + 1000,
        appId: 'android.chrome',
        category: 'tools',
        eventType: 'pickup',
        durationMs: 0,
      ));

      final count = await store.getSwitchCountToday();
      expect(count, equals(1));
    });
  });

  group('SQLiteStore — daily_metrics', () {
    test('upsertDailyMetrics and getDailyMetrics round-trip', () async {
      final row = DailyMetricsRow(
        date: '2024-11-14',
        cognitiveDebt: 45.5,
        cognitiveLoadPct: 62.0,
        wmCapacityRemaining: 78.0,
        residueAtEOD: 0.23,
        totalSwitches: 87,
        totalPickups: 34,
        totalScreenTime: 3.5,
        switchVelocityPeak: 2.1,
        peakLoadHour: 14,
        hourlyLoad: '[0,0,0,0,0,0,0,10,20,45,60,80,62,55,70,40,30,20,10,5,0,0,0,0]',
        categoryBreakdown: '{"productive":40,"entertainment":20,"social":30,"passiveWaste":10}',
        synced: 0,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await store.upsertDailyMetrics(row);
      final fetched = await store.getDailyMetrics('2024-11-14');

      expect(fetched, isNotNull);
      expect(fetched!.cognitiveDebt, closeTo(45.5, 0.01));
      expect(fetched.totalSwitches, equals(87));
      expect(fetched.peakLoadHour, equals(14));
    });

    test('upsertDailyMetrics overwrites existing row (UPSERT)', () async {
      final row1 = DailyMetricsRow(
        date: '2024-11-14',
        cognitiveDebt: 30.0,
        cognitiveLoadPct: 40.0,
        wmCapacityRemaining: 90.0,
        residueAtEOD: 0.1,
        totalSwitches: 40,
        totalPickups: 15,
        totalScreenTime: 2.0,
        switchVelocityPeak: 1.0,
        peakLoadHour: 10,
        hourlyLoad: '[]',
        categoryBreakdown: '{}',
        synced: 0,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      final row2 = row1.toMap()..['cognitiveDebt'] = 55.0;

      await store.upsertDailyMetrics(row1);
      await store.upsertDailyMetrics(DailyMetricsRow.fromMap(
          {...row2, 'totalPickups': 15, 'totalScreenTime': 2.0}));

      final fetched = await store.getDailyMetrics('2024-11-14');
      expect(fetched!.cognitiveDebt, closeTo(55.0, 0.01));
    });

    test('getUnsyncedMetrics returns only synced=0 rows', () async {
      await store.upsertDailyMetrics(DailyMetricsRow(
        date: '2024-11-13',
        cognitiveDebt: 20,
        cognitiveLoadPct: 25,
        wmCapacityRemaining: 95,
        residueAtEOD: 0.05,
        totalSwitches: 20,
        totalPickups: 8,
        totalScreenTime: 1.5,
        switchVelocityPeak: 0.5,
        peakLoadHour: 9,
        hourlyLoad: '[]',
        categoryBreakdown: '{}',
        synced: 0,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));
      await store.markSynced('2024-11-13');

      final unsynced = await store.getUnsyncedMetrics();
      expect(unsynced.any((r) => r.date == '2024-11-13'), isFalse);
    });

    test('markSynced sets synced=1', () async {
      await store.upsertDailyMetrics(DailyMetricsRow(
        date: '2024-11-12',
        cognitiveDebt: 10,
        cognitiveLoadPct: 15,
        wmCapacityRemaining: 98,
        residueAtEOD: 0.02,
        totalSwitches: 10,
        totalPickups: 5,
        totalScreenTime: 1.0,
        switchVelocityPeak: 0.3,
        peakLoadHour: 11,
        hourlyLoad: '[]',
        categoryBreakdown: '{}',
        synced: 0,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));
      await store.markSynced('2024-11-12');
      final row = await store.getDailyMetrics('2024-11-12');
      expect(row!.synced, equals(1));
    });
  });

  group('SQLiteStore — pending_sync queue', () {
    test('enqueue and getReadyPendingSyncs works', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await store.enqueuePendingSync(PendingSyncRow(
        date: '2024-11-14',
        payload: '{"test": true}',
        retryCount: 0,
        nextRetryAt: now - 1000, // ready immediately
      ));

      final ready = await store.getReadyPendingSyncs();
      expect(ready.length, equals(1));
      expect(ready.first.date, equals('2024-11-14'));
    });

    test('deletePendingSync removes the row', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await store.enqueuePendingSync(PendingSyncRow(
        date: '2024-11-10',
        payload: '{}',
        retryCount: 0,
        nextRetryAt: now - 1000,
      ));

      final before = await store.getReadyPendingSyncs();
      expect(before.isNotEmpty, isTrue);

      await store.deletePendingSync(before.first.id!);
      final after = await store.getReadyPendingSyncs();
      expect(after.where((r) => r.date == '2024-11-10').isEmpty, isTrue);
    });
  });
}
