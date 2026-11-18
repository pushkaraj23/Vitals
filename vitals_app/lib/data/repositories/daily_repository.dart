import 'package:cloud_firestore/cloud_firestore.dart';

class DailyModel {
  const DailyModel({
    required this.date,
    this.restingHr,
    this.hrv,
    this.sleepDeep,
    this.sleepTotal,
    this.spo2,
    this.steps,
    required this.source,
  });

  final String date; // yyyy-MM-dd
  final double? restingHr;
  final double? hrv;
  final double? sleepDeep; // minutes
  final double? sleepTotal; // minutes
  final double? spo2;
  final double? steps;
  final String source; // 'synthetic' | 'health_connect' | 'manual'

  bool get isGap =>
      restingHr == null &&
      hrv == null &&
      sleepDeep == null &&
      sleepTotal == null &&
      spo2 == null &&
      steps == null;

  factory DailyModel.fromMap(String date, Map<String, dynamic> m) {
    return DailyModel(
      date: (m['date'] as String?) ?? date,
      restingHr: (m['restingHr'] as num?)?.toDouble(),
      hrv: (m['hrv'] as num?)?.toDouble(),
      sleepDeep: (m['sleepDeep'] as num?)?.toDouble(),
      sleepTotal: (m['sleepTotal'] as num?)?.toDouble(),
      spo2: (m['spo2'] as num?)?.toDouble(),
      steps: (m['steps'] as num?)?.toDouble(),
      source: (m['source'] as String?) ?? 'manual',
    );
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{'date': date, 'source': source};
    if (restingHr != null) m['restingHr'] = restingHr;
    if (hrv != null) m['hrv'] = hrv;
    if (sleepDeep != null) m['sleepDeep'] = sleepDeep;
    if (sleepTotal != null) m['sleepTotal'] = sleepTotal;
    if (spo2 != null) m['spo2'] = spo2;
    if (steps != null) m['steps'] = steps;
    return m;
  }
}

class DailyRepository {
  DailyRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('daily');

  Stream<List<DailyModel>> watchAll(String uid) {
    return _col(uid).orderBy('date').snapshots().map(
          (s) => s.docs
              .map((d) => DailyModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<List<DailyModel>> getAll(String uid) async {
    final snap = await _col(uid).orderBy('date').get();
    return snap.docs.map((d) => DailyModel.fromMap(d.id, d.data())).toList();
  }

  Future<List<DailyModel>> getRange(
    String uid,
    String startDate,
    String endDate,
  ) async {
    final snap = await _col(uid)
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .orderBy('date')
        .get();
    return snap.docs.map((d) => DailyModel.fromMap(d.id, d.data())).toList();
  }

  Future<void> upsertBatch(String uid, List<DailyModel> days) async {
    const batchSize = 400;
    for (var i = 0; i < days.length; i += batchSize) {
      final chunk = days.sublist(i, (i + batchSize).clamp(0, days.length));
      final batch = _db.batch();
      for (final day in chunk) {
        if (day.isGap) continue; // Never write a gap doc
        final ref = _col(uid).doc(day.date);
        batch.set(ref, day.toMap(), SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  Future<int> countDays(String uid) async {
    final snap = await _col(uid).get();
    return snap.docs.length;
  }
}
