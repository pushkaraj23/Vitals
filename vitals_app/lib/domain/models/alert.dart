import 'enums.dart';

/// A notification-style message tied (optionally) to a flag.
class Alert {
  const Alert({
    required this.id,
    required this.tier,
    required this.title,
    required this.message,
    required this.createdAt,
    this.flagId,
    this.isRead = false,
    this.actionLabel,
  });

  final String id;
  final AlertTier tier;
  final String title;
  final String message;
  final DateTime createdAt;
  final String? flagId;
  final bool isRead;
  final String? actionLabel;

  Alert copyWith({bool? isRead}) {
    return Alert(
      id: id,
      tier: tier,
      title: title,
      message: message,
      createdAt: createdAt,
      flagId: flagId,
      isRead: isRead ?? this.isRead,
      actionLabel: actionLabel,
    );
  }
}
