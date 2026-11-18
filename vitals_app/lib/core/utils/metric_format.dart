import '../../domain/models/enums.dart';
import 'format.dart';

/// Number formatting that suits each [VitalMetric].
abstract final class MetricFormat {
  static int decimalsFor(VitalMetric metric) {
    switch (metric) {
      case VitalMetric.steps:
      case VitalMetric.restingHr:
      case VitalMetric.hrv:
      case VitalMetric.bedtimeVariability:
        return 0;
      case VitalMetric.sleepDuration:
      case VitalMetric.deepSleep:
      case VitalMetric.sleepFragmentation:
      case VitalMetric.spo2:
      case VitalMetric.respiratoryRate:
      case VitalMetric.skinTemp:
        return 1;
    }
  }

  static String value(VitalMetric metric, double value) =>
      Format.number(value, decimals: decimalsFor(metric));

  static String withUnit(VitalMetric metric, double value) =>
      '${MetricFormat.value(metric, value)} ${metric.unit}';

  static String range(VitalMetric metric, double low, double high) =>
      '${value(metric, low)}–${value(metric, high)} ${metric.unit}';
}
