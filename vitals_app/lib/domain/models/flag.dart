import 'enums.dart';

/// A pattern surfaced by the flag engine for one rule.
///
/// Flags describe how recent data compares with the person's own usual range.
/// They are never diagnoses and carry no probability.
class Flag {
  const Flag({
    required this.id,
    required this.ruleId,
    required this.title,
    required this.summary,
    required this.nextStep,
    required this.status,
    required this.metric,
    required this.severity,
    required this.confidence,
    required this.streakDays,
    required this.updatedAt,
    this.startedOn,
    this.currentValue,
    this.baselineMean,
    this.baselineLow,
    this.baselineHigh,
    this.meanDeviation,
    this.zScore,
    this.contextNote,
    this.doctorBadge = DoctorBadgeState.notReviewed,
    this.acknowledged = false,
  });

  final String id;
  final String ruleId;
  final String title;
  final String summary;
  final String nextStep;
  final FlagStatus status;
  final VitalMetric metric;
  final Severity severity;
  final Confidence confidence;

  /// Number of days (gaps excluded) the pattern has persisted.
  final int streakDays;
  final DateTime updatedAt;
  final DateTime? startedOn;

  /// Recent value (latest non-gap day) of [metric].
  final double? currentValue;
  final double? baselineMean;
  final double? baselineLow;
  final double? baselineHigh;

  /// Average distance beyond the baseline mean, in the metric's unit.
  final double? meanDeviation;

  /// Average deviation expressed in standard deviations.
  final double? zScore;

  /// Optional note, e.g. when family history adjusted sensitivity.
  final String? contextNote;
  final DoctorBadgeState doctorBadge;
  final bool acknowledged;

  HealthDomain get domain => metric.domain;
  bool get isActive => status != FlagStatus.green;

  Flag copyWith({
    DoctorBadgeState? doctorBadge,
    bool? acknowledged,
    String? summary,
    String? nextStep,
  }) {
    return Flag(
      id: id,
      ruleId: ruleId,
      title: title,
      summary: summary ?? this.summary,
      nextStep: nextStep ?? this.nextStep,
      status: status,
      metric: metric,
      severity: severity,
      confidence: confidence,
      streakDays: streakDays,
      updatedAt: updatedAt,
      startedOn: startedOn,
      currentValue: currentValue,
      baselineMean: baselineMean,
      baselineLow: baselineLow,
      baselineHigh: baselineHigh,
      meanDeviation: meanDeviation,
      zScore: zScore,
      contextNote: contextNote,
      doctorBadge: doctorBadge ?? this.doctorBadge,
      acknowledged: acknowledged ?? this.acknowledged,
    );
  }
}
