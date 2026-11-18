// lib/engine/vitalwatch_engine.dart
// Pure Dart — NO Flutter or Firebase imports.
import 'dart:math' as math;

import '../data/repositories/baseline_repository.dart';
import '../data/repositories/daily_repository.dart';
import '../data/repositories/flag_repository.dart';
import '../data/repositories/rule_repository.dart';
import '../data/repositories/user_repository.dart';

const int kCalibrationDays = 14;
const int kCalibrationMinSamples = 7;
const int kTrailingDays = 7;

/// Output of running the engine on a user's data.
class EngineOutput {
  const EngineOutput({
    required this.flags,
    required this.baselines,
    required this.isCalibrating,
    required this.calibrationDay,
  });

  /// Flags to write to users/{uid}/flags/ (deterministic id: engine_{ruleId}).
  final List<FlagModel> flags;

  /// Baselines to write to users/{uid}/baselines/{metric}.
  final List<BaselineModel> baselines;

  /// True when fewer than 14 days of data are available.
  final bool isCalibrating;

  /// Progress: 1 to 14.
  final int calibrationDay;
}

/// Pure Dart rule and baseline engine.
class VitalWatchEngine {
  const VitalWatchEngine();

  /// Runs calibration and rule evaluation.
  /// [daily] must be sorted by date ascending.
  EngineOutput evaluate({
    required List<DailyModel> daily,
    required List<RuleModel> rules,
    required UserModel user,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final nowStr = _formatDate(effectiveNow);

    final nonGapDays = daily.where((d) => !d.isGap).toList();
    final nonGapCount = nonGapDays.length;

    // ── 1. Baseline calculation ─────────────────────────────────────────────
    // Use first 14 calendar days of user's data (non-gap days, min 7 points)
    final isCalibrating = nonGapCount < kCalibrationDays;
    final calibrationDay = math.min(nonGapCount, kCalibrationDays);

    final calibrationWindow = nonGapDays.take(kCalibrationDays).toList();
    final baselines = <BaselineModel>[];
    final baselineMap = <String, BaselineModel>{};

    const metrics = ['restingHr', 'hrv', 'sleepDeep', 'spo2', 'steps'];

    for (final m in metrics) {
      final values = calibrationWindow
          .map((d) => _getMetricValue(d, m))
          .whereType<double>()
          .toList();

      if (values.length >= kCalibrationMinSamples) {
        final mean = _calcMean(values);
        final std = _calcStd(values, mean);
        final calUntil = calibrationWindow.last.date;
        final base = BaselineModel(
          metric: m,
          mean: _round(mean, 2),
          std: _round(math.max(std, 0.01), 2),
          n: values.length,
          calibratedUntil: calUntil,
        );
        baselines.add(base);
        baselineMap[m] = base;
      }
    }

    // If still calibrating (<14 days), generate NO amber or red flags
    if (isCalibrating) {
      return EngineOutput(
        flags: [],
        baselines: baselines,
        isCalibrating: true,
        calibrationDay: calibrationDay,
      );
    }

    // ── 2. Check family history modifier ────────────────────────────────────
    final hasHereditary = user.hasHereditaryRisk ||
        user.familyHistory.any((h) {
          final c = h.condition.toLowerCase();
          return c.contains('hypertension') ||
              c.contains('diabetes') ||
              c.contains('heart') ||
              c.contains('cardiovascular');
        });

    const heartRules = {'rhr_drift', 'hrv_decline', 'spo2_dip'};

    // ── 3. Evaluate each rule ───────────────────────────────────────────────
    final flags = <FlagModel>[];

    for (final rule in rules) {
      // Rule only fires if user has data for EVERY metric in requires
      final hasAllMetrics =
          rule.requires.every((req) => baselineMap.containsKey(req));
      if (!hasAllMetrics) continue;

      // And at least minDataDays of data
      if (nonGapCount < rule.minDataDays) continue;

      // Check baseline for the rule's primary metric
      final baseline = baselineMap[rule.metric];
      if (baseline == null) continue;

      // Hereditary modifier: lower thresholds for heart rules by 20%
      final isHeartRule = heartRules.contains(rule.id);
      final applyHereditary = hasHereditary && isHeartRule;

      double? minDeltaAbs = rule.minDeltaAbs;
      double? minDeltaPct = rule.minDeltaPct;
      if (applyHereditary) {
        if (minDeltaAbs != null) minDeltaAbs = minDeltaAbs * 0.8;
        if (minDeltaPct != null) minDeltaPct = minDeltaPct * 0.8;
      }

      // Trailing 7-day mean
      final trailingDays = nonGapDays.reversed.take(kTrailingDays).toList();
      final trailingValues = trailingDays
          .map((d) => _getMetricValue(d, rule.metric))
          .whereType<double>()
          .toList();

      if (trailingValues.isEmpty) continue;
      final trailingMean = _calcMean(trailingValues);
      final baselineMean = baseline.mean;

      // Check deviation
      final delta = rule.direction == 'up'
          ? trailingMean - baselineMean
          : baselineMean - trailingMean;

      final exceedsAbs = minDeltaAbs != null && delta >= minDeltaAbs;
      final exceedsPct = minDeltaPct != null &&
          baselineMean != 0 &&
          (delta / baselineMean * 100) >= minDeltaPct;

      if (!exceedsAbs && !exceedsPct) continue;

      // Count consecutive deviating days (ignore gaps, do not break on single gap)
      var streak = 0;
      var gapSkipAllowed = 1;

      for (var i = daily.length - 1; i >= 0; i--) {
        final d = daily[i];
        if (d.isGap) {
          if (gapSkipAllowed > 0) {
            gapSkipAllowed--;
            continue;
          } else {
            break;
          }
        }

        final val = _getMetricValue(d, rule.metric);
        if (val == null) continue;

        final dayDelta = rule.direction == 'up'
            ? val - baselineMean
            : baselineMean - val;

        final dayAbsOk = minDeltaAbs != null && dayDelta >= minDeltaAbs;
        final dayPctOk = minDeltaPct != null &&
            baselineMean != 0 &&
            (dayDelta / baselineMean * 100) >= minDeltaPct;

        if (dayAbsOk || dayPctOk) {
          streak++;
          gapSkipAllowed = 1; // reset single gap tolerance
        } else {
          break;
        }
      }

      // Determine level: red if >= redDays, amber if >= amberDays
      String level;
      if (streak >= rule.redDays) {
        level = 'red';
      } else if (streak >= rule.amberDays) {
        level = 'amber';
      } else {
        continue; // not enough persistence for this rule
      }

      // Confidence
      final completeness =
          daily.isEmpty ? 0.0 : nonGapCount / daily.length.toDouble();
      String confidence;
      if (completeness >= 0.85 && streak >= rule.redDays) {
        confidence = 'high';
      } else if (completeness >= 0.70) {
        confidence = 'medium';
      } else {
        confidence = 'low';
      }

      final severity = level == 'red'
          ? 3
          : (streak >= rule.amberDays + (rule.redDays - rule.amberDays) ~/ 2
              ? 2
              : 1);

      final explanation = applyHereditary
          ? '${rule.explanation} Adjusted for family history.'
          : rule.explanation;

      flags.add(FlagModel(
        id: 'engine_${rule.id}',
        ruleId: rule.id,
        level: level,
        metric: rule.metric,
        startDate: daily.isNotEmpty ? daily.last.date : nowStr,
        durationDays: streak,
        severity: severity,
        confidence: confidence,
        title: rule.title,
        explanation: explanation,
        dataUsed: rule.requires,
        source: 'engine',
        baselineValue: _round(baselineMean, 1),
        currentValue: _round(trailingMean, 1),
      ));
    }

    // ── 4. If no rule fires, emit overall_stable green flag ──────────────────
    if (flags.isEmpty) {
      flags.add(FlagModel(
        id: 'engine_overall_stable',
        ruleId: 'overall_stable',
        level: 'green',
        metric: 'overall',
        startDate: nowStr,
        durationDays: nonGapCount,
        severity: 1,
        confidence: 'high',
        title: 'Your patterns look stable',
        explanation:
            'Your resting heart rate, HRV, sleep and activity are all within your personal baseline range.',
        dataUsed: baselineMap.keys.toList(),
        source: 'engine',
      ));
    }

    return EngineOutput(
      flags: flags,
      baselines: baselines,
      isCalibrating: false,
      calibrationDay: kCalibrationDays,
    );
  }

  double? _getMetricValue(DailyModel d, String metric) {
    if (d.isGap) return null;
    return switch (metric) {
      'restingHr' => d.restingHr,
      'hrv' => d.hrv,
      'sleepDeep' => d.sleepDeep,
      'sleepTotal' => d.sleepTotal,
      'spo2' => d.spo2,
      'steps' => d.steps,
      _ => null,
    };
  }

  double _calcMean(List<double> vals) =>
      vals.reduce((a, b) => a + b) / vals.length;

  double _calcStd(List<double> vals, double mean) {
    if (vals.length <= 1) return 0;
    final sq = vals.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b);
    return math.sqrt(sq / (vals.length - 1));
  }

  double _round(double v, int decimals) {
    final factor = math.pow(10, decimals).toDouble();
    return (v * factor).round() / factor;
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
