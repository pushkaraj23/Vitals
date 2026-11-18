import 'package:intl/intl.dart';

abstract final class Format {
  static final NumberFormat _oneDecimal = NumberFormat('0.0');
  static final NumberFormat _int = NumberFormat('#,##0');
  static final NumberFormat _compact = NumberFormat.compact();

  static String number(num value, {int decimals = 0}) {
    if (decimals <= 0) return _int.format(value.round());
    if (decimals == 1) return _oneDecimal.format(value);
    return value.toStringAsFixed(decimals);
  }

  static String percent(num value, {bool signed = false}) {
    final text = '${value.abs().toStringAsFixed(1)}%';
    if (!signed) return text;
    if (value > 0) return '+$text';
    if (value < 0) return '-$text';
    return text;
  }

  static String compact(num value) => _compact.format(value);

  static String durationDays(int days) {
    if (days == 1) return '1 day';
    if (days < 14) return '$days days';
    final weeks = (days / 7).round();
    if (weeks < 8) return weeks == 1 ? '1 week' : '$weeks weeks';
    final months = (days / 30).round().clamp(1, 24);
    return months == 1 ? '1 month' : '$months months';
  }
}
