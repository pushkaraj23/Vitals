import 'package:cloud_firestore/cloud_firestore.dart';

class RuleImpactItem {
  const RuleImpactItem({required this.timeframe, required this.text});
  final String timeframe;
  final String text;

  factory RuleImpactItem.fromMap(Map<String, dynamic> m) => RuleImpactItem(
    timeframe: (m['timeframe'] as String?) ?? '',
    text: (m['text'] as String?) ?? '',
  );

  Map<String, dynamic> toMap() => {'timeframe': timeframe, 'text': text};
}

class RuleModel {
  const RuleModel({
    required this.id,
    required this.metric,
    required this.direction,
    required this.title,
    required this.explanation,
    required this.specialist,
    this.minDeltaAbs,
    this.minDeltaPct,
    required this.amberDays,
    required this.redDays,
    required this.minDataDays,
    required this.requires,
    required this.symptoms,
    required this.impacts,
    required this.remedies,
    required this.version,
    required this.reviewedBy,
  });

  final String id;
  final String metric;
  final String direction; // 'up'|'down'
  final String title;
  final String explanation;
  final String specialist;
  final double? minDeltaAbs;
  final double? minDeltaPct;
  final int amberDays;
  final int redDays;
  final int minDataDays;
  final List<String> requires;
  final List<String> symptoms;
  final List<RuleImpactItem> impacts;
  final List<String> remedies;
  final int version;
  final String reviewedBy;

  factory RuleModel.fromMap(String id, Map<String, dynamic> m) {
    return RuleModel(
      id: id,
      metric: (m['metric'] as String?) ?? '',
      direction: (m['direction'] as String?) ?? 'up',
      title: (m['title'] as String?) ?? '',
      explanation: (m['explanation'] as String?) ?? '',
      specialist: (m['specialist'] as String?) ?? '',
      minDeltaAbs: (m['minDeltaAbs'] as num?)?.toDouble(),
      minDeltaPct: (m['minDeltaPct'] as num?)?.toDouble(),
      amberDays: (m['amberDays'] as num?)?.toInt() ?? 7,
      redDays: (m['redDays'] as num?)?.toInt() ?? 21,
      minDataDays: (m['minDataDays'] as num?)?.toInt() ?? 14,
      requires: _toStringList(m['requires']),
      symptoms: _toStringList(m['symptoms']),
      impacts: ((m['impacts'] as List<dynamic>?) ?? [])
          .map((e) => RuleImpactItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      remedies: _toStringList(m['remedies']),
      version: (m['version'] as num?)?.toInt() ?? 1,
      reviewedBy: (m['reviewedBy'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'metric': metric,
    'direction': direction,
    'title': title,
    'explanation': explanation,
    'specialist': specialist,
    if (minDeltaAbs != null) 'minDeltaAbs': minDeltaAbs,
    if (minDeltaPct != null) 'minDeltaPct': minDeltaPct,
    'amberDays': amberDays,
    'redDays': redDays,
    'minDataDays': minDataDays,
    'requires': requires,
    'symptoms': symptoms,
    'impacts': impacts.map((e) => e.toMap()).toList(),
    'remedies': remedies,
    'version': version,
    'reviewedBy': reviewedBy,
  };

  static List<String> _toStringList(dynamic v) =>
      ((v as List<dynamic>?) ?? []).map((e) => e as String).toList();
}

class RuleRepository {
  RuleRepository(this._db);
  final FirebaseFirestore _db;

  Future<List<RuleModel>> getAll() async {
    final snap = await _db.collection('rules').get();
    return snap.docs.map((d) => RuleModel.fromMap(d.id, d.data())).toList();
  }

  Stream<List<RuleModel>> watchAll() {
    return _db.collection('rules').snapshots().map(
          (s) => s.docs.map((d) => RuleModel.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<RuleModel?> getOne(String ruleId) async {
    final snap = await _db.collection('rules').doc(ruleId).get();
    if (!snap.exists || snap.data() == null) return null;
    return RuleModel.fromMap(snap.id, snap.data()!);
  }
}
