import '../models/life_event.dart';
import '../models/profile.dart';

// Later: backed by Health Connect + FastAPI.
abstract class ProfileRepository {
  Future<Profile> getProfile();

  Future<Profile> updateProfile(Profile profile);

  /// Life events, newest first.
  Future<List<LifeEvent>> getLifeEvents();

  Future<List<LifeEvent>> addLifeEvent(LifeEvent event);

  Future<List<LifeEvent>> removeLifeEvent(String id);
}
