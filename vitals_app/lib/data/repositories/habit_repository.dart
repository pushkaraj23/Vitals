import 'package:cloud_firestore/cloud_firestore.dart';

class HabitProgressItem {
  const HabitProgressItem({required this.date, required this.done});
  final String date; // yyyy-MM-dd
  final bool done;

  factory HabitProgressItem.fromMap(Map<String, dynamic> m) => HabitProgressItem(
    date: (m['date'] as String?) ?? '',
    done: (m['done'] as bool?) ?? false,
  );

  Map<String, dynamic> toMap() => {'date': date, 'done': done};
}

class HabitModel {
  const HabitModel({
    required this.id,
    required this.templateId,
    required this.title,
    this.linkedFlag,
    required this.startDate,
    required this.durationDays,
    required this.progress,
    this.metric,
    this.metricBefore,
    this.metricAfter,
  });

  final String id;
  final String templateId;
  final String title;
  final String? linkedFlag;
  final String startDate; // yyyy-MM-dd
  final int durationDays;
  final List<HabitProgressItem> progress;
  final String? metric;
  final double? metricBefore;
  final double? metricAfter;

  int get completedCount => progress.where((p) => p.done).length;

  factory HabitModel.fromMap(String id, Map<String, dynamic> m) {
    return HabitModel(
      id: id,
      templateId: (m['templateId'] as String?) ?? '',
      title: (m['title'] as String?) ?? '',
      linkedFlag: m['linkedFlag'] as String?,
      startDate: (m['startDate'] as String?) ?? '',
      durationDays: (m['durationDays'] as num?)?.toInt() ?? 14,
      progress: ((m['progress'] as List<dynamic>?) ?? [])
          .map((e) => HabitProgressItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      metric: m['metric'] as String?,
      metricBefore: (m['metricBefore'] as num?)?.toDouble(),
      metricAfter: (m['metricAfter'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'templateId': templateId,
    'title': title,
    if (linkedFlag != null) 'linkedFlag': linkedFlag,
    'startDate': startDate,
    'durationDays': durationDays,
    'progress': progress.map((p) => p.toMap()).toList(),
    if (metric != null) 'metric': metric,
    if (metricBefore != null) 'metricBefore': metricBefore,
    if (metricAfter != null) 'metricAfter': metricAfter,
  };

  HabitModel copyWith({
    List<HabitProgressItem>? progress,
    double? metricAfter,
  }) {
    return HabitModel(
      id: id,
      templateId: templateId,
      title: title,
      linkedFlag: linkedFlag,
      startDate: startDate,
      durationDays: durationDays,
      progress: progress ?? this.progress,
      metric: metric,
      metricBefore: metricBefore,
      metricAfter: metricAfter ?? this.metricAfter,
    );
  }
}

class HabitRepository {
  HabitRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('habits');

  Stream<List<HabitModel>> watchAll(String uid) {
    return _col(uid).snapshots().map(
          (s) => s.docs.map((d) => HabitModel.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<List<HabitModel>> getAll(String uid) async {
    final snap = await _col(uid).get();
    return snap.docs.map((d) => HabitModel.fromMap(d.id, d.data())).toList();
  }

  Future<void> createHabit(String uid, HabitModel habit) async {
    await _col(uid).doc(habit.id).set(habit.toMap());
  }

  Future<void> updateProgress(
    String uid,
    String habitId,
    List<HabitProgressItem> progress,
  ) async {
    await _col(uid).doc(habitId).update({
      'progress': progress.map((p) => p.toMap()).toList(),
    });
  }

  Future<void> updateMetricAfter(
    String uid,
    String habitId,
    double metricAfter,
  ) async {
    await _col(uid).doc(habitId).update({'metricAfter': metricAfter});
  }

  Future<void> deleteHabit(String uid, String habitId) async {
    await _col(uid).doc(habitId).delete();
  }
}
