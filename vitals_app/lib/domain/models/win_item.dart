import 'enums.dart';

/// A positive moment worth celebrating (steady vitals, habit streaks...).
class WinItem {
  const WinItem({
    required this.id,
    required this.title,
    required this.description,
    required this.domain,
    required this.achievedOn,
  });

  final String id;
  final String title;
  final String description;
  final HealthDomain domain;
  final DateTime achievedOn;
}
