import 'package:intl/intl.dart';

abstract final class AppDateUtils {
  static final DateFormat dayMonth = DateFormat('d MMM');
  static final DateFormat dayMonthYear = DateFormat('d MMM yyyy');
  static final DateFormat weekdayShort = DateFormat('EEE');
  static final DateFormat monthYear = DateFormat('MMM yyyy');

  static String relativeDay(DateTime date, {DateTime? now}) {
    final today = DateUtilsDate.dateOnly(now ?? DateTime.now());
    final target = DateUtilsDate.dateOnly(date);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return weekdayShort.format(date);
    return dayMonth.format(date);
  }

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static Iterable<DateTime> daysBack(int count, {DateTime? end}) sync* {
    final last = dateOnly(end ?? DateTime.now());
    for (var i = count - 1; i >= 0; i--) {
      yield last.subtract(Duration(days: i));
    }
  }
}

/// Local alias to avoid clashing with Flutter's DateUtils.
typedef DateUtilsDate = AppDateUtils;
