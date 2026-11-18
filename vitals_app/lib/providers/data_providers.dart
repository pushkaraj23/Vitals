import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/alert.dart';
import '../domain/models/baseline.dart';
import '../domain/models/consent.dart';
import '../domain/models/daily_reading.dart';
import '../domain/models/device.dart';
import '../domain/models/doctor_review.dart';
import '../domain/models/enums.dart';
import '../domain/models/flag.dart';
import '../domain/models/habit.dart';
import '../domain/models/home_snapshot.dart';
import '../domain/models/life_event.dart';
import '../domain/models/profile.dart';
import '../domain/models/rule.dart';
import '../domain/models/settings.dart';
import '../domain/models/symptom.dart';
import 'repository_providers.dart';

// All providers below expose AsyncValue (loading / error / data). They are
// rebuilt automatically when the persona changes, because the repositories
// they read from depend on the generated MockStore.

// ------------------------------------------------------------ read-only data

final homeSnapshotProvider = FutureProvider<HomeSnapshot>(
  (ref) => ref.watch(healthDataRepositoryProvider).getHomeSnapshot(),
  retry: noRetry,
);

final readingsProvider = FutureProvider.family<List<DailyReading>, ChartRange>(
  (ref, range) =>
      ref.watch(healthDataRepositoryProvider).getReadings(range: range),
  retry: noRetry,
);

final baselineProvider = FutureProvider.family<Baseline, VitalMetric>(
  (ref, metric) => ref.watch(healthDataRepositoryProvider).getBaseline(metric),
  retry: noRetry,
);

final flagsProvider = FutureProvider<List<Flag>>(
  (ref) => ref.watch(flagsRepositoryProvider).getFlags(),
  retry: noRetry,
);

final flagProvider = FutureProvider.family<Flag?, String>(
  (ref, id) => ref.watch(flagsRepositoryProvider).getFlag(id),
  retry: noRetry,
);

/// Rule with the given id (from the rules library).
final ruleProvider = FutureProvider.family<Rule?, String>(
  (ref, id) => ref.watch(flagsRepositoryProvider).getRule(id),
  retry: noRetry,
);

final profileProvider = FutureProvider<Profile>(
  (ref) => ref.watch(profileRepositoryProvider).getProfile(),
  retry: noRetry,
);

final doctorReviewsProvider = FutureProvider<List<DoctorReview>>(
  (ref) => ref.watch(doctorReviewRepositoryProvider).getReviews(),
  retry: noRetry,
);

final doctorReviewForFlagProvider =
    FutureProvider.family<DoctorReview?, String>(
      (ref, flagId) =>
          ref.watch(doctorReviewRepositoryProvider).getReviewForFlag(flagId),
      retry: noRetry,
    );

final suggestedSymptomsProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(symptomRepositoryProvider).getSuggestedSymptoms(),
  retry: noRetry,
);

// ------------------------------------------------------------ mutable data

class HabitsNotifier extends AsyncNotifier<List<Habit>> {
  @override
  Future<List<Habit>> build() =>
      ref.watch(habitsRepositoryProvider).getHabits();

  /// Optimistically toggles [id] for [date] (default today). Rethrows if the
  /// repository fails, after restoring the previous state.
  Future<void> toggle(String id, [DateTime? date]) async {
    final previous = state.value;
    if (previous == null) return;
    final day = date ?? DateTime.now();
    state = AsyncData([
      for (final h in previous) h.id == id ? h.toggled(day) : h,
    ]);
    try {
      await ref.read(habitsRepositoryProvider).toggleHabit(id, day);
    } catch (_) {
      if (ref.mounted) state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> add(Habit habit) async {
    final updated = await ref.read(habitsRepositoryProvider).addHabit(habit);
    if (ref.mounted) state = AsyncData(updated);
  }

  Future<void> remove(String id) async {
    final updated = await ref.read(habitsRepositoryProvider).removeHabit(id);
    if (ref.mounted) state = AsyncData(updated);
  }
}

final habitsProvider = AsyncNotifierProvider<HabitsNotifier, List<Habit>>(
  HabitsNotifier.new,
  retry: noRetry,
);

class AlertsNotifier extends AsyncNotifier<List<Alert>> {
  @override
  Future<List<Alert>> build() =>
      ref.watch(alertsRepositoryProvider).getAlerts();

  Future<void> markRead(String id) async {
    final previous = state.value;
    if (previous == null) return;
    state = AsyncData([
      for (final a in previous) a.id == id ? a.copyWith(isRead: true) : a,
    ]);
    try {
      await ref.read(alertsRepositoryProvider).markRead(id);
    } catch (_) {
      if (ref.mounted) state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    final previous = state.value;
    if (previous == null) return;
    state = AsyncData([for (final a in previous) a.copyWith(isRead: true)]);
    try {
      await ref.read(alertsRepositoryProvider).markAllRead();
    } catch (_) {
      if (ref.mounted) state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> dismiss(String id) async {
    final previous = state.value;
    if (previous == null) return;
    state = AsyncData(previous.where((a) => a.id != id).toList());
    try {
      await ref.read(alertsRepositoryProvider).dismiss(id);
    } catch (_) {
      if (ref.mounted) state = AsyncData(previous);
      rethrow;
    }
  }
}

final alertsProvider = AsyncNotifierProvider<AlertsNotifier, List<Alert>>(
  AlertsNotifier.new,
  retry: noRetry,
);

/// Number of unread alerts (0 while loading or on error).
final unreadAlertCountProvider = Provider<int>((ref) {
  final alerts = ref.watch(alertsProvider).value ?? const <Alert>[];
  return alerts.where((a) => !a.isRead).length;
});

class SymptomsNotifier extends AsyncNotifier<List<Symptom>> {
  @override
  Future<List<Symptom>> build() =>
      ref.watch(symptomRepositoryProvider).getSymptoms();

  Future<void> add(Symptom symptom) async {
    final updated = await ref.read(symptomRepositoryProvider).addSymptom(symptom);
    if (ref.mounted) state = AsyncData(updated);
  }

  Future<void> remove(String id) async {
    final updated = await ref.read(symptomRepositoryProvider).removeSymptom(id);
    if (ref.mounted) state = AsyncData(updated);
  }
}

final symptomsProvider = AsyncNotifierProvider<SymptomsNotifier, List<Symptom>>(
  SymptomsNotifier.new,
  retry: noRetry,
);

class LifeEventsNotifier extends AsyncNotifier<List<LifeEvent>> {
  @override
  Future<List<LifeEvent>> build() =>
      ref.watch(profileRepositoryProvider).getLifeEvents();

  Future<void> add(LifeEvent event) async {
    final updated = await ref.read(profileRepositoryProvider).addLifeEvent(event);
    if (ref.mounted) state = AsyncData(updated);
  }

  Future<void> remove(String id) async {
    final updated = await ref.read(profileRepositoryProvider).removeLifeEvent(id);
    if (ref.mounted) state = AsyncData(updated);
  }
}

final lifeEventsProvider =
    AsyncNotifierProvider<LifeEventsNotifier, List<LifeEvent>>(
      LifeEventsNotifier.new,
      retry: noRetry,
    );

class DoctorReviewActions extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Requests a clinician review, then refreshes dependent providers.
  Future<void> request(String flagId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(doctorReviewRepositoryProvider).requestReview(flagId);
      ref
        ..invalidate(doctorReviewsProvider)
        ..invalidate(doctorReviewForFlagProvider)
        ..invalidate(flagsProvider)
        ..invalidate(flagProvider)
        ..invalidate(homeSnapshotProvider);
    });
  }
}

final doctorReviewActionsProvider =
    AsyncNotifierProvider<DoctorReviewActions, void>(
      DoctorReviewActions.new,
      retry: noRetry,
    );

// ----------------------------------------------------------------- settings

/// Re-fetches every data provider (used after changing demo tools).
void refreshAllData(Ref ref) {
  ref
    ..invalidate(homeSnapshotProvider)
    ..invalidate(readingsProvider)
    ..invalidate(baselineProvider)
    ..invalidate(flagsProvider)
    ..invalidate(flagProvider)
    ..invalidate(ruleProvider)
    ..invalidate(profileProvider)
    ..invalidate(doctorReviewsProvider)
    ..invalidate(doctorReviewForFlagProvider)
    ..invalidate(suggestedSymptomsProvider)
    ..invalidate(habitsProvider)
    ..invalidate(alertsProvider)
    ..invalidate(symptomsProvider)
    ..invalidate(lifeEventsProvider);
}

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() =>
      ref.watch(settingsRepositoryProvider).getSettings();

  Future<void> save(AppSettings next) async {
    final previous = state.value;
    state = AsyncData(next);
    try {
      await ref.read(settingsRepositoryProvider).updateSettings(next);
    } catch (_) {
      if (ref.mounted && previous != null) state = AsyncData(previous);
      rethrow;
    }
    if (!ref.mounted) return;
    final demoChanged =
        previous != null &&
        (previous.forceError != next.forceError ||
            previous.slowSync != next.slowSync);
    if (demoChanged) refreshAllData(ref);
  }

  Future<void> setForceError(bool value) async {
    final current = state.value ?? const AppSettings();
    await save(current.copyWith(forceError: value));
  }

  Future<void> setSlowSync(bool value) async {
    final current = state.value ?? const AppSettings();
    await save(current.copyWith(slowSync: value));
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
  retry: noRetry,
);

class ConsentsNotifier extends AsyncNotifier<List<Consent>> {
  @override
  Future<List<Consent>> build() =>
      ref.watch(settingsRepositoryProvider).getConsents();

  Future<void> setGranted(String id, {required bool granted}) async {
    final updated = await ref
        .read(settingsRepositoryProvider)
        .setConsent(id, granted: granted);
    if (ref.mounted) state = AsyncData(updated);
  }
}

final consentsProvider = AsyncNotifierProvider<ConsentsNotifier, List<Consent>>(
  ConsentsNotifier.new,
  retry: noRetry,
);

class DevicesNotifier extends AsyncNotifier<List<Device>> {
  @override
  Future<List<Device>> build() =>
      ref.watch(settingsRepositoryProvider).getDevices();

  Future<void> setConnected(String id, {required bool connected}) async {
    final updated = await ref
        .read(settingsRepositoryProvider)
        .setDeviceConnected(id, connected: connected);
    if (ref.mounted) state = AsyncData(updated);
  }

  /// Syncs one device. Honours the slow/force-error demo tools.
  Future<void> sync(String id) async {
    final updated = await ref.read(settingsRepositoryProvider).syncDevice(id);
    if (ref.mounted) state = AsyncData(updated);
  }
}

final devicesProvider = AsyncNotifierProvider<DevicesNotifier, List<Device>>(
  DevicesNotifier.new,
  retry: noRetry,
);

// --------------------------------------------------------------------- sync

/// "Sync now" for the Home screen. State is the last successful sync time.
class SyncNotifier extends AsyncNotifier<DateTime?> {
  @override
  Future<DateTime?> build() async => null;

  Future<void> sync() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final time = await ref.read(healthDataRepositoryProvider).syncNow();
      ref
        ..invalidate(homeSnapshotProvider)
        ..invalidate(readingsProvider)
        ..invalidate(baselineProvider)
        ..invalidate(devicesProvider);
      return time;
    });
  }
}

final syncProvider = AsyncNotifierProvider<SyncNotifier, DateTime?>(
  SyncNotifier.new,
  retry: noRetry,
);

