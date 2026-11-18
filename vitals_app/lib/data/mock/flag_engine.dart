import 'dart:math' as math;

import '../../domain/models/baseline.dart';
import '../../domain/models/daily_reading.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/flag.dart';
import '../../domain/models/rule.dart';

/// Tunable parameters of the [FlagEngine].
class FlagEngineConfig {
  const FlagEngineConfig({
    this.baselineWindowDays = 60,
    this.baselineLagDays = 28,
    this.minBaselineSamples = 21,
    this.allowedMisses = 1,
    this.recentWindowDays = 30,
  });

  /// Length of the rolling window used for the usual range.
  final int baselineWindowDays;

  /// The window ends this many days before the day being judged, so a slow
  /// drift cannot quietly drag its own baseline along with it.
  final int baselineLagDays;

  /// Fewer non-gap samples than this means "not enough history".
  final int minBaselineSamples;

  /// Isolated in-range days tolerated inside a pattern before it resets.
  final int allowedMisses;

  /// Window used to judge data completeness for confidence.
  final int recentWindowDays;
}

/// Result of judging one metric against its baseline.
class MetricEvaluation {
  const MetricEvaluation({
    required this.metric,
    required this.status,
    required this.streakDays,
    required this.insufficientData,
    this.startedOn,
    this.meanZ = 0,
    this.meanDeviation = 0,
    this.currentValue,
    this.baseline,
  });

  final VitalMetric metric;
  final FlagStatus status;

  /// Non-gap days outside the usual range, in the current persistent pattern.
  final int streakDays;
  final DateTime? startedOn;

  /// Average bad-direction deviation in standard deviations (over the pattern).
  final double meanZ;

  /// Average bad-direction deviation in the metric's unit.
  final double meanDeviation;
  final double? currentValue;
  final Baseline? baseline;
  final bool insufficientData;
}

/// Compares recent days with a person's own rolling baseline and flags
/// patterns that persist. Descriptive only: it never diagnoses.
///
/// Gap days (`isGap`) are skipped entirely: they are never treated as zero,
/// never count towards a pattern and never break one.
class FlagEngine {
  const FlagEngine({this.config = const FlagEngineConfig()});

  final FlagEngineConfig config;

  /// Rolling mean/std band for every day of [readings] (index-aligned).
  /// Entries are `null` where there is not enough history yet.
  List<BaselinePoint?> rollingBands(
    List<DailyReading> readings,
    VitalMetric metric, {
    double sigma = 2.0,
  }) {
    final bands = List<BaselinePoint?>.filled(readings.length, null);
    for (var i = 0; i < readings.length; i++) {
      final end = i - config.baselineLagDays; // inclusive
      final start = end - config.baselineWindowDays + 1;
      if (end < 0) continue;
      var count = 0;
      var sum = 0.0;
      for (var j = math.max(0, start); j <= end; j++) {
        final v = readings[j].valueOf(metric);
        if (v == null) continue;
        count++;
        sum += v;
      }
      if (count < config.minBaselineSamples) continue;
      final mean = sum / count;
      var sq = 0.0;
      for (var j = math.max(0, start); j <= end; j++) {
        final v = readings[j].valueOf(metric);
        if (v == null) continue;
        sq += (v - mean) * (v - mean);
      }
      final std = math.sqrt(sq / (count - 1));
      bands[i] = BaselinePoint(
        date: readings[i].date,
        mean: mean,
        stdDev: std,
        low: mean - sigma * std,
        high: mean + sigma * std,
      );
    }
    return bands;
  }

  /// Baseline for [metric] with the full band series for charts.
  Baseline computeBaseline(
    List<DailyReading> readings,
    VitalMetric metric, {
    double sigma = 2.0,
  }) {
    final bands = rollingBands(readings, metric, sigma: sigma);
    final series = bands.whereType<BaselinePoint>().toList(growable: false);
    if (series.isEmpty) return Baseline.insufficient(metric);
    final last = series.last;
    final end = readings.length - 1 - config.baselineLagDays;
    final start = math.max(0, end - config.baselineWindowDays + 1);
    var count = 0;
    for (var j = start; j <= end; j++) {
      if (readings[j].valueOf(metric) != null) count++;
    }
    return Baseline(
      metric: metric,
      mean: last.mean,
      stdDev: last.stdDev,
      low: last.low,
      high: last.high,
      sampleCount: count,
      sigma: sigma,
      series: series,
    );
  }

  /// Judges one metric with the supplied thresholds.
  MetricEvaluation evaluateMetric(
    List<DailyReading> readings,
    VitalMetric metric, {
    required double sigma,
    required double redSigma,
    required int redDays,
    required double minDelta,
    required int minDurationDays,
  }) {
    final bands = rollingBands(readings, metric, sigma: sigma);
    final baseline = computeBaseline(readings, metric, sigma: sigma);

    double? currentValue;
    for (var i = readings.length - 1; i >= 0; i--) {
      final v = readings[i].valueOf(metric);
      if (v != null) {
        currentValue = v;
        break;
      }
    }

    var streak = 0;
    var pendingMisses = 0;
    var zSum = 0.0;
    var devSum = 0.0;
    var zCount = 0;
    final pendingZ = <double>[];
    final pendingDev = <double>[];
    DateTime? startedOn;

    for (var i = readings.length - 1; i >= 0; i--) {
      final value = readings[i].valueOf(metric);
      if (value == null) continue; // gap: ignored
      final band = bands[i];
      if (band == null) break; // no baseline before this point
      final std = math.max(band.stdDev, 1e-6);
      final bad = metric.higherIsBetter
          ? band.mean - value
          : value - band.mean;
      final outside = bad > sigma * std && bad >= minDelta;
      if (outside) {
        streak++;
        startedOn = readings[i].date;
        zSum += bad / std;
        devSum += bad;
        zCount++;
        for (var k = 0; k < pendingZ.length; k++) {
          zSum += pendingZ[k];
          devSum += pendingDev[k];
          zCount++;
        }
        pendingZ.clear();
        pendingDev.clear();
        pendingMisses = 0;
      } else {
        pendingMisses++;
        if (pendingMisses > config.allowedMisses) break;
        pendingZ.add(bad / std);
        pendingDev.add(bad);
      }
    }

    final meanZ = zCount == 0 ? 0.0 : zSum / zCount;
    final meanDev = zCount == 0 ? 0.0 : devSum / zCount;

    var status = FlagStatus.green;
    if (streak >= minDurationDays) {
      status = FlagStatus.amber;
      if (streak >= redDays && meanZ >= redSigma) status = FlagStatus.red;
    }

    return MetricEvaluation(
      metric: metric,
      status: status,
      streakDays: status == FlagStatus.green ? 0 : streak,
      startedOn: status == FlagStatus.green ? null : startedOn,
      meanZ: meanZ,
      meanDeviation: meanDev,
      currentValue: currentValue,
      baseline: baseline,
      insufficientData: !baseline.hasData,
    );
  }

  /// Evaluates [rule], applying any matching [hereditaryTags]. Returns the
  /// worst metric's result as a [Flag] (green when nothing persists).
  Flag evaluateRule(
    List<DailyReading> readings,
    Rule rule, {
    Set<String> hereditaryTags = const {},
    DateTime? now,
  }) {
    var sigma = rule.thresholds.sigma;
    var minDays = rule.minDurationDays;
    String? contextNote;
    for (final modifier in rule.hereditaryModifiers) {
      if (hereditaryTags.contains(modifier.tag)) {
        sigma += modifier.sigmaDelta;
        minDays += modifier.minDurationDeltaDays;
        contextNote = modifier.note;
      }
    }
    sigma = math.max(1.0, sigma);
    minDays = math.max(2, minDays);
    final redDays = math.max(minDays, rule.thresholds.redDays);

    MetricEvaluation? worst;
    for (final metric in rule.metrics) {
      final eval = evaluateMetric(
        readings,
        metric,
        sigma: sigma,
        redSigma: rule.thresholds.redSigma,
        redDays: redDays,
        minDelta: rule.thresholds.minDelta,
        minDurationDays: minDays,
      );
      if (worst == null ||
          eval.status.index > worst.status.index ||
          (eval.status == worst.status &&
              eval.streakDays > worst.streakDays)) {
        worst = eval;
      }
    }
    final eval = worst!;
    final updatedAt = now ??
        (readings.isEmpty ? DateTime.now() : readings.last.date);

    return Flag(
      id: 'flag_${rule.id}',
      ruleId: rule.id,
      title: rule.name,
      summary: _summary(eval),
      nextStep: _nextStep(eval.status),
      status: eval.status,
      metric: eval.metric,
      severity: _severity(eval.status),
      confidence: _confidence(readings, eval, minDays),
      streakDays: eval.streakDays,
      updatedAt: updatedAt,
      startedOn: eval.startedOn,
      currentValue: eval.currentValue,
      baselineMean: eval.baseline?.hasData == true ? eval.baseline!.mean : null,
      baselineLow: eval.baseline?.hasData == true ? eval.baseline!.low : null,
      baselineHigh: eval.baseline?.hasData == true ? eval.baseline!.high : null,
      meanDeviation:
          eval.status == FlagStatus.green ? null : eval.meanDeviation,
      zScore: eval.status == FlagStatus.green ? null : eval.meanZ,
      contextNote: eval.status == FlagStatus.green ? null : contextNote,
    );
  }

  /// Evaluates every rule. Result is sorted worst first, then by streak.
  List<Flag> evaluateAll(
    List<DailyReading> readings,
    List<Rule> rules, {
    Set<String> hereditaryTags = const {},
    DateTime? now,
  }) {
    final flags = [
      for (final rule in rules)
        evaluateRule(readings, rule, hereditaryTags: hereditaryTags, now: now),
    ];
    flags.sort((a, b) {
      final byStatus = b.status.index.compareTo(a.status.index);
      if (byStatus != 0) return byStatus;
      return b.streakDays.compareTo(a.streakDays);
    });
    return flags;
  }

  Severity _severity(FlagStatus status) {
    switch (status) {
      case FlagStatus.green:
        return Severity.low;
      case FlagStatus.amber:
        return Severity.medium;
      case FlagStatus.red:
        return Severity.high;
    }
  }

  Confidence _confidence(
    List<DailyReading> readings,
    MetricEvaluation eval,
    int minDays,
  ) {
    if (eval.insufficientData) return Confidence.low;
    final recent = readings.length <= config.recentWindowDays
        ? readings
        : readings.sublist(readings.length - config.recentWindowDays);
    final valid = recent.where((r) => r.valueOf(eval.metric) != null).length;
    final completeness = recent.isEmpty ? 0.0 : valid / recent.length;
    if (eval.status == FlagStatus.green) {
      return completeness >= 0.85 ? Confidence.high : Confidence.medium;
    }
    if (eval.streakDays >= minDays * 2 && completeness >= 0.85) {
      return Confidence.high;
    }
    return completeness >= 0.7 ? Confidence.medium : Confidence.low;
  }

  String _summary(MetricEvaluation eval) {
    final metric = eval.metric;
    if (eval.insufficientData) {
      return 'Still learning your usual range for ${metric.label}. '
          'A few more weeks of data will help.';
    }
    if (eval.status == FlagStatus.green) {
      return '${metric.label} is within your usual range.';
    }
    final direction = metric.higherIsBetter ? 'lower' : 'higher';
    final verb = metric == VitalMetric.steps ? 'have' : 'has';
    return '${metric.label} $verb been $direction than your usual range for '
        '${eval.streakDays} days '
        '(about ${_formatAmount(metric, eval.meanDeviation)} $direction on '
        'average).';
  }

  String _nextStep(FlagStatus status) {
    switch (status) {
      case FlagStatus.green:
        return 'Nothing to do. Keep up the routines that are working for you.';
      case FlagStatus.amber:
        return 'Keep an eye on this over the next week and note anything that '
            'might explain it, like stress, illness or travel.';
      case FlagStatus.red:
        return 'This pattern has lasted a while. Consider sharing it with a '
            'clinician who can look at the full picture.';
    }
  }

  String _formatAmount(VitalMetric metric, double amount) {
    switch (metric) {
      case VitalMetric.steps:
        return '${((amount / 50).round() * 50)} ${metric.unit}';
      case VitalMetric.restingHr:
      case VitalMetric.hrv:
      case VitalMetric.bedtimeVariability:
        return '${amount.round()} ${metric.unit}';
      default:
        return '${amount.toStringAsFixed(1)} ${metric.unit}';
    }
  }
}
