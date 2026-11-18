import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/alerts/alert_preferences_screen.dart';
import '../../features/alerts/alerts_screen.dart';
import '../../features/alerts/emergency_screen.dart';
import '../../features/auth/fs_sign_in_screen.dart';
import '../../features/auth/fs_sign_up_screen.dart';
import '../../features/connect/connect_watch_screen.dart';
import '../../features/design_preview/design_preview_screen.dart';
import '../../features/doctor/doctor_review_detail_screen.dart';
import '../../features/doctor/doctor_reviews_screen.dart';
import '../../features/flags/flag_detail_screen.dart';
import '../../features/flags/flags_screen.dart';
import '../../features/habits/breathing_screen.dart';
import '../../features/habits/habits_screen.dart';
import '../../features/home/fs_home_screen.dart';
import '../../features/onboarding/fs_consent_screen.dart';
import '../../features/onboarding/fs_family_history_screen.dart';
import '../../features/onboarding/fs_medical_profile_screen.dart';
import '../../features/onboarding/fs_basic_profile_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/profile/fs_profile_screen.dart';
import '../../features/profile/devices_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/settings/fs_settings_screen.dart';
import '../../features/symptoms/fs_symptoms_screen.dart';
import '../../features/timeline/fs_timeline_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
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
  final refresh = _AuthListenable(ref);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);
      final path = state.uri.path;

      // While auth is loading, stay on splash
      if (authAsync.isLoading) {
        if (path == '/') return null;
        return '/';
      }

      final user = authAsync.value;
      final signedIn = user != null;

      final onSplash = path == '/';
      final onAuthFlow = path == '/sign-in' ||
          path == '/sign-up' ||
          path.startsWith('/onboard');

      if (!signedIn) {
        if (onSplash || onAuthFlow) return null;
        return '/sign-in';
      }

      // Signed in — check onboarding (single cached user-doc provider)
      final userProfile = ref.read(userProvider).value;
      final isDemo = userProfile?.isDemo ?? false;
      final onboardingComplete = userProfile?.onboardingComplete ?? false;

      if (!isDemo && !onboardingComplete && userProfile != null) {
        if (!userProfile.consent.healthData) {
          if (path == '/onboard/consent') return null;
          return '/onboard/consent';
        }
        if (userProfile.age == null) {
          if (path == '/onboard/basic-profile') return null;
          return '/onboard/basic-profile';
        }
        if (path.startsWith('/onboard/') || path == '/connect') return null;
        return '/onboard/consent';
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
              final auth = ref.read(authStateProvider);
              if (auth.value != null) {
                context.go(AppRoutes.home);
              } else {
                context.go('/sign-in');
              }
            },
          ),
        ),
      ),
      GoRoute(
        path: '/sign-in',
        pageBuilder: (context, state) =>
            _fadeSlide(state, const FsSignInScreen()),
      ),
      GoRoute(
        path: '/sign-up',
        pageBuilder: (context, state) =>
            _fadeSlide(state, const FsSignUpScreen()),
      ),
      // Onboarding steps
      GoRoute(
        path: '/onboard/consent',
        pageBuilder: (context, state) =>
            _fadeSlide(state, const FsConsentScreen()),
      ),
      GoRoute(
        path: '/onboard/basic-profile',
        pageBuilder: (context, state) =>
            _fadeSlide(state, const FsBasicProfileScreen()),
      ),
      GoRoute(
        path: '/onboard/medical-profile',
        pageBuilder: (context, state) =>
            _fadeSlide(state, const FsMedicalProfileScreen()),
      ),
      GoRoute(
        path: '/onboard/family-history',
        pageBuilder: (context, state) =>
            _fadeSlide(state, const FsFamilyHistoryScreen()),
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
            _fadeSlide(state, const FsSymptomsScreen()),
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
              return _fadeSlide(state, DoctorReviewDetailScreen(reviewId: id));
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
            _fadeSlide(state, const FsSettingsScreen()),
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
                    _fadeSlide(state, const FsHomeScreen()),
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
                      return _fadeSlide(state, FlagDetailScreen(flagId: id));
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
                    _fadeSlide(state, const FsTimelineScreen()),
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
                    _fadeSlide(state, const FsProfileScreen()),
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

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
    _ref.listen(userProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}
