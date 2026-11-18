import 'package:cloud_firestore/cloud_firestore.dart';

class HabitTemplateModel {
  const HabitTemplateModel({
    required this.id,
    required this.title,
    required this.linkedRule,
    required this.targetPerDay,
    required this.durationDays,
  });

  final String id;
  final String title;
  final String linkedRule;
  final int targetPerDay;
  final int durationDays;

  factory HabitTemplateModel.fromMap(String id, Map<String, dynamic> m) {
    return HabitTemplateModel(
      id: id,
      title: (m['title'] as String?) ?? '',
      linkedRule: (m['linkedRule'] as String?) ?? '',
      targetPerDay: (m['targetPerDay'] as num?)?.toInt() ?? 1,
      durationDays: (m['durationDays'] as num?)?.toInt() ?? 14,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'linkedRule': linkedRule,
    'targetPerDay': targetPerDay,
    'durationDays': durationDays,
  };
}

class HabitTemplateRepository {
  HabitTemplateRepository(this._db);
  final FirebaseFirestore _db;

  Future<List<HabitTemplateModel>> getAll() async {
    final snap = await _db.collection('habitTemplates').get();
    return snap.docs
        .map((d) => HabitTemplateModel.fromMap(d.id, d.data()))
        .toList();
  }

  Stream<List<HabitTemplateModel>> watchAll() {
    return _db.collection('habitTemplates').snapshots().map(
          (s) => s.docs
              .map((d) => HabitTemplateModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }
}
