import 'enums.dart';

/// A small daily habit the person is tracking.
class Habit {
  const Habit({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.domain,
    required this.targetDaysPerWeek,
    this.completedDates = const [],
    this.linkedRuleId,
  });

  final String id;
  final String title;
  final String subtitle;
  final HealthDomain domain;
  final int targetDaysPerWeek;

  /// Date-only values.
  final List<DateTime> completedDates;
  final String? linkedRuleId;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  bool isDoneOn(DateTime date) {
    final day = _day(date);
    return completedDates.any((d) => d == day);
  }

  /// Consecutive completed days ending today (or yesterday if today is open).
  int currentStreak({DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    var cursor = isDoneOn(today) ? today : today.subtract(const Duration(days: 1));
    var streak = 0;
    while (isDoneOn(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Completions in the 7 days ending [now].
  int completionsThisWeek({DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final start = today.subtract(const Duration(days: 6));
    return completedDates
        .where((d) => !d.isBefore(start) && !d.isAfter(today))
        .length;
  }

  Habit toggled(DateTime date) {
    final day = _day(date);
    final next = List<DateTime>.of(completedDates);
    if (!next.remove(day)) next.add(day);
    next.sort();
    return copyWith(completedDates: next);
  }

  Habit copyWith({
    String? title,
    String? subtitle,
    int? targetDaysPerWeek,
    List<DateTime>? completedDates,
  }) {
    return Habit(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      domain: domain,
      targetDaysPerWeek: targetDaysPerWeek ?? this.targetDaysPerWeek,
      completedDates: completedDates ?? this.completedDates,
      linkedRuleId: linkedRuleId,
    );
  }
}
