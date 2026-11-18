import 'package:flutter_test/flutter_test.dart';
import 'package:vitals/data/repositories/daily_repository.dart';
import 'package:vitals/data/repositories/rule_repository.dart';
import 'package:vitals/data/repositories/user_repository.dart';
import 'package:vitals/engine/vitalwatch_engine.dart';

void main() {
  const engine = VitalWatchEngine();

  final sampleRules = [
    RuleModel(
      id: 'rhr_drift',
      metric: 'restingHr',
      direction: 'up',
      title: 'Resting heart rate drifting up',
      explanation: 'Your resting heart rate has stayed above your baseline.',
      specialist: 'Cardiologist',
      minDeltaAbs: 4.0,
      amberDays: 7,
      redDays: 21,
      minDataDays: 14,
      requires: ['restingHr'],
      symptoms: ['Fatigue'],
      impacts: [const RuleImpactItem(timeframe: '1-3 mo', text: 'Load')],
      remedies: ['Rest'],
      version: 1,
      reviewedBy: 'Dr. Clinician',
    ),
    RuleModel(
      id: 'hrv_decline',
      metric: 'hrv',
      direction: 'down',
      title: 'Heart rate variability declining',
      explanation: 'HRV lower than usual range.',
      specialist: 'Physician',
      minDeltaPct: 15.0,
      amberDays: 7,
      redDays: 21,
      minDataDays: 14,
      requires: ['hrv'],
      symptoms: ['Stress'],
      impacts: [const RuleImpactItem(timeframe: '1-3 mo', text: 'Recovery')],
      remedies: ['Breathing'],
      version: 1,
      reviewedBy: 'Dr. Clinician',
    ),
    RuleModel(
      id: 'spo2_dip',
      metric: 'spo2',
      direction: 'down',
      title: 'Blood oxygen reading dipping',
      explanation: 'Overnight SpO2 dipping.',
      specialist: 'Physician',
      minDeltaAbs: 1.0,
      amberDays: 5,
      redDays: 14,
      minDataDays: 14,
      requires: ['spo2'],
      symptoms: ['Breathless'],
      impacts: [],
      remedies: [],
      version: 1,
      reviewedBy: 'Dr. Clinician',
    ),
  ];

  const standardUser = UserModel(
    uid: 'test_user',
    name: 'Test User',
    email: 'test@example.com',
  );

  String makeDate(int dayIndex) {
    final d = DateTime(2026, 1, 1).add(Duration(days: dayIndex));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  test('Stable user -> green flag with overall_stable', () {
    // 30 days of stable data around 60 bpm RHR and 55 ms HRV
    final daily = List.generate(30, (i) {
      return DailyModel(
        date: makeDate(i),
        restingHr: 60.0 + (i % 2 == 0 ? 0.5 : -0.5),
        hrv: 55.0,
        sleepDeep: 80.0,
        spo2: 98.0,
        steps: 8000.0,
        source: 'synthetic',
      );
    });

    final res = engine.evaluate(
      daily: daily,
      rules: sampleRules,
      user: standardUser,
      now: DateTime(2026, 1, 31),
    );

    expect(res.isCalibrating, isFalse);
    expect(res.flags.length, 1);
    expect(res.flags.first.ruleId, 'overall_stable');
    expect(res.flags.first.level, 'green');
  });

  test('Drifting user -> red flag after 21+ days of sustained deviation', () {
    // First 14 days: 60 bpm.
    // Next 25 days: 70 bpm (delta = +10, exceeds minDeltaAbs 4.0).
    final daily = <DailyModel>[];
    for (var i = 0; i < 14; i++) {
      daily.add(DailyModel(
        date: makeDate(i),
        restingHr: 60.0,
        hrv: 55.0,
        sleepDeep: 80.0,
        spo2: 98.0,
        steps: 8000.0,
        source: 'synthetic',
      ));
    }
    for (var i = 14; i < 39; i++) {
      daily.add(DailyModel(
        date: makeDate(i),
        restingHr: 70.0,
        hrv: 55.0,
        sleepDeep: 80.0,
        spo2: 98.0,
        steps: 8000.0,
        source: 'synthetic',
      ));
    }

    final res = engine.evaluate(
      daily: daily,
      rules: sampleRules,
      user: standardUser,
      now: DateTime(2026, 2, 10),
    );

    expect(res.isCalibrating, isFalse);
    final rhrFlag = res.flags.firstWhere((f) => f.ruleId == 'rhr_drift');
    expect(rhrFlag.level, 'red');
    expect(rhrFlag.severity, 3);
    expect(rhrFlag.durationDays, greaterThanOrEqualTo(21));
  });

  test('<14 days -> calibrating, no amber or red flags', () {
    // Only 8 days of data
    final daily = List.generate(8, (i) {
      return DailyModel(
        date: makeDate(i),
        restingHr: 75.0, // High, but should not flag because calibrating
        hrv: 30.0,
        sleepDeep: 40.0,
        spo2: 93.0,
        steps: 3000.0,
        source: 'synthetic',
      );
    });

    final res = engine.evaluate(
      daily: daily,
      rules: sampleRules,
      user: standardUser,
    );

    expect(res.isCalibrating, isTrue);
    expect(res.calibrationDay, 8);
    expect(res.flags, isEmpty);
  });

  test('Missing required metric -> rule skipped', () {
    // 25 days of data having only restingHr, NO hrv or spo2
    final daily = List.generate(25, (i) {
      return DailyModel(
        date: makeDate(i),
        restingHr: 60.0,
        source: 'synthetic',
      );
    });

    final res = engine.evaluate(
      daily: daily,
      rules: sampleRules,
      user: standardUser,
    );

    expect(res.isCalibrating, isFalse);
    // Since hrv and spo2 are missing from data, hrv_decline and spo2_dip rules must be skipped.
    expect(res.flags.any((f) => f.ruleId == 'hrv_decline'), isFalse);
    expect(res.flags.any((f) => f.ruleId == 'spo2_dip'), isFalse);
  });

  test("Gaps don't count as zero and do not break streak on single gap day", () {
    // 14 days baseline: 60 bpm
    final daily = <DailyModel>[];
    for (var i = 0; i < 14; i++) {
      daily.add(DailyModel(
        date: makeDate(i),
        restingHr: 60.0,
        source: 'synthetic',
      ));
    }
    // 8 days of 68 bpm, with 1 gap day in between
    daily.add(DailyModel(date: makeDate(14), restingHr: 68.0, source: 'synthetic'));
    daily.add(DailyModel(date: makeDate(15), restingHr: 68.0, source: 'synthetic'));
    daily.add(DailyModel(date: makeDate(16), restingHr: 68.0, source: 'synthetic'));
    daily.add(DailyModel(date: makeDate(17), source: 'synthetic')); // GAP day
    daily.add(DailyModel(date: makeDate(18), restingHr: 68.0, source: 'synthetic'));
    daily.add(DailyModel(date: makeDate(19), restingHr: 68.0, source: 'synthetic'));
    daily.add(DailyModel(date: makeDate(20), restingHr: 68.0, source: 'synthetic'));
    daily.add(DailyModel(date: makeDate(21), restingHr: 68.0, source: 'synthetic'));

    final res = engine.evaluate(
      daily: daily,
      rules: sampleRules,
      user: standardUser,
    );

    final rhrFlag = res.flags.firstWhere((f) => f.ruleId == 'rhr_drift');
    // Streak should not be broken by the single gap day!
    expect(rhrFlag.durationDays, greaterThanOrEqualTo(7));
    expect(rhrFlag.level, 'amber');
  });

  test('Hereditary modifier adjusts sensitivity and notes in explanation', () {
    const userWithHypertension = UserModel(
      uid: 'user_hyp',
      familyHistory: [
        FamilyHistoryItem(relation: 'Mother', condition: 'Hypertension', ageAtOnset: 55),
      ],
    );

    // Baseline: 60 bpm
    final daily = <DailyModel>[];
    for (var i = 0; i < 14; i++) {
      daily.add(DailyModel(
        date: makeDate(i),
        restingHr: 60.0,
        source: 'synthetic',
      ));
    }
    // 8 days of 63.5 bpm: delta is 3.5.
    // Standard rule minDeltaAbs is 4.0 -> would NOT fire.
    // With hereditary modifier, minDeltaAbs is 4.0 * 0.8 = 3.2 -> WILL fire!
    for (var i = 14; i < 22; i++) {
      daily.add(DailyModel(
        date: makeDate(i),
        restingHr: 63.5,
        source: 'synthetic',
      ));
    }

    final res = engine.evaluate(
      daily: daily,
      rules: sampleRules,
      user: userWithHypertension,
    );

    final flag = res.flags.firstWhere((f) => f.ruleId == 'rhr_drift');
    expect(flag.level, 'amber');
    expect(flag.explanation, contains('Adjusted for family history'));
  });
}
