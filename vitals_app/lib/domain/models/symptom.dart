import 'enums.dart';

/// A symptom the person logged themselves.
class Symptom {
  const Symptom({
    required this.id,
    required this.label,
    required this.date,
    this.severity = Severity.low,
    this.note,
    this.linkedFlagId,
  });

  final String id;
  final String label;
  final DateTime date;
  final Severity severity;
  final String? note;
  final String? linkedFlagId;

  Symptom copyWith({
    String? label,
    DateTime? date,
    Severity? severity,
    String? note,
    String? linkedFlagId,
  }) {
    return Symptom(
      id: id,
      label: label ?? this.label,
      date: date ?? this.date,
      severity: severity ?? this.severity,
      note: note ?? this.note,
      linkedFlagId: linkedFlagId ?? this.linkedFlagId,
    );
  }
}
