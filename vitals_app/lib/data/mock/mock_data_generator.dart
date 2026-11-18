import 'dart:math' as math;

import '../../domain/models/daily_reading.dart';
import '../../domain/models/enums.dart';
import 'personas.dart';

/// Generates deterministic sample data for a [Persona].
///
/// The same persona, `end` date and `days` always produce identical output.
/// About 3% of days are gaps (`isGap: true`, all metrics `null`), and each
/// metric has a day-of-week pattern (weekends differ from weekdays).
class MockDataGenerator {
  const MockDataGenerator();

  static const int defaultDays = 180;
  static const double gapRate = 0.03;

  /// Day-of-week offsets, Monday first.
  static const Map<VitalMetric, List<double>> _weekdayEffect = {
    VitalMetric.restingHr: [0.3, 0, 0, 0, 0.4, 0.9, 0.5],
    VitalMetric.hrv: [0, 0.6, 0.6, 0, -1.2, -2.2, -0.6],
    VitalMetric.sleepDuration: [-0.1, -0.2, -0.1, 0, -0.1, 0.7, 0.5],
    VitalMetric.deepSleep: [0, 0, 0, 0, 0, 0.12, 0.08],
    VitalMetric.sleepFragmentation: [0, 0, 0, 0.2, 0.5, 1.4, 0.9],
    VitalMetric.spo2: [0, 0, 0, 0, 0, 0, 0],
    VitalMetric.steps: [0, 300, 200, 0, -200, 1100, -700],
    VitalMetric.respiratoryRate: [0, 0, 0, 0, 0.1, 0.2, 0.1],
    VitalMetric.skinTemp: [0, 0, 0, 0, 0.05, 0.1, 0.05],
    VitalMetric.bedtimeVariability: [0, 0, 0, 3, 8, 14, 9],
  };

  /// Returns [days] readings ending on [end] (date-only), oldest first.
  List<DailyReading> generate(
    Persona persona, {
    DateTime? end,
    int days = defaultDays,
  }) {
    final last = _dateOnly(end ?? DateTime.now());
    final rng = math.Random(persona.seed);

    // Exactly ~3% gaps at deterministic positions; the latest day is kept.
    final gapCount = (days * gapRate).round();
    final gapIndexes = <int>{};
    while (gapIndexes.length < gapCount) {
      gapIndexes.add(rng.nextInt(days - 1));
    }

    final readings = <DailyReading>[];
    for (var i = 0; i < days; i++) {
      final daysAgo = days - 1 - i;
      final date = DateTime(last.year, last.month, last.day - daysAgo);

      // Always draw the same number of random values per day so that gaps
      // do not shift the sequence for the days that follow.
      final noise = <VitalMetric, double>{
        for (final metric in VitalMetric.values) metric: _gaussian(rng),
      };
      if (gapIndexes.contains(i)) {
        readings.add(DailyReading.gap(date));
        continue;
      }

      final values = <VitalMetric, double>{};
      for (final entry in persona.metrics.entries) {
        final metric = entry.key;
        final spec = entry.value;
        var value = spec.mean +
            _weekdayEffect[metric]![date.weekday - 1] +
            noise[metric]! * spec.sd;
        for (final drift in persona.drifts) {
          if (drift.metric == metric) value += drift.shiftAt(daysAgo);
        }
        for (final blip in persona.blips) {
          if (blip.metric == metric) value += blip.shiftAt(daysAgo);
        }
        values[metric] = value;
      }
      _applyLimits(values);
      readings.add(DailyReading.fromValues(date, values));
    }
    return readings;
  }

  void _applyLimits(Map<VitalMetric, double> v) {
    // metric: (min, max, decimals)
    const limits = <VitalMetric, (double, double, int)>{
      VitalMetric.restingHr: (38, 120, 0),
      VitalMetric.hrv: (8, 150, 0),
      VitalMetric.sleepDuration: (3.5, 10.5, 2),
      VitalMetric.deepSleep: (0.2, 3.0, 2),
      VitalMetric.sleepFragmentation: (0, 60, 1),
      VitalMetric.spo2: (85, 100, 1),
      VitalMetric.steps: (400, 30000, 0),
      VitalMetric.respiratoryRate: (8, 30, 1),
      VitalMetric.skinTemp: (30, 37, 2),
      VitalMetric.bedtimeVariability: (0, 240, 0),
    };
    for (final metric in v.keys.toList()) {
      final (lo, hi, decimals) = limits[metric]!;
      final factor = math.pow(10, decimals).toDouble();
      v[metric] = (v[metric]!.clamp(lo, hi) * factor).round() / factor;
    }
    // Deep sleep can never exceed 40% of the night.
    final sleep = v[VitalMetric.sleepDuration];
    final deep = v[VitalMetric.deepSleep];
    if (sleep != null && deep != null && deep > sleep * 0.4) {
      v[VitalMetric.deepSleep] = (sleep * 0.4 * 100).round() / 100;
    }
  }

  /// Standard normal via Box–Muller.
  double _gaussian(math.Random rng) {
    final u1 = 1 - rng.nextDouble();
    final u2 = rng.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
