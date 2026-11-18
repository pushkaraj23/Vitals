import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vitals/data/mock/flag_engine.dart';
import 'package:vitals/data/mock/mock_data_generator.dart';
import 'package:vitals/data/mock/personas.dart';
import 'package:vitals/data/mock/rules_loader.dart';
import 'package:vitals/domain/models/daily_reading.dart';
import 'package:vitals/domain/models/enums.dart';
import 'package:vitals/domain/models/flag.dart';
import 'package:vitals/domain/models/rule.dart';

const engine = FlagEngine();

Rule makeRule(
  VitalMetric metric, {
  int minDays = 7,
  double minDelta = 3,
  List<HereditaryModifier> modifiers = const [],
}) {
  return Rule(
    id: 'test_${metric.name}',
    name: 'Test ${metric.label}',
    summary: 'test',
    metrics: [metric],
    minDurationDays: minDays,
    thresholds: RuleThresholds(
      sigma: 2,
      redSigma: 3.5,
      redDays: 14,
      minDelta: minDelta,
    ),
    symptoms: const [],
    impactsPhysical: const [],
    impactsMental: const [],
    remedies: const [],
    specialist: 'General physician',
    sources: const [],
    hereditaryModifiers: modifiers,
  );
}

/// Builds a series for [metric]: [stableDays] around [mean], then [tail]
/// (values or `null` for a gap) appended.
List<DailyReading> series(
  VitalMetric metric, {
  required double mean,
  required double noise,
  int stableDays = 100,
  List<double?> tail = const [],
}) {
  final rng = math.Random(42);
  final start = DateTime(2026, 1, 1);
  final readings = <DailyReading>[];
  for (var i = 0; i < stableDays; i++) {
    readings.add(
      DailyReading.fromValues(DateTime(start.year, start.month, start.day + i), {
        metric: mean + (rng.nextDouble() * 2 - 1) * noise,
      }),
    );
  }
  for (var j = 0; j < tail.length; j++) {
    final date = DateTime(start.year, start.month, start.day + stableDays + j);
    final value = tail[j];
    readings.add(
      value == null
          ? DailyReading.gap(date)
          : DailyReading.fromValues(date, {metric: value}),
    );
  }
  return readings;
}

void main() {
  group('baseline', () {
    test('rolling band uses mean and stddev and ignores gaps', () {
      final data = series(
        VitalMetric.hrv,
        mean: 50,
        noise: 3,
        tail: [null, null, null],
      );
      final baseline = engine.computeBaseline(data, VitalMetric.hrv);
      expect(baseline.hasData, isTrue);
      // A zero-filled gap would drag this well below 50.
      expect(baseline.mean, closeTo(50, 1.5));
      expect(baseline.stdDev, greaterThan(0));
      expect(baseline.low, lessThan(baseline.mean));
      expect(baseline.high, greaterThan(baseline.mean));
      expect(baseline.series, isNotEmpty);
    });

    test('too little history yields an insufficient baseline', () {
      final data = series(
        VitalMetric.hrv,
        mean: 50,
        noise: 3,
        stableDays: 10,
      );
      expect(engine.computeBaseline(data, VitalMetric.hrv).hasData, isFalse);
    });
  });

  group('drift detection', () {
    test('sustained rise in resting HR is flagged', () {
      final data = series(
        VitalMetric.restingHr,
        mean: 60,
        noise: 1.5,
        tail: List.filled(20, 70.0),
      );
      final flag = engine.evaluateRule(
        data,
        makeRule(VitalMetric.restingHr),
      );
      expect(flag.status, isNot(FlagStatus.green));
      expect(flag.streakDays, 20);
      expect(flag.startedOn, data[data.length - 20].date);
      expect(flag.meanDeviation, closeTo(10, 1.5));
      expect(flag.summary, contains('higher than your usual range'));
      // Descriptive language only.
      expect(flag.summary.toLowerCase(), isNot(contains('diagnos')));
      expect(flag.summary, isNot(contains('%')));
    });

    test('long, large drift escalates to red', () {
      final data = series(
        VitalMetric.restingHr,
        mean: 60,
        noise: 1.5,
        tail: List.filled(20, 72.0),
      );
      final flag = engine.evaluateRule(data, makeRule(VitalMetric.restingHr));
      expect(flag.status, FlagStatus.red);
    });

    test('a lower-is-worse metric flags when it drops', () {
      final data = series(
        VitalMetric.hrv,
        mean: 50,
        noise: 3,
        tail: List.filled(10, 35.0),
      );
      final flag = engine.evaluateRule(
        data,
        makeRule(VitalMetric.hrv, minDelta: 6),
      );
      expect(flag.status, isNot(FlagStatus.green));
      expect(flag.summary, contains('lower than your usual range'));
    });

    test('moving in the healthy direction is not flagged', () {
      final data = series(
        VitalMetric.restingHr,
        mean: 60,
        noise: 1.5,
        tail: List.filled(20, 50.0),
      );
      final flag = engine.evaluateRule(data, makeRule(VitalMetric.restingHr));
      expect(flag.status, FlagStatus.green);
    });
  });

  group('persistence rule', () {
    final rule = makeRule(VitalMetric.restingHr);

    test('too few days outside range stays green', () {
      final data = series(
        VitalMetric.restingHr,
        mean: 60,
        noise: 1.5,
        tail: List.filled(4, 70.0),
      );
      expect(engine.evaluateRule(data, rule).status, FlagStatus.green);
    });

    test('exactly the minimum duration turns amber', () {
      final data = series(
        VitalMetric.restingHr,
        mean: 60,
        noise: 1.5,
        tail: List.filled(7, 70.0),
      );
      final flag = engine.evaluateRule(data, rule);
      expect(flag.status, FlagStatus.amber);
      expect(flag.streakDays, 7);
    });

    test('one day short of the minimum stays green', () {
      final data = series(
        VitalMetric.restingHr,
        mean: 60,
        noise: 1.5,
        tail: List.filled(6, 70.0),
      );
      expect(engine.evaluateRule(data, rule).status, FlagStatus.green);
    });

    test('a pattern that recovered no longer flags', () {
      final data = series(
        VitalMetric.restingHr,
        mean: 60,
        noise: 1.5,
        tail: [...List.filled(10, 70.0), 60.0, 60.5, 59.5],
      );
      expect(engine.evaluateRule(data, rule).status, FlagStatus.green);
    });

    test('a single in-range day inside a pattern does not reset it', () {
      final data = series(
        VitalMetric.restingHr,
        mean: 60,
        noise: 1.5,
        tail: [...List.filled(5, 70.0), 60.0, ...List.filled(5, 70.0)],
      );
      final flag = engine.evaluateRule(data, rule);
      expect(flag.status, FlagStatus.amber);
      expect(flag.streakDays, 10);
    });

    test('a matching family-history tag surfaces the pattern sooner', () {
      final modifiers = [
        const HereditaryModifier(
          tag: 'cardiovascular',
          label: 'Family history',
          note: 'Sensitivity only.',
          minDurationDeltaDays: -2,
        ),
      ];
      final data = series(
        VitalMetric.restingHr,
        mean: 60,
        noise: 1.5,
        tail: List.filled(5, 70.0),
      );
      final withModifier = makeRule(VitalMetric.restingHr, modifiers: modifiers);
      expect(engine.evaluateRule(data, withModifier).status, FlagStatus.green);
      final flag = engine.evaluateRule(
        data,
        withModifier,
        hereditaryTags: const {'cardiovascular'},
      );
      expect(flag.status, FlagStatus.amber);
      expect(flag.contextNote, 'Sensitivity only.');
    });
  });

  group('gaps', () {
    test('gap days are not treated as zero', () {
      // If gaps were zeros, HRV would look like a collapse and flag red.
      final data = series(
        VitalMetric.hrv,
        mean: 50,
        noise: 3,
        tail: [...List.filled(5, 50.0), ...List.filled(8, null)],
      );
      expect(data.where((r) => r.isGap).every((r) => r.hrv == null), isTrue);
      final flag = engine.evaluateRule(
        data,
        makeRule(VitalMetric.hrv, minDelta: 6),
      );
      expect(flag.status, FlagStatus.green);
      expect(flag.currentValue, closeTo(50, 0.001));
    });

    test('gaps inside a pattern neither count nor break it', () {
      final data = series(
        VitalMetric.restingHr,
        mean: 60,
        noise: 1.5,
        tail: [
          ...List.filled(4, 70.0),
          null,
          null,
          null,
          ...List.filled(5, 70.0),
        ],
      );
      final flag = engine.evaluateRule(data, makeRule(VitalMetric.restingHr));
      expect(flag.status, FlagStatus.amber);
      expect(flag.streakDays, 9); // 9 real days; the 3 gaps are ignored
    });

    test('trailing gaps do not hide an ongoing pattern', () {
      final data = series(
        VitalMetric.restingHr,
        mean: 60,
        noise: 1.5,
        tail: [...List.filled(9, 70.0), null, null],
      );
      final flag = engine.evaluateRule(data, makeRule(VitalMetric.restingHr));
      expect(flag.status, FlagStatus.amber);
      expect(flag.streakDays, 9);
    });
  });

  group('mock data generator', () {
    final end = DateTime(2026, 6, 1);
    const generator = MockDataGenerator();

    test('is deterministic', () {
      final a = generator.generate(Personas.rahul, end: end);
      final b = generator.generate(Personas.rahul, end: end);
      expect(a.length, 180);
      expect(a, b);
    });

    test('has ~3% gaps with null values, never zeros', () {
      final data = generator.generate(Personas.rahul, end: end);
      final gaps = data.where((r) => r.isGap).toList();
      expect(gaps.length, inInclusiveRange(3, 8));
      for (final gap in gaps) {
        for (final metric in VitalMetric.values) {
          expect(gap.valueOf(metric), isNull);
        }
      }
      expect(data.last.isGap, isFalse);
      for (final r in data.where((r) => !r.isGap)) {
        expect(r.restingHr, isNotNull);
        expect(r.restingHr, greaterThan(0));
      }
    });

    test('weekends differ from weekdays (day-of-week pattern)', () {
      final data = generator.generate(Personas.meera, end: end);
      double mean(Iterable<DailyReading> r) =>
          r.map((e) => e.sleepDuration!).reduce((a, b) => a + b) / r.length;
      final valid = data.where((r) => !r.isGap);
      final weekend = valid.where((r) => r.date.weekday >= 6);
      final weekday = valid.where((r) => r.date.weekday < 6);
      expect(mean(weekend), greaterThan(mean(weekday)));
    });
  });

  group('persona stories', () {
    final rules = RulesLoader.parse(
      File('assets/rules/rules.json').readAsStringSync(),
    );
    final end = DateTime(2026, 6, 1);
    const generator = MockDataGenerator();

    Map<String, Flag> flagsFor(Persona persona) {
      final data = generator.generate(persona, end: end);
      final flags = engine.evaluateAll(
        data,
        rules,
        hereditaryTags: persona.profile.familyHistoryTags.toSet(),
      );
      return {for (final f in flags) f.ruleId: f};
    }

    test('Rahul has red and amber flags', () {
      final flags = flagsFor(Personas.rahul);
      expect(flags['resting_hr_drift']!.status, FlagStatus.red);
      expect(flags['hrv_decline']!.status, FlagStatus.red);
      expect(flags['sleep_fragmentation']!.status, FlagStatus.amber);
      expect(flags['low_deep_sleep']!.status, FlagStatus.amber);
      expect(flags['low_activity']!.status, FlagStatus.amber);
      expect(flags['spo2_dips']!.status, FlagStatus.green);
    });

    test('Meera stays green, including a short dip in steps', () {
      final flags = flagsFor(Personas.meera);
      for (final flag in flags.values) {
        expect(flag.status, FlagStatus.green, reason: flag.ruleId);
      }
    });
  });
}
