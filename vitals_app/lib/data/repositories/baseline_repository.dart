import 'package:cloud_firestore/cloud_firestore.dart';

class BaselineModel {
  const BaselineModel({
    required this.metric,
    required this.mean,
    required this.std,
    required this.n,
    required this.calibratedUntil,
  });

  final String metric;
  final double mean;
  final double std;
  final int n;
  final String calibratedUntil; // yyyy-MM-dd

  factory BaselineModel.fromMap(String metric, Map<String, dynamic> m) {
    return BaselineModel(
      metric: metric,
      mean: (m['mean'] as num?)?.toDouble() ?? 0.0,
      std: (m['std'] as num?)?.toDouble() ?? 0.0,
      n: (m['n'] as num?)?.toInt() ?? 0,
      calibratedUntil: (m['calibratedUntil'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'mean': mean,
    'std': std,
    'n': n,
    'calibratedUntil': calibratedUntil,
  };
}

class BaselineRepository {
  BaselineRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('baselines');

  Future<Map<String, BaselineModel>> getAll(String uid) async {
    final snap = await _col(uid).get();
    return {
      for (final d in snap.docs)
        d.id: BaselineModel.fromMap(d.id, d.data()),
    };
  }

  Stream<Map<String, BaselineModel>> watchAll(String uid) {
    return _col(uid).snapshots().map((s) => {
          for (final d in s.docs)
            d.id: BaselineModel.fromMap(d.id, d.data()),
        });
  }

  Future<void> setBaseline(String uid, BaselineModel baseline) async {
    await _col(uid).doc(baseline.metric).set(baseline.toMap());
  }

  Future<void> setBatch(String uid, List<BaselineModel> baselines) async {
    final batch = _db.batch();
    for (final b in baselines) {
      batch.set(_col(uid).doc(b.metric), b.toMap());
    }
    await batch.commit();
  }
}
