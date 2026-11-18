import 'enums.dart';

/// Something happening in life that can explain changes in vitals
/// (illness, travel, new medication, a stressful period...).
class LifeEvent {
  const LifeEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.startDate,
    this.endDate,
    this.note,
  });

  final String id;
  final LifeEventType type;
  final String title;
  final DateTime startDate;

  /// `null` means ongoing or a single-day event.
  final DateTime? endDate;
  final String? note;

  bool get isOngoing => endDate == null;

  LifeEvent copyWith({
    LifeEventType? type,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    String? note,
  }) {
    return LifeEvent(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      note: note ?? this.note,
    );
  }
}
