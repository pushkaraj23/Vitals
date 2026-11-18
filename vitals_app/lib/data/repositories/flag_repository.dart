import 'package:cloud_firestore/cloud_firestore.dart';

class FlagModel {
  const FlagModel({
    required this.id,
    required this.ruleId,
    required this.level,
    required this.metric,
    required this.startDate,
    required this.durationDays,
    required this.severity,
    required this.confidence,
    required this.title,
    required this.explanation,
    required this.dataUsed,
    required this.source,
    this.baselineValue,
    this.currentValue,
    this.aiExplanation,
  });

  final String id;
  final String ruleId;
  final String level; // 'green'|'amber'|'red'
  final String metric;
  final String startDate; // yyyy-MM-dd
  final int durationDays;
  final int severity; // 1-3
  final String confidence; // 'low'|'medium'|'high'
  final String title;
  final String explanation;
  final List<String> dataUsed;
  final String source; // 'seed'|'engine'
  final double? baselineValue;
  final double? currentValue;
  final String? aiExplanation;

  factory FlagModel.fromMap(String id, Map<String, dynamic> m) {
    return FlagModel(
      id: id,
      ruleId: (m['ruleId'] as String?) ?? '',
      level: (m['level'] as String?) ?? 'green',
      metric: (m['metric'] as String?) ?? '',
      startDate: (m['startDate'] as String?) ?? '',
      durationDays: (m['durationDays'] as num?)?.toInt() ?? 0,
      severity: (m['severity'] as num?)?.toInt() ?? 1,
      confidence: (m['confidence'] as String?) ?? 'medium',
      title: (m['title'] as String?) ?? '',
      explanation: (m['explanation'] as String?) ?? '',
      dataUsed: ((m['dataUsed'] as List<dynamic>?) ?? [])
          .map((e) => e as String)
          .toList(),
      source: (m['source'] as String?) ?? 'engine',
      baselineValue: (m['baselineValue'] as num?)?.toDouble(),
      currentValue: (m['currentValue'] as num?)?.toDouble(),
      aiExplanation: m['aiExplanation'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'ruleId': ruleId,
      'level': level,
      'metric': metric,
      'startDate': startDate,
      'durationDays': durationDays,
      'severity': severity,
      'confidence': confidence,
      'title': title,
      'explanation': explanation,
      'dataUsed': dataUsed,
      'source': source,
    };
    if (baselineValue != null) m['baselineValue'] = baselineValue;
    if (currentValue != null) m['currentValue'] = currentValue;
    if (aiExplanation != null) m['aiExplanation'] = aiExplanation;
    return m;
  }
}

class FlagRepository {
  FlagRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('flags');

  Stream<List<FlagModel>> watchAll(String uid) {
    return _col(uid).snapshots().map(
          (s) => s.docs.map((d) => FlagModel.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<List<FlagModel>> getAll(String uid) async {
    final snap = await _col(uid).get();
    return snap.docs.map((d) => FlagModel.fromMap(d.id, d.data())).toList();
  }

  Future<FlagModel?> getOne(String uid, String flagId) async {
    final snap = await _col(uid).doc(flagId).get();
    if (!snap.exists || snap.data() == null) return null;
    return FlagModel.fromMap(snap.id, snap.data()!);
  }

  Stream<FlagModel?> watchOne(String uid, String flagId) {
    return _col(uid).doc(flagId).snapshots().map((s) {
      if (!s.exists || s.data() == null) return null;
      return FlagModel.fromMap(s.id, s.data()!);
    });
  }

  Future<void> setFlag(String uid, FlagModel flag) async {
    await _col(uid).doc(flag.id).set(flag.toMap());
  }

  Future<void> setFlagBatch(String uid, List<FlagModel> flags) async {
    final batch = _db.batch();
    for (final f in flags) {
      batch.set(_col(uid).doc(f.id), f.toMap());
    }
    await batch.commit();
  }

  Future<void> pruneEngineFlags(String uid, Set<String> keepIds) async {
    final snap = await _col(uid).where('source', isEqualTo: 'engine').get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      if (!keepIds.contains(d.id)) {
        batch.delete(d.reference);
      }
    }
    await batch.commit();
  }
}
