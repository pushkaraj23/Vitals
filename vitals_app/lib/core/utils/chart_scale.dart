import 'dart:math' as math;

/// Shared Y-axis scaling so small metric deltas don't fill the chart.
abstract final class ChartScale {
  /// Minimum visual span per metric (same units as the series).
  static double minSpan(String? metric, double mid) {
    return switch (metric) {
      'restingHr' => 24,
      'hrv' => 40,
      'sleepDeep' => 50,
      'sleepTotal' => 90,
      'spo2' => 10,
      'steps' => math.max(mid.abs() * 0.35, 2500),
      _ => math.max(mid.abs() * 0.2, 12),
    };
  }

  /// Returns padded [minY]/[maxY] centered on the data, expanded to at least
  /// [minSpan] so modest changes look modest.
  static ({double minY, double maxY}) bounds(
    Iterable<double> values, {
    String? metric,
  }) {
    final vals = values.toList();
    if (vals.isEmpty) return (minY: 0, maxY: 1);

    final lo = vals.reduce(math.min);
    final hi = vals.reduce(math.max);
    final mid = (lo + hi) / 2;
    final dataSpan = (hi - lo).abs();
    final floor = minSpan(metric, mid);
    // Prefer a calm scale: at least [floor], otherwise data + soft margin.
    final span = math.max(dataSpan * 1.35, floor);
    var minY = mid - span / 2;
    var maxY = mid + span / 2;

    // Keep all points inside with a little breathing room.
    if (lo < minY) minY = lo - span * 0.06;
    if (hi > maxY) maxY = hi + span * 0.06;

    // SpO₂ can't exceed ~100; keep the scale honest near the ceiling.
    if (metric == 'spo2') {
      maxY = math.min(maxY, 102);
      if (minY > 90) minY = math.min(minY, 90);
    }

    if ((maxY - minY).abs() < 1e-6) {
      minY -= 1;
      maxY += 1;
    }
    return (minY: minY, maxY: maxY);
  }

  /// Nicely spaced tick interval (~4–5 labels).
  static double yInterval(double minY, double maxY) {
    final range = (maxY - minY).abs();
    if (range <= 0) return 1;
    final rough = range / 4;
    // Round to a friendly step so labels aren't noisy.
    final mag = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    final norm = rough / mag;
    final nice = norm < 1.5
        ? 1.0
        : norm < 3
            ? 2.0
            : norm < 7
                ? 5.0
                : 10.0;
    return nice * mag;
  }
}
