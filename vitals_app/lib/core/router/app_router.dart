import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/alerts/alert_preferences_screen.dart';
import '../../features/alerts/alerts_screen.dart';
import '../../features/alerts/emergency_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/connect/connect_watch_screen.dart';
import '../../features/design_preview/design_preview_screen.dart';
import '../../features/doctor/doctor_review_detail_screen.dart';
import '../../features/doctor/doctor_reviews_screen.dart';
import '../../features/flags/flag_detail_screen.dart';
import '../../features/flags/flags_screen.dart';
import '../../features/habits/breathing_screen.dart';
import '../../features/habits/habits_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/consent_screen.dart';
import '../../features/onboarding/intake_screen.dart';
import '../../features/onboarding/onboarding_carousel_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/profile/devices_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/symptoms/symptoms_screen.dart';
import '../../features/timeline/timeline_screen.dart';
import '../../providers/session_provider.dart';
import '../routes.dart';
import '../shell/adaptive_shell.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

CustomTransitionPage<void> _fadeSlide(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionListenable(ref);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final path = state.uri.path;
      final onSplash = path == '/';
      final onAuthFlow = path == '/onboarding' ||
          path == '/sign-in' ||
          path == '/otp' ||
          path == '/consent' ||
          path == '/intake' ||
          path == '/connect';

      if (!session.canEnterApp) {
        if (onSplash || onAuthFlow) return null;
        if (!session.hasCompletedOnboarding) return '/onboarding';
        if (!session.hasSignedIn) return '/sign-in';
        if (!session.consentsAccepted) return '/consent';
        if (!session.deviceConnected) return '/connect';
        return '/sign-in';
      }

      if (onSplash || onAuthFlow) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _fadeSlide(
          state,
          SplashScreen(
            onFinished: () {
              final s = ref.read(sessionProvider);
              if (s.canEnterApp) {
                context.go(AppRoutes.home);
              } else if (s.hasCompletedOnboarding) {
                context.go('/sign-in');
              } else {
                context.go('/onboarding');
              }
            },
          ),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            _fadeSlide(state, const OnboardingCarouselScreen()),
      ),
      GoRoute(
        path: '/sign-in',
        pageBuilder: (context, state) =>
            _fadeSlide(state, const SignInScreen()),
      ),
      GoRoute(
        path: '/otp',
        pageBuilder: (context, state) {
          final destination =
              state.extra is String ? state.extra as String : null;
          return _fadeSlide(state, OtpScreen(destination: destination));
        },
      ),
      GoRoute(
        path: '/consent',
        pageBuilder: (context, state) =>
            _fadeSlide(state, const ConsentScreen()),
      ),
      GoRoute(
        path: '/intake',
        pageBuilder: (context, state) =>
            _fadeSlide(state, const IntakeScreen()),
      ),
      GoRoute(
        path: '/connect',
        pageBuilder: (context, state) =>
            _fadeSlide(state, const ConnectWatchScreen()),
      ),
      GoRoute(
        path: AppRoutes.emergency,
        pageBuilder: (context, state) =>
            _fadeSlide(state, const EmergencyScreen()),
      ),
      GoRoute(
        path: AppRoutes.designPreview,
        pageBuilder: (context, state) =>
            _fadeSlide(state, const DesignPreviewScreen()),
      ),
      GoRoute(
        path: AppRoutes.alerts,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            _fadeSlide(state, const AlertsScreen()),
      ),
      GoRoute(
        path: AppRoutes.alertPreferences,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            _fadeSlide(state, const AlertPreferencesScreen()),
      ),
      GoRoute(
        path: AppRoutes.symptoms,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            _fadeSlide(state, const SymptomsScreen()),
      ),
      GoRoute(
        path: AppRoutes.doctors,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            _fadeSlide(state, const DoctorReviewsScreen()),
        routes: [
          GoRoute(
            path: ':reviewId',
            parentNavigatorKey: _rootKey,
            pageBuilder: (context, state) {
              final id = state.pathParameters['reviewId']!;
              return _fadeSlide(
                state,
                DoctorReviewDetailScreen(reviewId: id),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.reports,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            _fadeSlide(state, const ReportsScreen()),
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            _fadeSlide(state, const SettingsScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdaptiveShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                pageBuilder: (context, state) =>
                    _fadeSlide(state, const HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.flags,
                pageBuilder: (context, state) =>
                    _fadeSlide(state, const FlagsScreen()),
                routes: [
                  GoRoute(
                    path: ':flagId',
                    parentNavigatorKey: _rootKey,
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['flagId']!;
                      return _fadeSlide(
                        state,
                        FlagDetailScreen(flagId: id),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.timeline,
                pageBuilder: (context, state) =>
                    _fadeSlide(state, const TimelineScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.habits,
                pageBuilder: (context, state) =>
                    _fadeSlide(state, const HabitsScreen()),
                routes: [
                  GoRoute(
                    path: 'breathing',
                    parentNavigatorKey: _rootKey,
                    pageBuilder: (context, state) =>
                        _fadeSlide(state, const BreathingScreen()),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                pageBuilder: (context, state) =>
                    _fadeSlide(state, const ProfileScreen()),
                routes: [
                  GoRoute(
                    path: 'devices',
                    parentNavigatorKey: _rootKey,
                    pageBuilder: (context, state) =>
                        _fadeSlide(state, const DevicesScreen()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _SessionListenable extends ChangeNotifier {
  _SessionListenable(this._ref) {
    _ref.listen<SessionState>(sessionProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}
