import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitals/data/mock/personas.dart';
import 'package:vitals/domain/models/enums.dart';
import 'package:vitals/providers/providers.dart';

ProviderContainer makeContainer() {
  final container = ProviderContainer(
    overrides: [
      mockLatencyProvider.overrideWithValue(Duration.zero),
      mockClockProvider.overrideWithValue(() => DateTime(2026, 6, 1)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('home snapshot loads for the default persona (Rahul)', () async {
    final container = makeContainer();
    expect(container.read(homeSnapshotProvider), isA<AsyncLoading>());
    final home = await container.read(homeSnapshotProvider.future);
    expect(home.profile.firstName, 'Rahul');
    expect(home.overallStatus, FlagStatus.red);
    expect(home.activeFlags, isNotEmpty);
    expect(home.recentReadings.length, 30);
    expect(home.heroBaseline.hasData, isTrue);
    expect(home.wins, isNotEmpty);
  });

  test('switching persona regenerates data', () async {
    final container = makeContainer();
    final rahul = await container.read(homeSnapshotProvider.future);
    container.read(personaIdProvider.notifier).select(PersonaId.meera);
    final meera = await container.read(homeSnapshotProvider.future);
    expect(rahul.profile.firstName, 'Rahul');
    expect(meera.profile.firstName, 'Meera');
    expect(meera.overallStatus, FlagStatus.green);
    expect(meera.activeFlags, isEmpty);
  });

  test('force error surfaces as AsyncError, then recovers', () async {
    final container = makeContainer();
    await container.read(settingsProvider.future);
    await container.read(settingsProvider.notifier).setForceError(true);

    await expectLater(
      container.read(homeSnapshotProvider.future),
      throwsA(isA<Object>()),
    );
    expect(container.read(homeSnapshotProvider), isA<AsyncError>());

    // Settings stay reachable while errors are forced.
    await container.read(settingsProvider.notifier).setForceError(false);
    final home = await container.read(homeSnapshotProvider.future);
    expect(home.profile.firstName, 'Rahul');
  });

  test('habit toggle updates state', () async {
    final container = makeContainer();
    final habits = await container.read(habitsProvider.future);
    final first = habits.first;
    final today = DateTime(2026, 6, 1);
    final wasDone = first.isDoneOn(today);
    await container.read(habitsProvider.notifier).toggle(first.id, today);
    final updated = container.read(habitsProvider).requireValue;
    expect(updated.firstWhere((h) => h.id == first.id).isDoneOn(today), !wasDone);
  });

  test('flags carry doctor-review badges', () async {
    final container = makeContainer();
    final flags = await container.read(flagsProvider.future);
    final hr = flags.firstWhere((f) => f.ruleId == 'resting_hr_drift');
    expect(hr.doctorBadge, DoctorBadgeState.underReview);
    final other = flags.firstWhere((f) => f.ruleId == 'hrv_decline');
    expect(other.doctorBadge, DoctorBadgeState.notReviewed);
  });
}
