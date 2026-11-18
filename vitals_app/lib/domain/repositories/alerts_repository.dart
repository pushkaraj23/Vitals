import '../models/alert.dart';

// Later: backed by Health Connect + FastAPI.
abstract class AlertsRepository {
  /// Alerts, newest first.
  Future<List<Alert>> getAlerts();

  Future<List<Alert>> markRead(String id);

  Future<List<Alert>> markAllRead();

  Future<List<Alert>> dismiss(String id);
}
