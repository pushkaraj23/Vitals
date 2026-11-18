enum UnitSystem {
  metric('Metric'),
  imperial('Imperial');

  const UnitSystem(this.label);

  final String label;
}

/// How readily patterns are surfaced. Presentation-only in the UI build.
enum AlertSensitivity {
  relaxed('Relaxed'),
  balanced('Balanced'),
  sensitive('Sensitive');

  const AlertSensitivity(this.label);

  final String label;
}

class AppSettings {
  const AppSettings({
    this.unitSystem = UnitSystem.metric,
    this.sensitivity = AlertSensitivity.balanced,
    this.notificationsEnabled = true,
    this.dailySummaryEnabled = true,
    this.reminderMinutesAfterMidnight = 20 * 60,
    this.forceError = false,
    this.slowSync = false,
    this.gentleMode = false,
  });

  final UnitSystem unitSystem;
  final AlertSensitivity sensitivity;
  final bool notificationsEnabled;
  final bool dailySummaryEnabled;

  /// Daily reminder time as minutes after midnight (default 20:00).
  final int reminderMinutesAfterMidnight;

  /// Demo tool: make mock repositories throw.
  final bool forceError;

  /// Demo tool: make mock repositories respond slowly.
  final bool slowSync;

  /// Softens wording of potential impacts on the Flag detail screen.
  final bool gentleMode;

  AppSettings copyWith({
    UnitSystem? unitSystem,
    AlertSensitivity? sensitivity,
    bool? notificationsEnabled,
    bool? dailySummaryEnabled,
    int? reminderMinutesAfterMidnight,
    bool? forceError,
    bool? slowSync,
    bool? gentleMode,
  }) {
    return AppSettings(
      unitSystem: unitSystem ?? this.unitSystem,
      sensitivity: sensitivity ?? this.sensitivity,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
      reminderMinutesAfterMidnight:
          reminderMinutesAfterMidnight ?? this.reminderMinutesAfterMidnight,
      forceError: forceError ?? this.forceError,
      slowSync: slowSync ?? this.slowSync,
      gentleMode: gentleMode ?? this.gentleMode,
    );
  }
}
