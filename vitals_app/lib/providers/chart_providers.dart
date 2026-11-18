import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/metric_labels.dart';
import '../data/repositories/baseline_repository.dart';
import '../data/repositories/daily_repository.dart';
import '../data/repositories/flag_repository.dart';
import '../domain/models/enums.dart';
import 'data_providers.dart';

/// One precomputed series for charts (never built inside widget `build`).
class MetricSeries {
  const MetricSeries({
    required this.metric,
    required this.values,
    required this.dates,
    this.latest,
    this.mean7,
    this.baselineMean,
    this.baselineStd,
    this.flagLevel,
  });

  final String metric;
  /// Chronological; `null` = gap (do not plot as zero).
  final List<double?> values;
  final List<String> dates;
  final double? latest;
  final double? mean7;
  final double? baselineMean;
  final double? baselineStd;
  /// Worst flag level for this metric, if any.
  final String? flagLevel;

  FlagStatus get status =>
      MetricLabels.statusFromLevel(flagLevel ?? 'green');

  /// Non-null points only, for widgets that cannot take gaps (hero card).
  List<double> get solidPoints =>
      values.whereType<double>().toList(growable: false);

  /// Downsampled to ≤ [maxPoints], preserving null gaps as breaks.
  MetricSeries downsample(int maxPoints) {
    if (values.length <= maxPoints) return this;
    final step = (values.length / maxPoints).ceil();
    final v = <double?>[];
    final d = <String>[];
    for (var i = 0; i < values.length; i += step) {
      v.add(values[i]);
      d.add(dates[i]);
    }
    return MetricSeries(
      metric: metric,
      values: v,
      dates: d,
      latest: latest,
      mean7: mean7,
      baselineMean: baselineMean,
      baselineStd: baselineStd,
      flagLevel: flagLevel,
    );
  }
}

double? _metricValue(DailyModel day, String metric) {
  if (day.isGap) return null;
  return switch (metric) {
    'restingHr' => day.restingHr,
    'hrv' => day.hrv,
    'sleepDeep' => day.sleepDeep,
    'sleepTotal' => day.sleepTotal,
    'spo2' => day.spo2,
    'steps' => day.steps,
    _ => null,
  };
}

MetricSeries _buildSeries({
  required String metric,
  required List<DailyModel> daily,
  required Map<String, BaselineModel> baselines,
  required List<FlagModel> flags,
  int? lastN,
}) {
  var days = daily;
  if (lastN != null && days.length > lastN) {
    days = days.sublist(days.length - lastN);
  }

  final values = <double?>[];
  final dates = <String>[];
  for (final d in days) {
    dates.add(d.date);
    values.add(_metricValue(d, metric));
  }

  final recent = values.reversed.whereType<double>().take(7).toList();
  final mean7 = recent.isEmpty
      ? null
      : recent.reduce((a, b) => a + b) / recent.length;

  final baseline = baselines[metric];
  final bMean = baseline?.mean;
  final bStd = baseline?.std;

  String? worst;
  for (final f in flags) {
    if (f.metric != metric) continue;
    if (worst == null ||
        _rank(f.level) > _rank(worst)) {
      worst = f.level;
    }
  }

  final solid = values.whereType<double>().toList();
  return MetricSeries(
    metric: metric,
    values: values,
    dates: dates,
    latest: solid.isEmpty ? null : solid.last,
    mean7: mean7,
    baselineMean: bMean,
    baselineStd: bStd,
    flagLevel: worst,
  );
}

int _rank(String level) => switch (level) {
      'red' => 2,
      'amber' => 1,
      _ => 0,
    };

/// Last 30 days per core metric — used by the home dashboard.
final homeMetricSeriesProvider = Provider<Map<String, MetricSeries>>((ref) {
  final daily = ref.watch(dailyProvider(null)).value ?? const [];
  final baselines = ref.watch(baselinesProvider).value ?? {};
  final flags = ref.watch(flagsProvider).value ?? const [];

  const metrics = ['restingHr', 'hrv', 'sleepDeep', 'spo2', 'steps'];
  return {
    for (final m in metrics)
      m: _buildSeries(
        metric: m,
        daily: daily,
        baselines: baselines,
        flags: flags,
        lastN: 30,
      ).downsample(60),
  };
});

/// Hero metric: worst flagged metric, else restingHr.
final homeHeroMetricProvider = Provider<String>((ref) {
  final flags = ref.watch(flagsProvider).value ?? const [];
  final actionable = flags.where((f) => f.level != 'green').toList();
  if (actionable.isEmpty) return 'restingHr';
  actionable.sort((a, b) {
    final r = _rank(b.level) - _rank(a.level);
    if (r != 0) return r;
    return b.durationDays.compareTo(a.durationDays);
  });
  final m = actionable.first.metric;
  if (m.isEmpty) return 'restingHr';
  return m;
});

/// Metric currently focused on the Timeline tab (set from Home vital taps).
class TimelineSelectedMetric extends Notifier<String> {
  @override
  String build() => 'restingHr';

  void select(String metric) => state = metric;
}

final timelineSelectedMetricProvider =
    NotifierProvider<TimelineSelectedMetric, String>(
  TimelineSelectedMetric.new,
);
