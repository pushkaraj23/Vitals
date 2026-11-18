import 'enums.dart';

enum DeviceKind {
  phone('Phone'),
  watch('Smartwatch'),
  ring('Smart ring'),
  band('Fitness band');

  const DeviceKind(this.label);

  final String label;
}

/// A data source (wearable or aggregator) connected to the app.
class Device {
  const Device({
    required this.id,
    required this.name,
    required this.kind,
    required this.connected,
    this.lastSyncedAt,
    this.batteryPercent,
    this.metrics = const [],
  });

  final String id;
  final String name;
  final DeviceKind kind;
  final bool connected;
  final DateTime? lastSyncedAt;
  final int? batteryPercent;
  final List<VitalMetric> metrics;

  Device copyWith({
    bool? connected,
    DateTime? lastSyncedAt,
    int? batteryPercent,
  }) {
    return Device(
      id: id,
      name: name,
      kind: kind,
      connected: connected ?? this.connected,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      metrics: metrics,
    );
  }
}
