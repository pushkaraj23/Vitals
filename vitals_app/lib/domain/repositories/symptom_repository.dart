import '../models/symptom.dart';

// Later: backed by Health Connect + FastAPI.
abstract class SymptomRepository {
  /// Logged symptoms, newest first.
  Future<List<Symptom>> getSymptoms();

  Future<List<Symptom>> addSymptom(Symptom symptom);

  Future<List<Symptom>> removeSymptom(String id);

  /// Quick-pick labels (drawn from the rules library).
  Future<List<String>> getSuggestedSymptoms();
}
