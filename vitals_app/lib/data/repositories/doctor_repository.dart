import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorModel {
  const DoctorModel({
    required this.uid,
    required this.name,
    required this.email,
    this.specialty,
    this.active = true,
  });

  final String uid;
  final String name;
  final String email;
  final String? specialty;
  final bool active;

  String get label {
    final specialtyLabel = specialty?.trim();
    if (specialtyLabel == null || specialtyLabel.isEmpty) return name;
    return '$name · $specialtyLabel';
  }

  factory DoctorModel.fromMap(String uid, Map<String, dynamic> m) {
    return DoctorModel(
      uid: uid,
      name: (m['name'] as String?)?.trim().isNotEmpty == true
          ? (m['name'] as String).trim()
          : 'Doctor',
      email: (m['email'] as String?)?.trim() ?? '',
      specialty: (m['specialty'] as String?)?.trim(),
      active: m['active'] != false,
    );
  }
}

class DoctorRepository {
  DoctorRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('doctors');

  Stream<List<DoctorModel>> watchActive() {
    return _col.snapshots().map((snap) {
      final doctors = snap.docs
          .map((d) => DoctorModel.fromMap(d.id, d.data()))
          .where((d) => d.active)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return doctors;
    });
  }

  Future<List<DoctorModel>> getActive() async {
    final snap = await _col.get();
    final doctors = snap.docs
        .map((d) => DoctorModel.fromMap(d.id, d.data()))
        .where((d) => d.active)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return doctors;
  }

  /// Deterministic auto-assignment from the active doctor list.
  DoctorModel? pickAuto(List<DoctorModel> doctors, String seed) {
    if (doctors.isEmpty) return null;
    final hash = seed.codeUnits.fold<int>(0, (a, b) => a + b);
    return doctors[hash % doctors.length];
  }
}
