import '../models/consent.dart';
import '../models/device.dart';
import '../models/settings.dart';

// Later: backed by Health Connect + FastAPI.
abstract class SettingsRepository {
  Future<AppSettings> getSettings();

  Future<AppSettings> updateSettings(AppSettings settings);

  Future<List<Consent>> getConsents();

  Future<List<Consent>> setConsent(String id, {required bool granted});

  Future<List<Device>> getDevices();

  Future<List<Device>> setDeviceConnected(String id, {required bool connected});

  /// Syncs one device. Returns the updated device list.
  Future<List<Device>> syncDevice(String id);
}
