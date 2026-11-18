import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';

enum VitalMetric {
  restingHr(
    label: 'Resting HR',
    unit: 'bpm',
    domain: HealthDomain.heart,
    higherIsBetter: false,
  ),
  hrv(
    label: 'HRV',
    unit: 'ms',
    domain: HealthDomain.heart,
    higherIsBetter: true,
  ),
  sleepDuration(
    label: 'Sleep',
    unit: 'h',
    domain: HealthDomain.sleep,
    higherIsBetter: true,
  ),
  deepSleep(
    label: 'Deep sleep',
    unit: 'h',
    domain: HealthDomain.sleep,
    higherIsBetter: true,
  ),
  sleepFragmentation(
    label: 'Sleep fragmentation',
    unit: 'index',
    domain: HealthDomain.sleep,
    higherIsBetter: false,
  ),
  spo2(
    label: 'SpO₂',
    unit: '%',
    domain: HealthDomain.respiratory,
    higherIsBetter: true,
  ),
  steps(
    label: 'Steps',
    unit: 'steps',
    domain: HealthDomain.activity,
    higherIsBetter: true,
  ),
  respiratoryRate(
    label: 'Respiratory rate',
    unit: '/min',
    domain: HealthDomain.respiratory,
    higherIsBetter: false,
  ),
  skinTemp(
    label: 'Skin temp',
    unit: '°C',
    domain: HealthDomain.stressRecovery,
    higherIsBetter: false,
  ),
  bedtimeVariability(
    label: 'Bedtime variability',
    unit: 'min',
    domain: HealthDomain.sleep,
    higherIsBetter: false,
  );

  const VitalMetric({
    required this.label,
    required this.unit,
    required this.domain,
    required this.higherIsBetter,
  });

  final String label;
  final String unit;
  final HealthDomain domain;
  final bool higherIsBetter;
}

enum HealthDomain {
  heart('Heart', Icons.favorite_rounded),
  sleep('Sleep', Icons.bedtime_rounded),
  activity('Activity', Icons.directions_walk_rounded),
  stressRecovery('Stress & recovery', Icons.self_improvement_rounded),
  respiratory('Respiratory', Icons.air_rounded);

  const HealthDomain(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum FlagStatus {
  green(
    label: 'Healthy',
    icon: Icons.check_circle_rounded,
    color: AppColors.flagGreen,
    background: AppColors.flagGreenBg,
  ),
  amber(
    label: 'Watch',
    icon: Icons.warning_amber_rounded,
    color: AppColors.flagAmber,
    background: AppColors.flagAmberBg,
  ),
  red(
    label: 'Action needed',
    icon: Icons.error_rounded,
    color: AppColors.flagRed,
    background: AppColors.flagRedBg,
  );

  const FlagStatus({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;
}

enum Severity { low, medium, high }

enum Confidence { low, medium, high }

enum AlertTier {
  info('Info', Icons.info_rounded, AppColors.skyCard),
  advise('Advise', Icons.medical_services_rounded, AppColors.creamCard),
  urgent('Urgent', Icons.priority_high_rounded, AppColors.peachCard),
  emergency('Emergency', Icons.emergency_rounded, AppColors.flagRedBg);

  const AlertTier(this.label, this.icon, this.background);

  final String label;
  final IconData icon;
  final Color background;
}

enum DoctorVerdict {
  confirmed('Confirmed'),
  notConcerning('Not concerning'),
  needsConsultation('Needs consultation'),
  pending('Under review');

  const DoctorVerdict(this.label);

  final String label;
}

enum DoctorBadgeState {
  verified('Doctor-verified', Icons.verified_rounded, AppColors.flagGreen),
  underReview('Under review', Icons.hourglass_top_rounded, AppColors.flagAmber),
  notReviewed('Not yet reviewed', Icons.pending_outlined, AppColors.muted),
  needsConsultation(
    'Needs consultation',
    Icons.local_hospital_rounded,
    AppColors.flagRed,
  );

  const DoctorBadgeState(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

enum LifeEventType {
  illness('Illness', Icons.sick_rounded),
  travel('Travel', Icons.flight_rounded),
  medication('Medication', Icons.medication_rounded),
  stress('Stress', Icons.psychology_rounded),
  other('Other', Icons.event_rounded);

  const LifeEventType(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum ChartRange {
  oneWeek('1W', 7),
  oneMonth('1M', 30),
  threeMonths('3M', 90),
  sixMonths('6M', 180),
  all('ALL', 180);

  const ChartRange(this.label, this.days);

  final String label;
  final int days;
}
