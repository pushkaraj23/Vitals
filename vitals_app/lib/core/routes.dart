/// Route paths used by the feature screens. The router (not part of the
/// feature screens) must register these.
abstract final class AppRoutes {
  static const home = '/home';
  static const flags = '/flags';
  static String flag(String id) => '/flags/$id';

  static const timeline = '/timeline';
  static const habits = '/habits';
  static const breathing = '/habits/breathing';
  static const symptoms = '/symptoms';

  static const alerts = '/alerts';
  static const alertPreferences = '/alerts/preferences';
  static const emergency = '/emergency';

  static const doctors = '/doctors';
  static String doctorReview(String id) => '/doctors/$id';

  static const reports = '/reports';
  static const profile = '/profile';
  static const devices = '/profile/devices';
  static const settings = '/settings';
  static const designPreview = '/design-preview';
}
