import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vitals/core/theme/app_theme.dart';
import 'package:vitals/core/widgets/flag_chip.dart';
import 'package:vitals/domain/models/enums.dart';
import 'package:vitals/features/alerts/alert_preferences_screen.dart';
import 'package:vitals/features/alerts/alerts_screen.dart';
import 'package:vitals/features/alerts/emergency_screen.dart';
import 'package:vitals/features/doctor/doctor_review_detail_screen.dart';
import 'package:vitals/features/doctor/doctor_reviews_screen.dart';
import 'package:vitals/features/flags/flag_detail_screen.dart';
import 'package:vitals/features/habits/breathing_screen.dart';
import 'package:vitals/features/habits/habits_screen.dart';
import 'package:vitals/features/profile/devices_screen.dart';
import 'package:vitals/features/profile/profile_screen.dart';
import 'package:vitals/features/reports/reports_screen.dart';
import 'package:vitals/features/settings/settings_screen.dart';
import 'package:vitals/features/symptoms/symptoms_screen.dart';
import 'package:vitals/features/timeline/timeline_screen.dart';
import 'package:vitals/providers/providers.dart';

Future<ProviderContainer> pumpScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      mockLatencyProvider.overrideWithValue(Duration.zero),
      mockClockProvider.overrideWithValue(() => DateTime(2026, 6, 1)),
    ],
  );
  addTearDown(container.dispose);
  await tester.runAsync(() => container.read(mockStoreProvider.future));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light, home: screen),
    ),
  );
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Avoid network font fetches in tests; theme still builds with fallbacks.
  GoogleFonts.config.allowRuntimeFetching = false;

  final screens = <String, Widget>{
    'timeline': const TimelineScreen(),
    'habits': const HabitsScreen(),
    'breathing': const BreathingScreen(),
    'symptoms': const SymptomsScreen(),
    'alerts': const AlertsScreen(),
    'emergency': const EmergencyScreen(),
    'alert preferences': const AlertPreferencesScreen(),
    'doctor reviews': const DoctorReviewsScreen(),
    'review detail': const DoctorReviewDetailScreen(reviewId: 'review_x'),
    'reports': const ReportsScreen(),
    'profile': const ProfileScreen(),
    'devices': const DevicesScreen(),
    'settings': const SettingsScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} renders without errors', (tester) async {
      final container = await pumpScreen(tester, entry.value);
      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      container.dispose();
    });
  }

  testWidgets('FlagChip shows icon and label for each status', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(
          body: Column(
            children: [
              FlagChip(status: FlagStatus.green),
              FlagChip(status: FlagStatus.amber),
              FlagChip(status: FlagStatus.red),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Healthy'), findsOneWidget);
    expect(find.text('Watch'), findsOneWidget);
    expect(find.text('Action needed'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);
  });

  testWidgets('Flag detail renders with mock data', (tester) async {
    final container = ProviderContainer(
      overrides: [
        mockLatencyProvider.overrideWithValue(Duration.zero),
        mockClockProvider.overrideWithValue(() => DateTime(2026, 6, 1)),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(mockStoreProvider.future));
    final flags = await tester.runAsync(
      () => container.read(flagsProvider.future),
    );
    expect(flags, isNotNull);
    expect(flags!, isNotEmpty);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: FlagDetailScreen(flagId: flags.first.id),
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(FlagDetailScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('gentle mode hides long-term outlook until opened', (tester) async {
    final container = ProviderContainer(
      overrides: [
        mockLatencyProvider.overrideWithValue(Duration.zero),
        mockClockProvider.overrideWithValue(() => DateTime(2026, 6, 1)),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(mockStoreProvider.future));

    // Seed gentle mode before any settings provider is watched by UI.
    await tester.runAsync(() async {
      final current = await container.read(settingsProvider.future);
      await container
          .read(settingsProvider.notifier)
          .save(current.copyWith(gentleMode: true));
      await container.read(settingsProvider.future);
    });

    final flags = await tester.runAsync(
      () => container.read(flagsProvider.future),
    );
    final id =
        flags!.firstWhere((f) => f.isActive, orElse: () => flags.first).id;

    expect(container.read(settingsProvider).value?.gentleMode, isTrue);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: FlagDetailScreen(flagId: id),
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // With gentle mode on, the Physical/Mental toggle must stay hidden
    // until the user opens the outlook notes.
    expect(find.text('Physical'), findsNothing);
    expect(find.text('Mental'), findsNothing);
  });
}
