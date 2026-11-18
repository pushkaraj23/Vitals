import 'enums.dart';

/// One calendar day of wearable-derived vitals.
///
/// When [isGap] is true the device produced no usable data for the day and
/// every metric is `null` (a gap is *never* represented as zero).
class DailyReading {
  const DailyReading({
    required this.date,
    this.isGap = false,
    this.restingHr,
    this.hrv,
    this.sleepDuration,
    this.deepSleep,
    this.sleepFragmentation,
    this.spo2,
    this.steps,
    this.respiratoryRate,
    this.skinTemp,
    this.bedtimeVariability,
  });

  /// A day with no data.
  const DailyReading.gap(this.date)
    : isGap = true,
      restingHr = null,
      hrv = null,
      sleepDuration = null,
      deepSleep = null,
      sleepFragmentation = null,
      spo2 = null,
      steps = null,
      respiratoryRate = null,
      skinTemp = null,
      bedtimeVariability = null;

  /// Builds a reading from a metric → value map. Missing metrics stay `null`.
  factory DailyReading.fromValues(
    DateTime date,
    Map<VitalMetric, double> values,
  ) {
    return DailyReading(
      date: date,
      restingHr: values[VitalMetric.restingHr],
      hrv: values[VitalMetric.hrv],
      sleepDuration: values[VitalMetric.sleepDuration],
      deepSleep: values[VitalMetric.deepSleep],
      sleepFragmentation: values[VitalMetric.sleepFragmentation],
      spo2: values[VitalMetric.spo2],
      steps: values[VitalMetric.steps],
      respiratoryRate: values[VitalMetric.respiratoryRate],
      skinTemp: values[VitalMetric.skinTemp],
      bedtimeVariability: values[VitalMetric.bedtimeVariability],
    );
  }

  /// Date-only (local midnight).
  final DateTime date;
  final bool isGap;

  /// Beats per minute.
  final double? restingHr;

  /// Milliseconds.
  final double? hrv;

  /// Hours asleep.
  final double? sleepDuration;

  /// Hours of deep sleep.
  final double? deepSleep;

  /// Unitless index; higher means more disrupted sleep.
  final double? sleepFragmentation;

  /// Percent.
  final double? spo2;

  final double? steps;

  /// Breaths per minute.
  final double? respiratoryRate;

  /// Degrees Celsius.
  final double? skinTemp;

  /// Minutes the bedtime differed from the person's usual bedtime.
  final double? bedtimeVariability;

  /// Value for [metric], or `null` if this is a gap or the metric is missing.
  double? valueOf(VitalMetric metric) {
    if (isGap) return null;
    switch (metric) {
      case VitalMetric.restingHr:
        return restingHr;
      case VitalMetric.hrv:
        return hrv;
      case VitalMetric.sleepDuration:
        return sleepDuration;
      case VitalMetric.deepSleep:
        return deepSleep;
      case VitalMetric.sleepFragmentation:
        return sleepFragmentation;
      case VitalMetric.spo2:
        return spo2;
      case VitalMetric.steps:
        return steps;
      case VitalMetric.respiratoryRate:
        return respiratoryRate;
      case VitalMetric.skinTemp:
        return skinTemp;
      case VitalMetric.bedtimeVariability:
        return bedtimeVariability;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyReading &&
          other.date == date &&
          other.isGap == isGap &&
          other.restingHr == restingHr &&
          other.hrv == hrv &&
          other.sleepDuration == sleepDuration &&
          other.deepSleep == deepSleep &&
          other.sleepFragmentation == sleepFragmentation &&
          other.spo2 == spo2 &&
          other.steps == steps &&
          other.respiratoryRate == respiratoryRate &&
          other.skinTemp == skinTemp &&
          other.bedtimeVariability == bedtimeVariability;

  @override
  int get hashCode => Object.hash(
    date,
    isGap,
    restingHr,
    hrv,
    sleepDuration,
    deepSleep,
    sleepFragmentation,
    spo2,
    steps,
    respiratoryRate,
    skinTemp,
    bedtimeVariability,
  );
}
