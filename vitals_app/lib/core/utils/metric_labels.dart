import 'package:material_ui/material_ui.dart';

import '../../domain/models/enums.dart';
import '../theme/app_colors.dart';

/// Maps Firestore metric field names to UI chrome.
abstract final class MetricLabels {
  static String label(String metric) => switch (metric) {
        'restingHr' => 'Resting HR',
        'hrv' => 'HRV',
        'sleepDeep' => 'Deep sleep',
        'sleepTotal' => 'Sleep',
        'spo2' => 'SpO₂',
        'steps' => 'Steps',
        _ => metric,
      };

  static String unit(String metric) => switch (metric) {
        'restingHr' => 'bpm',
        'hrv' => 'ms',
        'sleepDeep' || 'sleepTotal' => 'min',
        'spo2' => '%',
        'steps' => 'steps',
        _ => '',
      };

  static IconData icon(String metric) => switch (metric) {
        'restingHr' || 'hrv' => Icons.favorite_rounded,
        'sleepDeep' || 'sleepTotal' => Icons.bedtime_rounded,
        'spo2' => Icons.air_rounded,
        'steps' => Icons.directions_walk_rounded,
        _ => Icons.show_chart_rounded,
      };

  static FlagStatus statusFromLevel(String level) => switch (level) {
        'red' => FlagStatus.red,
        'amber' => FlagStatus.amber,
        _ => FlagStatus.green,
      };

  static Color colorFromLevel(String level) => switch (level) {
        'red' => AppColors.flagRed,
        'amber' => AppColors.flagAmber,
        _ => AppColors.flagGreen,
      };

  static Color bgFromLevel(String level) => switch (level) {
        'red' => AppColors.flagRedBg,
        'amber' => AppColors.flagAmberBg,
        _ => AppColors.flagGreenBg,
      };

  /// Checkup tier from flag level + severity (no Emergency unless a rule defines it).
  static AlertTier checkupTier(String level, int severity) {
    if (level == 'red') {
      return severity >= 3 ? AlertTier.urgent : AlertTier.advise;
    }
    if (level == 'amber') return AlertTier.advise;
    return AlertTier.info;
  }
}
