/// A data-use permission the person can grant or withdraw.
class Consent {
  const Consent({
    required this.id,
    required this.title,
    required this.description,
    required this.granted,
    this.isRequired = false,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final bool granted;

  /// Required consents cannot be switched off while the app is in use.
  final bool isRequired;
  final DateTime? updatedAt;

  Consent copyWith({bool? granted, DateTime? updatedAt}) {
    return Consent(
      id: id,
      title: title,
      description: description,
      granted: granted ?? this.granted,
      isRequired: isRequired,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
