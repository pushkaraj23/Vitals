import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/health_connect/health_connect_auth_notifier.dart';
import '../data/health_connect/health_connect_repository.dart';
import '../data/mock/mock_repositories.dart';
import '../data/mock/mock_store.dart';
import '../data/mock/rules_loader.dart';
import '../domain/models/rule.dart';
import '../domain/repositories/alerts_repository.dart';
import '../domain/repositories/doctor_review_repository.dart';
import '../domain/repositories/flags_repository.dart';
import '../domain/repositories/habits_repository.dart';
import '../domain/repositories/health_data_repository.dart';
import '../domain/repositories/profile_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/repositories/symptom_repository.dart';
import 'persona_provider.dart';

/// Riverpod retries failed providers by default. For a demo that must show
/// error states (and the "force error" tool), we want a single attempt.
Duration? noRetry(int retryCount, Object error) => null;

final rulesLoaderProvider = Provider<RulesLoader>((ref) => const RulesLoader());

/// The educational rules library (`assets/rules/rules.json`).
final rulesProvider = FutureProvider<List<Rule>>(
  (ref) => ref.watch(rulesLoaderProvider).load(),
  retry: noRetry,
);

/// Simulated network latency of the mock repositories. Override in tests.
final mockLatencyProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 600),
);

/// "Today" for generated data. Override in tests for determinism.
final mockClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Settings, consents and devices; survives persona switches.
final mockSessionProvider = Provider<MockSession>((ref) => MockSession());

/// Generated sample data for the active persona. Rebuilds (regenerates)
/// whenever the persona changes.
final mockStoreProvider = FutureProvider<MockStore>((ref) async {
  final persona = ref.watch(currentPersonaProvider);
  final rules = await ref.watch(rulesProvider.future);
  final now = ref.read(mockClockProvider)();
  return MockStore.create(persona: persona, rules: rules, now: now);
}, retry: noRetry);

final mockBackendProvider = Provider<MockBackend>((ref) {
  return MockBackend(
    session: ref.watch(mockSessionProvider),
    store: ref.watch(mockStoreProvider.future),
    latency: ref.watch(mockLatencyProvider),
  );
});

// ── Health Connect real repositories ──────────────────────────────────────────

final healthConnectRepositoryProvider = Provider<HealthConnectRepository>((ref) {
  final backend = ref.watch(mockBackendProvider);
  return HealthConnectRepository(
    loadRules: () => ref.watch(rulesProvider.future),
    profileRepository: MockProfileRepository(backend),
    habitsRepository: MockHabitsRepository(backend),
    alertsRepository: MockAlertsRepository(backend),
  );
});

final healthConnectFlagsRepositoryProvider =
    Provider<HealthConnectFlagsRepository>((ref) {
  final backend = ref.watch(mockBackendProvider);
  return HealthConnectFlagsRepository(
    healthRepo: ref.watch(healthConnectRepositoryProvider),
    loadRules: () => ref.watch(rulesProvider.future),
    profileRepo: MockProfileRepository(backend),
  );
});

// ── Active repositories ───────────────────────────────────────────────────────

/// The active [HealthDataRepository].
///
/// • On Android with Health Connect permissions granted → real data from
///   [HealthConnectRepository].
/// • Everywhere else (non-Android, permissions not yet granted, demo mode) →
///   [MockHealthDataRepository] with generated data.
final healthDataRepositoryProvider = Provider<HealthDataRepository>((ref) {
  if (Platform.isAndroid) {
    final authorised = ref.watch(hcAuthorizedProvider);
    if (authorised) {
      return ref.watch(healthConnectRepositoryProvider);
    }
  }
  return MockHealthDataRepository(ref.watch(mockBackendProvider));
});

/// The active [FlagsRepository].
///
/// • On Android with Health Connect permissions granted → flags evaluated
///   against real Health Connect readings by [HealthConnectFlagsRepository].
/// • Otherwise → [MockFlagsRepository] using mock persona data.
final flagsRepositoryProvider = Provider<FlagsRepository>((ref) {
  if (Platform.isAndroid) {
    final authorised = ref.watch(hcAuthorizedProvider);
    if (authorised) {
      return ref.watch(healthConnectFlagsRepositoryProvider);
    }
  }
  return MockFlagsRepository(ref.watch(mockBackendProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => MockProfileRepository(ref.watch(mockBackendProvider)),
);

final habitsRepositoryProvider = Provider<HabitsRepository>(
  (ref) => MockHabitsRepository(ref.watch(mockBackendProvider)),
);

final alertsRepositoryProvider = Provider<AlertsRepository>(
  (ref) => MockAlertsRepository(ref.watch(mockBackendProvider)),
);

final doctorReviewRepositoryProvider = Provider<DoctorReviewRepository>(
  (ref) => MockDoctorReviewRepository(ref.watch(mockBackendProvider)),
);

final symptomRepositoryProvider = Provider<SymptomRepository>(
  (ref) => MockSymptomRepository(ref.watch(mockBackendProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => MockSettingsRepository(ref.watch(mockBackendProvider)),
);
