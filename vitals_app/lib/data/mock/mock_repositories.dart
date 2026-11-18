import 'dart:async';

import '../../domain/models/alert.dart';
import '../../domain/models/baseline.dart';
import '../../domain/models/consent.dart';
import '../../domain/models/daily_reading.dart';
import '../../domain/models/device.dart';
import '../../domain/models/doctor_review.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/flag.dart';
import '../../domain/models/habit.dart';
import '../../domain/models/home_snapshot.dart';
import '../../domain/models/life_event.dart';
import '../../domain/models/profile.dart';
import '../../domain/models/rule.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/symptom.dart';
import '../../domain/repositories/alerts_repository.dart';
import '../../domain/repositories/doctor_review_repository.dart';
import '../../domain/repositories/flags_repository.dart';
import '../../domain/repositories/habits_repository.dart';
import '../../domain/repositories/health_data_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/symptom_repository.dart';
import 'mock_store.dart';

/// Thrown by mock repositories when the "force error" demo tool is on.
class MockDemoException implements Exception {
  const MockDemoException([
    this.message = 'Something went wrong while loading your data. '
        '(Demo error: switched on in Settings → Demo tools.)',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Settings, consents and devices. These live outside [MockStore] so they
/// survive persona switches (including the demo tool toggles).
class MockSession {
  MockSession({AppSettings? settings, List<Consent>? consents, List<Device>? devices})
    : settings = settings ?? const AppSettings(),
      consents = consents ?? _defaultConsents(),
      devices = devices ?? _defaultDevices();

  AppSettings settings;
  List<Consent> consents;
  List<Device> devices;

  static List<Consent> _defaultConsents() => [
    const Consent(
      id: 'health_data',
      title: 'Read my health data',
      description:
          'Lets VitalWatch read sleep, heart and activity data from your '
          'connected sources to compare it with your own usual range.',
      granted: true,
      isRequired: true,
    ),
    const Consent(
      id: 'doctor_sharing',
      title: 'Share summaries with a clinician',
      description:
          'Only when you ask for a review. Summaries are shared, never raw '
          'data.',
      granted: true,
    ),
    const Consent(
      id: 'notifications',
      title: 'Pattern notifications',
      description: 'Get a gentle nudge when a pattern persists.',
      granted: true,
    ),
    const Consent(
      id: 'research',
      title: 'Anonymous research use',
      description:
          'Help improve pattern detection with data that cannot be traced '
          'back to you.',
      granted: false,
    ),
  ];

  static List<Device> _defaultDevices() {
    final synced = DateTime.now().subtract(const Duration(hours: 2));
    return [
      Device(
        id: 'health_connect',
        name: 'Health Connect',
        kind: DeviceKind.phone,
        connected: true,
        lastSyncedAt: synced,
        metrics: const [VitalMetric.steps, VitalMetric.sleepDuration],
      ),
      Device(
        id: 'sample_watch',
        name: 'Sample smartwatch',
        kind: DeviceKind.watch,
        connected: true,
        lastSyncedAt: synced,
        batteryPercent: 64,
        metrics: const [
          VitalMetric.restingHr,
          VitalMetric.hrv,
          VitalMetric.spo2,
          VitalMetric.respiratoryRate,
          VitalMetric.skinTemp,
        ],
      ),
      const Device(
        id: 'sample_ring',
        name: 'Sample smart ring',
        kind: DeviceKind.ring,
        connected: false,
        metrics: [VitalMetric.sleepFragmentation, VitalMetric.deepSleep],
      ),
    ];
  }
}

/// Shared plumbing for all mock repositories: ~600 ms latency, plus the
/// `slowSync` and `forceError` demo tools.
class MockBackend {
  MockBackend({
    required this.session,
    required this.store,
    this.latency = const Duration(milliseconds: 600),
    this.slowExtra = const Duration(seconds: 3),
  });

  final MockSession session;
  final Future<MockStore> store;
  final Duration latency;
  final Duration slowExtra;

  /// Waits, honours the demo tools, then runs [action] on the store.
  Future<T> run<T>(T Function(MockStore store) action) async {
    final data = await store;
    final settings = session.settings;
    final wait = settings.slowSync ? latency + slowExtra : latency;
    if (wait > Duration.zero) {
      await Future<void>.delayed(wait);
    }
    if (settings.forceError) throw const MockDemoException();
    return action(data);
  }

  /// For settings screens: normal latency, never throws, so the demo tools
  /// can always be switched off again.
  Future<T> runSafe<T>(T Function() action) async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    return action();
  }
}

class MockHealthDataRepository implements HealthDataRepository {
  MockHealthDataRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<List<DailyReading>> getReadings({ChartRange range = ChartRange.all}) {
    return _backend.run((store) {
      final all = store.readings;
      final count = range.days >= all.length ? all.length : range.days;
      return List.unmodifiable(all.sublist(all.length - count));
    });
  }

  @override
  Future<DailyReading?> getLatestReading() =>
      _backend.run((store) => store.latestReading);

  @override
  Future<Baseline> getBaseline(VitalMetric metric) =>
      _backend.run((store) => store.baseline(metric));

  @override
  Future<HomeSnapshot> getHomeSnapshot() =>
      _backend.run((store) => store.buildHomeSnapshot());

  @override
  Future<DateTime> syncNow() {
    return _backend.run((store) {
      final time = DateTime.now();
      store.lastSyncedAt = time;
      _backend.session.devices = [
        for (final d in _backend.session.devices)
          d.connected ? d.copyWith(lastSyncedAt: time) : d,
      ];
      return time;
    });
  }
}

class MockFlagsRepository implements FlagsRepository {
  MockFlagsRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<List<Flag>> getFlags() => _backend.run((store) => store.flags);

  @override
  Future<Flag?> getFlag(String id) {
    return _backend.run((store) {
      for (final flag in store.flags) {
        if (flag.id == id) return flag;
      }
      return null;
    });
  }

  @override
  Future<Flag> acknowledgeFlag(String id) {
    return _backend.run((store) {
      store.acknowledge(id);
      return store.flags.firstWhere((f) => f.id == id);
    });
  }

  @override
  Future<List<Rule>> getRules() => _backend.run((store) => store.rules);

  @override
  Future<Rule?> getRule(String id) {
    return _backend.run((store) {
      for (final rule in store.rules) {
        if (rule.id == id) return rule;
      }
      return null;
    });
  }
}

class MockProfileRepository implements ProfileRepository {
  MockProfileRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<Profile> getProfile() => _backend.run((store) => store.profile);

  @override
  Future<Profile> updateProfile(Profile profile) {
    return _backend.run((store) {
      store.profile = profile;
      store.refreshFlags(); // family history can change sensitivity
      return profile;
    });
  }

  @override
  Future<List<LifeEvent>> getLifeEvents() =>
      _backend.run((store) => List.unmodifiable(store.lifeEvents));

  @override
  Future<List<LifeEvent>> addLifeEvent(LifeEvent event) {
    return _backend.run((store) {
      store.lifeEvents = [event, ...store.lifeEvents]
        ..sort((a, b) => b.startDate.compareTo(a.startDate));
      return List.unmodifiable(store.lifeEvents);
    });
  }

  @override
  Future<List<LifeEvent>> removeLifeEvent(String id) {
    return _backend.run((store) {
      store.lifeEvents = store.lifeEvents.where((e) => e.id != id).toList();
      return List.unmodifiable(store.lifeEvents);
    });
  }
}

class MockHabitsRepository implements HabitsRepository {
  MockHabitsRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<List<Habit>> getHabits() =>
      _backend.run((store) => List.unmodifiable(store.habits));

  @override
  Future<Habit> toggleHabit(String id, DateTime date) {
    return _backend.run((store) {
      late Habit updated;
      store.habits = [
        for (final habit in store.habits)
          if (habit.id == id) (updated = habit.toggled(date)) else habit,
      ];
      return updated;
    });
  }

  @override
  Future<List<Habit>> addHabit(Habit habit) {
    return _backend.run((store) {
      store.habits = [...store.habits, habit];
      return List.unmodifiable(store.habits);
    });
  }

  @override
  Future<List<Habit>> removeHabit(String id) {
    return _backend.run((store) {
      store.habits = store.habits.where((h) => h.id != id).toList();
      return List.unmodifiable(store.habits);
    });
  }
}

class MockAlertsRepository implements AlertsRepository {
  MockAlertsRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<List<Alert>> getAlerts() =>
      _backend.run((store) => List.unmodifiable(store.alerts));

  @override
  Future<List<Alert>> markRead(String id) {
    return _backend.run((store) {
      store.alerts = [
        for (final a in store.alerts) a.id == id ? a.copyWith(isRead: true) : a,
      ];
      return List.unmodifiable(store.alerts);
    });
  }

  @override
  Future<List<Alert>> markAllRead() {
    return _backend.run((store) {
      store.alerts = [for (final a in store.alerts) a.copyWith(isRead: true)];
      return List.unmodifiable(store.alerts);
    });
  }

  @override
  Future<List<Alert>> dismiss(String id) {
    return _backend.run((store) {
      store.alerts = store.alerts.where((a) => a.id != id).toList();
      return List.unmodifiable(store.alerts);
    });
  }
}

class MockDoctorReviewRepository implements DoctorReviewRepository {
  MockDoctorReviewRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<List<DoctorReview>> getReviews() =>
      _backend.run((store) => List.unmodifiable(store.reviews));

  @override
  Future<DoctorReview?> getReviewForFlag(String flagId) =>
      _backend.run((store) => store.reviewFor(flagId));

  @override
  Future<DoctorReview> requestReview(String flagId) {
    return _backend.run((store) {
      final existing = store.reviewFor(flagId);
      if (existing != null) return existing;
      final review = DoctorReview(
        id: 'review_$flagId',
        flagId: flagId,
        doctorName: 'Dr. Ananya Mehta',
        credentials: 'General physician (sample reviewer)',
        verdict: DoctorVerdict.pending,
        requestedAt: DateTime.now(),
        note: 'A clinician will look at your shared trend summary.',
      );
      store.reviews = [...store.reviews, review];
      return review;
    });
  }
}

class MockSymptomRepository implements SymptomRepository {
  MockSymptomRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<List<Symptom>> getSymptoms() =>
      _backend.run((store) => List.unmodifiable(store.symptoms));

  @override
  Future<List<Symptom>> addSymptom(Symptom symptom) {
    return _backend.run((store) {
      store.symptoms = [symptom, ...store.symptoms]
        ..sort((a, b) => b.date.compareTo(a.date));
      return List.unmodifiable(store.symptoms);
    });
  }

  @override
  Future<List<Symptom>> removeSymptom(String id) {
    return _backend.run((store) {
      store.symptoms = store.symptoms.where((s) => s.id != id).toList();
      return List.unmodifiable(store.symptoms);
    });
  }

  @override
  Future<List<String>> getSuggestedSymptoms() {
    return _backend.run((store) {
      final seen = <String>{};
      return [
        for (final rule in store.rules)
          for (final symptom in rule.symptoms)
            if (seen.add(symptom)) symptom,
      ];
    });
  }
}

class MockSettingsRepository implements SettingsRepository {
  MockSettingsRepository(this._backend);

  final MockBackend _backend;

  MockSession get _session => _backend.session;

  @override
  Future<AppSettings> getSettings() => _backend.runSafe(() => _session.settings);

  @override
  Future<AppSettings> updateSettings(AppSettings settings) {
    return _backend.runSafe(() => _session.settings = settings);
  }

  @override
  Future<List<Consent>> getConsents() =>
      _backend.runSafe(() => List.unmodifiable(_session.consents));

  @override
  Future<List<Consent>> setConsent(String id, {required bool granted}) {
    return _backend.runSafe(() {
      _session.consents = [
        for (final c in _session.consents)
          if (c.id == id && !c.isRequired)
            c.copyWith(granted: granted, updatedAt: DateTime.now())
          else
            c,
      ];
      return List.unmodifiable(_session.consents);
    });
  }

  @override
  Future<List<Device>> getDevices() =>
      _backend.runSafe(() => List.unmodifiable(_session.devices));

  @override
  Future<List<Device>> setDeviceConnected(
    String id, {
    required bool connected,
  }) {
    return _backend.runSafe(() {
      _session.devices = [
        for (final d in _session.devices)
          if (d.id == id)
            d.copyWith(
              connected: connected,
              lastSyncedAt: connected ? DateTime.now() : d.lastSyncedAt,
            )
          else
            d,
      ];
      return List.unmodifiable(_session.devices);
    });
  }

  @override
  Future<List<Device>> syncDevice(String id) {
    // Syncing honours the demo tools (slow / failing syncs).
    return _backend.run((store) {
      _session.devices = [
        for (final d in _session.devices)
          d.id == id && d.connected
              ? d.copyWith(lastSyncedAt: DateTime.now())
              : d,
      ];
      store.lastSyncedAt = DateTime.now();
      return List.unmodifiable(_session.devices);
    });
  }
}
