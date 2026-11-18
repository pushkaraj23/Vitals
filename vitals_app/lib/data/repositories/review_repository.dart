import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  const ReviewModel({
    required this.flagId,
    required this.verdict,
    required this.note,
    required this.reviewerName,
    required this.reviewedAt,
    required this.simulated,
    this.status,
  });

  final String flagId;
  final String verdict; // 'Confirmed'|'Not concerning'|'Needs consultation'
  final String note;
  final String reviewerName;
  final String reviewedAt; // yyyy-MM-dd
  final bool simulated;
  final String? status; // 'pending'

  bool get isPending => status == 'pending';

  factory ReviewModel.fromMap(String flagId, Map<String, dynamic> m) {
    final reviewedAt = m['reviewedAt'];
    String reviewedAtStr;
    if (reviewedAt is Timestamp) {
      final dt = reviewedAt.toDate();
      reviewedAtStr =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } else {
      reviewedAtStr = (reviewedAt as String?) ?? '';
    }
    return ReviewModel(
      flagId: flagId,
      verdict: (m['verdict'] as String?) ?? '',
      note: (m['note'] as String?) ?? '',
      reviewerName: (m['reviewerName'] as String?) ?? '',
      reviewedAt: reviewedAtStr,
      simulated: (m['simulated'] as bool?) ?? false,
      status: m['status'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'verdict': verdict,
    'note': note,
    'reviewerName': reviewerName,
    'reviewedAt': reviewedAt,
    'simulated': simulated,
    if (status != null) 'status': status,
  };
}

class ReviewRepository {
  ReviewRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('reviews');

  Stream<List<ReviewModel>> watchAll(String uid) {
    return _col(uid).snapshots().map(
          (s) =>
              s.docs.map((d) => ReviewModel.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<List<ReviewModel>> getAll(String uid) async {
    final snap = await _col(uid).get();
    return snap.docs.map((d) => ReviewModel.fromMap(d.id, d.data())).toList();
  }

  Stream<ReviewModel?> watchForFlag(String uid, String flagId) {
    return _col(uid).doc(flagId).snapshots().map((s) {
      if (!s.exists || s.data() == null) return null;
      return ReviewModel.fromMap(s.id, s.data()!);
    });
  }

  Future<ReviewModel?> getForFlag(String uid, String flagId) async {
    final snap = await _col(uid).doc(flagId).get();
    if (!snap.exists || snap.data() == null) return null;
    return ReviewModel.fromMap(snap.id, snap.data()!);
  }

  Future<void> setReview(String uid, ReviewModel review) async {
    await _col(uid).doc(review.flagId).set(review.toMap());
  }

  Future<void> requestReview(String uid, String flagId) async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await _col(uid).doc(flagId).set({
      'verdict': 'Needs consultation',
      'note':
          'Review request submitted. Doctor review is not available yet in this prototype.',
      'reviewerName': 'Pending clinician assignment',
      'reviewedAt': dateStr,
      'simulated': false,
      'status': 'pending',
    }, SetOptions(merge: true));
  }
}
