import 'package:cloud_firestore/cloud_firestore.dart';

class SymptomModel {
  const SymptomModel({
    required this.id,
    required this.symptom,
    required this.date,
    this.flagId,
  });

  final String id;
  final String symptom;
  final String date; // yyyy-MM-dd
  final String? flagId;

  factory SymptomModel.fromMap(String id, Map<String, dynamic> m) {
    return SymptomModel(
      id: id,
      symptom: (m['symptom'] as String?) ?? '',
      date: (m['date'] as String?) ?? '',
      flagId: m['flagId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'symptom': symptom,
    'date': date,
    if (flagId != null) 'flagId': flagId,
  };
}

class SymptomRepository {
  SymptomRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('symptoms');

  Stream<List<SymptomModel>> watchAll(String uid) {
    return _col(uid).snapshots().map(
          (s) =>
              s.docs
                  .map((d) => SymptomModel.fromMap(d.id, d.data()))
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date)),
        );
  }

  Future<List<SymptomModel>> getAll(String uid) async {
    final snap = await _col(uid).get();
    final list =
        snap.docs.map((d) => SymptomModel.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> addSymptom(String uid, SymptomModel symptom) async {
    await _col(uid).doc(symptom.id).set(symptom.toMap());
  }

  Future<void> deleteSymptom(String uid, String symptomId) async {
    await _col(uid).doc(symptomId).delete();
  }
}
