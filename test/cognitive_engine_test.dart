import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:cognitrack_mobile/core/cognitive_engine/models.dart';
import 'package:cognitrack_mobile/core/cognitive_engine/constants.dart';
import 'package:cognitrack_mobile/core/cognitive_engine/residue_decay.dart';
import 'package:cognitrack_mobile/core/cognitive_engine/velocity_multiplier.dart';
import 'package:cognitrack_mobile/core/cognitive_engine/cognitive_engine.dart';
import 'package:cognitrack_mobile/core/cognitive_engine/app_normalizer.dart';

void main() {
  const t0 = 1700000000000;

  AppEvent makeEvent({
    required int timestamp,
    required EventType type,
    Category cat = Category.productive,
  }) =>
      AppEvent(
        id: '$timestamp',
        timestamp: timestamp,
        appId: 'android.notion',
        category: cat,
        durationMs: 0,
        eventType: type,
        deviceType: DeviceType.phone,
      );

  group('decayResidue', () {
    test('decays to ~37% at one tau', () {
      expect(decayResidue(1.0, tauMs), closeTo(exp(-1), 0.001));
    });
    test('fully recovers at 23 min', () {
      expect(decayResidue(1.0, 23 * 60 * 1000), lessThan(0.06));
    });
    test('zero residue stays zero', () {
      expect(decayResidue(0.0, 60000), closeTo(0.0, 0.0001));
    });
  });

  group('computeVelocityMultiplier', () {
    test('1 switch/min → 1.0', () => expect(computeVelocityMultiplier(1.0), closeTo(1.0, 0.001)));
    test('4 switches/min → 2.5 cap', () => expect(computeVelocityMultiplier(4.0), closeTo(2.5, 0.001)));
    test('2.5 switches/min → 1.75', () => expect(computeVelocityMultiplier(2.5), closeTo(1.75, 0.001)));
  });

  group('contextDistance matrix', () {
    test('passiveWaste→productive = 9.0', () {
      expect(contextDistance[Category.passiveWaste]?[Category.productive], equals(9.0));
    });
    test('productive→passiveWaste = 7.0', () {
      expect(contextDistance[Category.productive]?[Category.passiveWaste], equals(7.0));
    });
    test('matrix is asymmetric', () {
      final pwP = contextDistance[Category.passiveWaste]?[Category.productive];
      final pPw = contextDistance[Category.productive]?[Category.passiveWaste];
      expect(pwP, isNot(equals(pPw)));
    });
  });

  group('calculateCognitiveDebt', () {
    test('empty events → zero report', () {
      final r = calculateCognitiveDebt([]);
      expect(r.cognitiveDebt, equals(0));
      expect(r.wmCapacityRemaining, equals(wmInitial));
      expect(r.hourlyDebt.length, equals(24));
    });

    test('passiveWaste→productive produces more debt than productive→productive', () {
      final low = calculateCognitiveDebt([
        makeEvent(timestamp: t0, type: EventType.switch_, cat: Category.productive),
        makeEvent(timestamp: t0 + 60000, type: EventType.switch_, cat: Category.productive),
      ]);
      final high = calculateCognitiveDebt([
        makeEvent(timestamp: t0, type: EventType.switch_, cat: Category.passiveWaste),
        makeEvent(timestamp: t0 + 60000, type: EventType.switch_, cat: Category.productive),
      ]);
      expect(high.cognitiveDebt, greaterThan(low.cognitiveDebt));
    });

    test('cognitiveLoadPct capped at 100 under heavy load', () {
      final events = List.generate(200, (i) => makeEvent(
        timestamp: t0 + i * 10000,
        type: EventType.switch_,
        cat: i.isEven ? Category.passiveWaste : Category.productive,
      ));
      expect(calculateCognitiveDebt(events).cognitiveLoadPct, lessThanOrEqualTo(100));
    });

    test('sustained productive focus ≥20 min rewards WM', () {
      final events = [
        makeEvent(timestamp: t0, type: EventType.switch_, cat: Category.productive),
        makeEvent(timestamp: t0 + 5 * 60000, type: EventType.pickup, cat: Category.productive),
        makeEvent(timestamp: t0 + 10 * 60000, type: EventType.pickup, cat: Category.productive),
        makeEvent(timestamp: t0 + 20 * 60000, type: EventType.pickup, cat: Category.productive),
      ];
      final r = calculateCognitiveDebt(events);
      expect(r.wmCapacityRemaining, greaterThanOrEqualTo(wmInitial - 10));
    });

    test('hourlyDebt is 24 elements, all 0–100', () {
      final events = List.generate(5, (i) => makeEvent(
        timestamp: t0 + i * 30000,
        type: EventType.switch_,
        cat: i.isEven ? Category.social : Category.productive,
      ));
      final r = calculateCognitiveDebt(events);
      expect(r.hourlyDebt.length, equals(24));
      for (final h in r.hourlyDebt) {
        expect(h, inInclusiveRange(0, 100));
      }
    });
  });

  group('normalizeAppId + resolveCategory', () {
    test('com.instagram.android → android.instagram → social', () {
      final id = normalizeAppId('com.instagram.android', Platform.android);
      expect(id, equals('android.instagram'));
      expect(resolveCategory(id), equals(Category.social));
    });
    test('com.zhiliaoapp.musically (TikTok) → passiveWaste', () {
      final id = normalizeAppId('com.zhiliaoapp.musically', Platform.android);
      expect(resolveCategory(id), equals(Category.passiveWaste));
    });
    test('com.apple.mobilesafari → ios.safari → tools', () {
      final id = normalizeAppId('com.apple.mobilesafari', Platform.ios);
      expect(resolveCategory(id), equals(Category.tools));
    });
    test('unknown package → tools default', () {
      final id = normalizeAppId('com.unknown.app', Platform.android);
      expect(resolveCategory(id), equals(Category.tools));
    });
  });
}
