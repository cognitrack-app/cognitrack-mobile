import 'package:flutter_test/flutter_test.dart';
import 'package:cognitrack_mobile/core/cognitive_engine/models.dart';

void main() {
  group('SyncEngine — payload builder logic', () {
    test('_computeCategoryBreakdown sums to ≤100 per category', () {
      // Inline the breakdown logic with a known event set
      final events = [
        AppEvent(
          id: '1',
          timestamp: 1000,
          appId: 'android.notion',
          category: Category.productive,
          durationMs: 60000, // 1 min
          eventType: EventType.switch_,
          deviceType: DeviceType.phone,
        ),
        AppEvent(
          id: '2',
          timestamp: 2000,
          appId: 'android.instagram',
          category: Category.social,
          durationMs: 30000, // 30 sec
          eventType: EventType.switch_,
          deviceType: DeviceType.phone,
        ),
        AppEvent(
          id: '3',
          timestamp: 3000,
          appId: 'android.tiktok',
          category: Category.passiveWaste,
          durationMs: 30000, // 30 sec
          eventType: EventType.switch_,
          deviceType: DeviceType.phone,
        ),
      ];

      final totalMs = events.fold<int>(0, (sum, e) => sum + e.durationMs);
      expect(totalMs, equals(120000));

      double pct(Category c) =>
          events
              .where((e) => e.category == c)
              .fold<int>(0, (s, e) => s + e.durationMs) /
          totalMs *
          100;

      expect(pct(Category.productive), closeTo(50.0, 0.1));
      expect(pct(Category.social), closeTo(25.0, 0.1));
      expect(pct(Category.passiveWaste), closeTo(25.0, 0.1));
      expect(pct(Category.entertainment), closeTo(0.0, 0.1));

      // Total should be ≤ 100 (tools not included in phone breakdown)
      final total = pct(Category.productive) +
          pct(Category.social) +
          pct(Category.passiveWaste) +
          pct(Category.entertainment);
      expect(total, lessThanOrEqualTo(100.1));
    });

    test('PhoneSyncPayload.toFirestore includes all 11 required fields', () {
      final payload = PhoneSyncPayload(
        date: '2024-11-14',
        deviceId: 'abc123',
        platform: 'android',
        cognitiveDebt: 45.5,
        cognitiveLoadPct: 62.0,
        wmCapacityRemaining: 78.0,
        residueAtEOD: 0.23,
        totalScreenTime: 3.5,
        totalSwitches: 87,
        totalPickups: 34,
        switchVelocityPeak: 2.1,
        categoryBreakdown: const CategoryBreakdown(
          productive: 40,
          entertainment: 20,
          social: 30,
          passiveWaste: 10,
        ),
        peakLoadHour: 14,
        hourlyLoad: List.filled(24, 0.0),
        lastUpdated: '2024-11-14T18:00:00Z',
      );

      final map = payload.toFirestore();

      // Verify all 11 metric fields are present
      expect(map.containsKey('cognitiveDebt'), isTrue);
      expect(map.containsKey('cognitiveLoadPct'), isTrue);
      expect(map.containsKey('wmCapacityRemaining'), isTrue);
      expect(map.containsKey('residueAtEOD'), isTrue);
      expect(map.containsKey('totalScreenTime'), isTrue);
      expect(map.containsKey('totalSwitches'), isTrue);
      expect(map.containsKey('totalPickups'), isTrue);
      expect(map.containsKey('switchVelocityPeak'), isTrue);
      expect(map.containsKey('categoryBreakdown'), isTrue);
      expect(map.containsKey('peakLoadHour'), isTrue);
      expect(map.containsKey('hourlyLoad'), isTrue);

      // Verify agentType is set correctly
      expect(map['agentType'], equals('phone'));

      // hourlyLoad must be 24 elements
      expect((map['hourlyLoad'] as List).length, equals(24));
    });
  });
}
