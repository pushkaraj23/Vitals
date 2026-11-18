import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

import '../../providers/repository_providers.dart';

/// Tracks the current Health Connect authorisation state.
enum HcAuthState {
  /// We haven't asked yet (or the platform is not Android).
  unknown,
  /// User granted all permissions.
  granted,
  /// User denied one or more permissions.
  denied,
  /// An unexpected error occurred.
  error,
}

/// Notifier that drives the Health Connect permission flow.
class HealthConnectAuthNotifier extends AsyncNotifier<HcAuthState> {
  @override
  Future<HcAuthState> build() async {
    if (!Platform.isAndroid) return HcAuthState.unknown;
    final repo = ref.read(healthConnectRepositoryProvider);
    final has = await repo.hasAuthorization();
    return has ? HcAuthState.granted : HcAuthState.unknown;
  }

  /// Show the Health Connect permission dialog.
  Future<void> requestPermissions() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(healthConnectRepositoryProvider);
      final granted = await repo.requestAuthorization();
      return granted ? HcAuthState.granted : HcAuthState.denied;
    });
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Drives the permission UI.
final hcAuthProvider =
    AsyncNotifierProvider<HealthConnectAuthNotifier, HcAuthState>(
  HealthConnectAuthNotifier.new,
);

/// `true` once the user has granted all Health Connect permissions.
final hcAuthorizedProvider = Provider<bool>((ref) {
  return ref.watch(hcAuthProvider).value == HcAuthState.granted;
});

/// Returns `true` if the app is running on Android AND Health Connect is
/// available on the device (i.e. the app is installed).
final hcAvailableProvider = FutureProvider<bool>((ref) async {
  if (!Platform.isAndroid) return false;
  return Health().isHealthConnectAvailable();
});
