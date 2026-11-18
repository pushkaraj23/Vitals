enum BiologicalSex {
  female('Female'),
  male('Male'),
  other('Other');

  const BiologicalSex(this.label);

  final String label;
}

/// The person using the app.
class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.age,
    required this.sex,
    required this.heightCm,
    required this.weightKg,
    required this.occupation,
    required this.memberSince,
    this.familyHistoryTags = const [],
    this.goals = const [],
  });

  final String id;
  final String name;
  final int age;
  final BiologicalSex sex;
  final double heightCm;
  final double weightKg;
  final String occupation;
  final DateTime memberSince;

  /// Matches `HereditaryModifier.tag` values in the rules file,
  /// e.g. `cardiovascular`, `sleep_disorders`.
  final List<String> familyHistoryTags;
  final List<String> goals;

  String get firstName => name.split(' ').first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Profile copyWith({
    String? name,
    int? age,
    BiologicalSex? sex,
    double? heightCm,
    double? weightKg,
    String? occupation,
    List<String>? familyHistoryTags,
    List<String>? goals,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      occupation: occupation ?? this.occupation,
      memberSince: memberSince,
      familyHistoryTags: familyHistoryTags ?? this.familyHistoryTags,
      goals: goals ?? this.goals,
    );
  }
}
