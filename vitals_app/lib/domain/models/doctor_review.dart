import 'enums.dart';

/// A clinician's review of a flag (sample data in the UI-only build).
class DoctorReview {
  const DoctorReview({
    required this.id,
    required this.flagId,
    required this.doctorName,
    required this.credentials,
    required this.verdict,
    required this.requestedAt,
    this.reviewedAt,
    this.note,
  });

  final String id;
  final String flagId;
  final String doctorName;
  final String credentials;
  final DoctorVerdict verdict;
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final String? note;

  bool get isPending => verdict == DoctorVerdict.pending;

  /// Badge shown next to the flag.
  DoctorBadgeState get badge {
    switch (verdict) {
      case DoctorVerdict.confirmed:
      case DoctorVerdict.notConcerning:
        return DoctorBadgeState.verified;
      case DoctorVerdict.needsConsultation:
        return DoctorBadgeState.needsConsultation;
      case DoctorVerdict.pending:
        return DoctorBadgeState.underReview;
    }
  }

  DoctorReview copyWith({
    DoctorVerdict? verdict,
    DateTime? reviewedAt,
    String? note,
  }) {
    return DoctorReview(
      id: id,
      flagId: flagId,
      doctorName: doctorName,
      credentials: credentials,
      verdict: verdict ?? this.verdict,
      requestedAt: requestedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      note: note ?? this.note,
    );
  }
}
