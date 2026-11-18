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
  final String verdict; // 'Confirmed'|'Not concerning'|'Needs consultation'|''
  final String note;
  final String reviewerName;
  final String reviewedAt; // yyyy-MM-dd
  final bool simulated;
  /// pending | in_review | reviewed
  final String? status;

  bool get isPending => status == 'pending' || status == 'in_review';

  bool get isInReview => status == 'in_review';

  bool get isReviewed =>
      status == 'reviewed' ||
      (!isPending &&
          verdict.isNotEmpty &&
          reviewerName.isNotEmpty &&
          reviewerName != 'Pending' &&
          reviewerName != 'Pending clinician assignment');

  String get statusLabel {
    if (isInReview) return 'In review';
    if (isPending) return 'Awaiting doctor';
    if (isReviewed) return 'Reviewed';
    return 'Requested';
  }

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
    return _col(uid).snapshots().map((s) {
      final reviews =
          s.docs.map((d) => ReviewModel.fromMap(d.id, d.data())).toList();
      reviews.sort((a, b) {
        final rank = _statusRank(a) - _statusRank(b);
        if (rank != 0) return rank;
        return b.reviewedAt.compareTo(a.reviewedAt);
      });
      return reviews;
    });
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

  /// Creates the portal enquiry first, then mirrors a pending review for the app.
  /// Enquiry-first avoids "requested" UI when the doctor queue write fails.
  Future<void> requestReview(
    String uid,
    String flagId, {
    String patientName = 'Patient',
    String? patientEmail,
    String flagTitle = 'Pattern flag',
    String flagLevel = '',
    String metric = '',
    String message = '',
  }) async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final note = message.trim().isEmpty
        ? 'Patient requested a doctor review of this pattern.'
        : message.trim();

    final enquiryRef = _db.collection('enquiries').doc('${uid}_$flagId');
    final enquiryPayload = <String, dynamic>{
      'patientId': uid,
      'patientName': patientName,
      if (patientEmail != null && patientEmail.isNotEmpty)
        'patientEmail': patientEmail,
      'flagId': flagId,
      'flagTitle': flagTitle,
      'flagLevel': flagLevel,
      'metric': metric,
      'message': note,
      'status': 'open',
      'verdict': null,
      'doctorNote': '',
      'doctorId': null,
      'doctorName': null,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Prefer create/merge without requiring a privileged pre-read.
    // If the doc already exists as open/in_review, keep status and refresh details.
    try {
      final existing = await enquiryRef.get();
      if (existing.exists) {
        final currentStatus = existing.data()?['status'] as String?;
        if (currentStatus == 'open' || currentStatus == 'in_review') {
          await enquiryRef.set({
            'message': note,
            'patientName': patientName,
            if (patientEmail != null && patientEmail.isNotEmpty)
              'patientEmail': patientEmail,
            'flagTitle': flagTitle,
            'flagLevel': flagLevel,
            'metric': metric,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          await enquiryRef.set({
            ...enquiryPayload,
            'createdAt':
                existing.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else {
        await enquiryRef.set({
          ...enquiryPayload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseException catch (e) {
      // Missing-doc get can fail under older rules; fall back to create.
      if (e.code == 'permission-denied') {
        await enquiryRef.set({
          ...enquiryPayload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        rethrow;
      }
    }

    await _col(uid).doc(flagId).set({
      'verdict': '',
      'note': note,
      'reviewerName': 'Pending',
      'reviewedAt': dateStr,
      'simulated': false,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static int _statusRank(ReviewModel review) {
    if (review.isInReview) return 0;
    if (review.isPending) return 1;
    return 2;
  }
}
