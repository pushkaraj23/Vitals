import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/alert.dart';
import '../../domain/models/enums.dart';
import '../../providers/providers.dart';

/// Alert id -> time the snooze ends. Cleared when the persona changes.
class SnoozedAlertsNotifier extends Notifier<Map<String, DateTime>> {
  @override
  Map<String, DateTime> build() {
    ref.watch(personaIdProvider);
    return const {};
  }

  void snooze(String id, Duration duration) {
    state = {...state, id: DateTime.now().add(duration)};
  }

  void unsnooze(String id) {
    state = {...state}..remove(id);
  }

  /// Whether [alert] is currently snoozed. Emergency alerts never are.
  bool isSnoozed(Alert alert) {
    if (alert.tier == AlertTier.emergency) return false;
    final until = state[alert.id];
    return until != null && until.isAfter(DateTime.now());
  }
}

final snoozedAlertsProvider =
    NotifierProvider<SnoozedAlertsNotifier, Map<String, DateTime>>(
      SnoozedAlertsNotifier.new,
    );

/// Alerts created locally by demo tools (e.g. "Trigger emergency").
class DemoAlertsNotifier extends Notifier<List<Alert>> {
  @override
  List<Alert> build() {
    ref.watch(personaIdProvider);
    return const [];
  }

  void triggerEmergency() {
    state = [
      Alert(
        id: 'demo_emergency',
        tier: AlertTier.emergency,
        title: 'Seek medical care now',
        message:
            'This is a demo emergency alert. In a real situation, contact '
            'local emergency services or go to the nearest hospital.',
        createdAt: DateTime.now(),
        actionLabel: 'Open emergency screen',
      ),
      for (final a in state)
        if (a.id != 'demo_emergency') a,
    ];
  }

  void remove(String id) => state = [
    for (final a in state)
      if (a.id != id) a,
  ];

  void clear() => state = const [];
}

final demoAlertsProvider = NotifierProvider<DemoAlertsNotifier, List<Alert>>(
  DemoAlertsNotifier.new,
);

// ------------------------------------------------------------ preferences

enum AlertFrequency {
  instant('As they happen', 'Get a notification when a pattern appears.'),
  daily('Daily digest', 'One summary each day at your reminder time.'),
  weekly('Weekly digest', 'A calm weekly roundup.');

  const AlertFrequency(this.label, this.description);

  final String label;
  final String description;
}

class AlertPrefs {
  const AlertPrefs({
    this.push = true,
    this.email = false,
    this.sms = false,
    this.frequency = AlertFrequency.instant,
    this.quietHoursEnabled = true,
    this.quietStartMinutes = 22 * 60,
    this.quietEndMinutes = 7 * 60,
  });

  final bool push;
  final bool email;
  final bool sms;
  final AlertFrequency frequency;
  final bool quietHoursEnabled;
  final int quietStartMinutes;
  final int quietEndMinutes;

  AlertPrefs copyWith({
    bool? push,
    bool? email,
    bool? sms,
    AlertFrequency? frequency,
    bool? quietHoursEnabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
  }) {
    return AlertPrefs(
      push: push ?? this.push,
      email: email ?? this.email,
      sms: sms ?? this.sms,
      frequency: frequency ?? this.frequency,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
      quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
    );
  }
}

class AlertPrefsNotifier extends Notifier<AlertPrefs> {
  @override
  AlertPrefs build() => const AlertPrefs();

  void update(AlertPrefs Function(AlertPrefs) change) =>
      state = change(state);

  void reset() => state = const AlertPrefs();
}

final alertPrefsProvider = NotifierProvider<AlertPrefsNotifier, AlertPrefs>(
  AlertPrefsNotifier.new,
);
