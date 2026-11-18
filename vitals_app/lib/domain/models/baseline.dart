import 'enums.dart';

/// Personal "usual range" for a single day on a rolling baseline.
class BaselinePoint {
  const BaselinePoint({
    required this.date,
    required this.mean,
    required this.stdDev,
    required this.low,
    required this.high,
  });

  final DateTime date;
  final double mean;
  final double stdDev;
  final double low;
  final double high;
}

/// A person's usual range for one [VitalMetric].
///
/// [mean]/[stdDev]/[low]/[high] describe the most recent band. [series] holds
/// the per-day rolling band (days without enough history are omitted).
class Baseline {
  const Baseline({
    required this.metric,
    required this.mean,
    required this.stdDev,
    required this.low,
    required this.high,
    required this.sampleCount,
    required this.sigma,
    this.series = const [],
  });

  /// Returned when there is not enough history to build a band.
  const Baseline.insufficient(this.metric)
    : mean = double.nan,
      stdDev = double.nan,
      low = double.nan,
      high = double.nan,
      sampleCount = 0,
      sigma = 0,
      series = const [];

  final VitalMetric metric;
  final double mean;
  final double stdDev;
  final double low;
  final double high;

  /// Number of non-gap days that contributed to the latest band.
  final int sampleCount;

  /// Band half-width in standard deviations.
  final double sigma;

  final List<BaselinePoint> series;

  bool get hasData => sampleCount > 0 && !mean.isNaN;

  /// Whether [value] sits inside the usual range.
  bool contains(double value) => hasData && value >= low && value <= high;

  Baseline copyWith({
    double? mean,
    double? stdDev,
    double? low,
    double? high,
    int? sampleCount,
    double? sigma,
    List<BaselinePoint>? series,
  }) {
    return Baseline(
      metric: metric,
      mean: mean ?? this.mean,
      stdDev: stdDev ?? this.stdDev,
      low: low ?? this.low,
      high: high ?? this.high,
      sampleCount: sampleCount ?? this.sampleCount,
      sigma: sigma ?? this.sigma,
      series: series ?? this.series,
    );
  }
}
