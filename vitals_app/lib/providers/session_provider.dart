import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory demo session. Returning users skip onboarding.
class SessionState {
  const SessionState({
    this.hasCompletedOnboarding = false,
    this.hasSignedIn = false,
    this.consentsAccepted = false,
    this.deviceConnected = false,
  });

  final bool hasCompletedOnboarding;
  final bool hasSignedIn;
  final bool consentsAccepted;
  final bool deviceConnected;

  bool get canEnterApp =>
      hasCompletedOnboarding &&
      hasSignedIn &&
      consentsAccepted &&
      deviceConnected;

  SessionState copyWith({
    bool? hasCompletedOnboarding,
    bool? hasSignedIn,
    bool? consentsAccepted,
    bool? deviceConnected,
  }) {
    return SessionState(
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      hasSignedIn: hasSignedIn ?? this.hasSignedIn,
      consentsAccepted: consentsAccepted ?? this.consentsAccepted,
      deviceConnected: deviceConnected ?? this.deviceConnected,
    );
  }
}

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();

  void completeOnboarding() =>
      state = state.copyWith(hasCompletedOnboarding: true);

  void signIn() => state = state.copyWith(hasSignedIn: true);

  void acceptConsents() => state = state.copyWith(consentsAccepted: true);

  void connectDevice() => state = state.copyWith(deviceConnected: true);

  /// Jump straight into the demo home (jury shortcut).
  void enterDemo() {
    state = const SessionState(
      hasCompletedOnboarding: true,
      hasSignedIn: true,
      consentsAccepted: true,
      deviceConnected: true,
    );
  }

  void signOut() => state = const SessionState();
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);
