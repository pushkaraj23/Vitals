import '../models/doctor_review.dart';

// Later: backed by Health Connect + FastAPI.
abstract class DoctorReviewRepository {
  Future<List<DoctorReview>> getReviews();

  Future<DoctorReview?> getReviewForFlag(String flagId);

  /// Asks a clinician to look at the flag. Returns a pending review.
  Future<DoctorReview> requestReview(String flagId);
}
