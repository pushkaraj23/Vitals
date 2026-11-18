import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyHistoryItem {
  const FamilyHistoryItem({
    required this.relation,
    required this.condition,
    this.ageAtOnset,
  });

  final String relation;
  final String condition;
  final int? ageAtOnset;

  factory FamilyHistoryItem.fromMap(Map<String, dynamic> m) {
    return FamilyHistoryItem(
      relation: (m['relation'] as String?) ?? '',
      condition: (m['condition'] as String?) ?? '',
      ageAtOnset: (m['ageAtOnset'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    'relation': relation,
    'condition': condition,
    if (ageAtOnset != null) 'ageAtOnset': ageAtOnset,
  };
}

class ConsentInfo {
  const ConsentInfo({required this.healthData, this.acceptedAt});

  final bool healthData;
  final DateTime? acceptedAt;

  factory ConsentInfo.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const ConsentInfo(healthData: false);
    final ts = m['acceptedAt'];
    return ConsentInfo(
      healthData: (m['healthData'] as bool?) ?? false,
      acceptedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'healthData': healthData,
    if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
  };
}

class UserModel {
  const UserModel({
    required this.uid,
    this.name,
    this.email,
    this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.conditions = const [],
    this.medications = const [],
    this.allergies = const [],
    this.surgeries = const [],
    this.familyHistory = const [],
    this.isDemo = false,
    this.scenario,
    this.dataStart,
    this.dataEnd,
    this.onboardingComplete = false,
    this.consent = const ConsentInfo(healthData: false),
    this.lastSyncedAt,
  });

  final String uid;
  final String? name;
  final String? email;
  final int? age;
  final String? sex;
  final double? heightCm;
  final double? weightKg;
  final List<String> conditions;
  final List<String> medications;
  final List<String> allergies;
  final List<String> surgeries;
  final List<FamilyHistoryItem> familyHistory;
  final bool isDemo;
  final String? scenario;
  final String? dataStart;
  final String? dataEnd;
  final bool onboardingComplete;
  final ConsentInfo consent;
  final DateTime? lastSyncedAt;

  String get displayName => name ?? email ?? 'User';
  String get firstName => displayName.split(' ').first;

  bool get hasHereditaryRisk {
    final search = familyHistory.map((e) => e.condition.toLowerCase());
    return search.any(
      (c) =>
          c.contains('hypertension') ||
          c.contains('diabetes') ||
          c.contains('heart') ||
          c.contains('cardiovascular'),
    );
  }

  factory UserModel.fromMap(String uid, Map<String, dynamic> m) {
    final consentMap = m['consent'] as Map<String, dynamic>?;
    final lastSynced = m['lastSyncedAt'];
    return UserModel(
      uid: uid,
      name: m['name'] as String?,
      email: m['email'] as String?,
      age: (m['age'] as num?)?.toInt(),
      sex: m['sex'] as String?,
      heightCm: (m['heightCm'] as num?)?.toDouble(),
      weightKg: (m['weightKg'] as num?)?.toDouble(),
      conditions: _toStringList(m['conditions']),
      medications: _toStringList(m['medications']),
      allergies: _toStringList(m['allergies']),
      surgeries: _toStringList(m['surgeries']),
      familyHistory: ((m['familyHistory'] as List<dynamic>?) ?? [])
          .map((e) => FamilyHistoryItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      isDemo: (m['isDemo'] as bool?) ?? false,
      scenario: m['scenario'] as String?,
      dataStart: m['dataStart'] as String?,
      dataEnd: m['dataEnd'] as String?,
      onboardingComplete: (m['onboardingComplete'] as bool?) ?? false,
      consent: ConsentInfo.fromMap(consentMap),
      lastSyncedAt: lastSynced is Timestamp ? lastSynced.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
    if (name != null) 'name': name,
    if (email != null) 'email': email,
    if (age != null) 'age': age,
    if (sex != null) 'sex': sex,
    if (heightCm != null) 'heightCm': heightCm,
    if (weightKg != null) 'weightKg': weightKg,
    'conditions': conditions,
    'medications': medications,
    'allergies': allergies,
    'surgeries': surgeries,
    'familyHistory': familyHistory.map((e) => e.toMap()).toList(),
    'isDemo': isDemo,
    if (scenario != null) 'scenario': scenario,
    if (dataStart != null) 'dataStart': dataStart,
    if (dataEnd != null) 'dataEnd': dataEnd,
    'onboardingComplete': onboardingComplete,
    'consent': consent.toMap(),
    if (lastSyncedAt != null) 'lastSyncedAt': Timestamp.fromDate(lastSyncedAt!),
  };

  UserModel copyWith({
    String? name,
    String? email,
    int? age,
    String? sex,
    double? heightCm,
    double? weightKg,
    List<String>? conditions,
    List<String>? medications,
    List<String>? allergies,
    List<String>? surgeries,
    List<FamilyHistoryItem>? familyHistory,
    bool? isDemo,
    bool? onboardingComplete,
    ConsentInfo? consent,
    DateTime? lastSyncedAt,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      conditions: conditions ?? this.conditions,
      medications: medications ?? this.medications,
      allergies: allergies ?? this.allergies,
      surgeries: surgeries ?? this.surgeries,
      familyHistory: familyHistory ?? this.familyHistory,
      isDemo: isDemo ?? this.isDemo,
      scenario: scenario,
      dataStart: dataStart,
      dataEnd: dataEnd,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      consent: consent ?? this.consent,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  static List<String> _toStringList(dynamic v) =>
      ((v as List<dynamic>?) ?? []).map((e) => e as String).toList();
}

class UserRepository {
  UserRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  Stream<UserModel?> watchUser(String uid) {
    return _doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return UserModel.fromMap(snap.id, snap.data()!);
    });
  }

  Future<UserModel?> getUser(String uid) async {
    final snap = await _doc(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return UserModel.fromMap(snap.id, snap.data()!);
  }

  Future<void> setUser(String uid, UserModel user) async {
    await _doc(uid).set(user.toMap(), SetOptions(merge: true));
  }

  Future<void> updateField(String uid, Map<String, dynamic> data) async {
    await _doc(uid).set(data, SetOptions(merge: true));
  }

  Future<void> updateLastSynced(String uid, DateTime time) async {
    await _doc(uid).set({
      'lastSyncedAt': Timestamp.fromDate(time),
    }, SetOptions(merge: true));
  }

  Future<void> deleteUserData(String uid) async {
    final subcollections = [
      'daily',
      'baselines',
      'flags',
      'symptoms',
      'habits',
      'reviews',
    ];
    for (final col in subcollections) {
      final snap = await _doc(uid).collection(col).get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await _doc(uid).delete();
  }
}
