import 'enums.dart';

/// Numeric thresholds that drive the persistence rule for one [Rule].
class RuleThresholds {
  const RuleThresholds({
    required this.sigma,
    required this.redSigma,
    required this.redDays,
    required this.minDelta,
  });

  factory RuleThresholds.fromJson(Map<String, dynamic> json) {
    return RuleThresholds(
      sigma: (json['sigma'] as num).toDouble(),
      redSigma: (json['redSigma'] as num).toDouble(),
      redDays: (json['redDays'] as num).toInt(),
      minDelta: (json['minDelta'] as num).toDouble(),
    );
  }

  /// A day is "outside usual range" beyond this many standard deviations.
  final double sigma;

  /// Mean deviation (in standard deviations) needed to escalate to red.
  final double redSigma;

  /// Days of persistence needed before a pattern can escalate to red.
  final int redDays;

  /// Minimum absolute change (in the metric's unit) to count as outside range.
  final double minDelta;

  RuleThresholds copyWith({
    double? sigma,
    double? redSigma,
    int? redDays,
    double? minDelta,
  }) {
    return RuleThresholds(
      sigma: sigma ?? this.sigma,
      redSigma: redSigma ?? this.redSigma,
      redDays: redDays ?? this.redDays,
      minDelta: minDelta ?? this.minDelta,
    );
  }
}

/// Family/personal background that makes a rule slightly more sensitive.
class HereditaryModifier {
  const HereditaryModifier({
    required this.tag,
    required this.label,
    required this.note,
    this.sigmaDelta = 0,
    this.minDurationDeltaDays = 0,
  });

  factory HereditaryModifier.fromJson(Map<String, dynamic> json) {
    return HereditaryModifier(
      tag: json['tag'] as String,
      label: json['label'] as String,
      note: json['note'] as String,
      sigmaDelta: (json['sigmaDelta'] as num?)?.toDouble() ?? 0,
      minDurationDeltaDays: (json['minDurationDeltaDays'] as num?)?.toInt() ?? 0,
    );
  }

  /// Matches a tag in `Profile.familyHistoryTags`.
  final String tag;
  final String label;
  final String note;

  /// Added to the rule's sigma (negative = more sensitive).
  final double sigmaDelta;

  /// Added to the rule's minimum duration (negative = flags sooner).
  final int minDurationDeltaDays;
}

/// An educational pattern rule loaded from `assets/rules/rules.json`.
///
/// Rules describe patterns worth noticing. They never diagnose conditions.
class Rule {
  const Rule({
    required this.id,
    required this.name,
    required this.summary,
    required this.metrics,
    required this.minDurationDays,
    required this.thresholds,
    required this.symptoms,
    required this.impactsPhysical,
    required this.impactsMental,
    required this.remedies,
    required this.specialist,
    required this.sources,
    required this.hereditaryModifiers,
  });

  factory Rule.fromJson(Map<String, dynamic> json) {
    final impacts = json['impacts'] as Map<String, dynamic>? ?? const {};
    final metrics = (json['metrics'] as List<dynamic>).map((value) {
      final name = value as String;
      for (final metric in VitalMetric.values) {
        if (metric.name == name) return metric;
      }
      throw FormatException('Unknown metric "$name" in rule "${json['id']}"');
    }).toList();
    if (metrics.isEmpty) {
      throw FormatException('Rule "${json['id']}" has no metrics');
    }
    return Rule(
      id: json['id'] as String,
      name: json['name'] as String,
      summary: json['summary'] as String,
      metrics: metrics,
      minDurationDays: (json['minDurationDays'] as num).toInt(),
      thresholds: RuleThresholds.fromJson(
        json['thresholds'] as Map<String, dynamic>,
      ),
      symptoms: _strings(json['symptoms']),
      impactsPhysical: _strings(impacts['physical']),
      impactsMental: _strings(impacts['mental']),
      remedies: _strings(json['remedies']),
      specialist: json['specialist'] as String,
      sources: _strings(json['sources']),
      hereditaryModifiers: ((json['hereditaryModifiers'] as List<dynamic>?) ??
              const [])
          .map((e) => HereditaryModifier.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static List<String> _strings(Object? value) =>
      ((value as List<dynamic>?) ?? const []).map((e) => e as String).toList();

  final String id;
  final String name;
  final String summary;

  /// Metrics evaluated by this rule. The first is the primary metric.
  final List<VitalMetric> metrics;

  /// Days a pattern must persist before it is surfaced.
  final int minDurationDays;
  final RuleThresholds thresholds;

  /// Things people sometimes notice alongside this pattern.
  final List<String> symptoms;
  final List<String> impactsPhysical;
  final List<String> impactsMental;

  /// Lifestyle-level suggestions only.
  final List<String> remedies;

  /// Type of clinician who could help interpret this pattern.
  final String specialist;

  /// Organisation names for further reading (no links).
  final List<String> sources;
  final List<HereditaryModifier> hereditaryModifiers;

  VitalMetric get primaryMetric => metrics.first;
  HealthDomain get domain => primaryMetric.domain;
}
