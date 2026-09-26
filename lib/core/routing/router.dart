import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../features/auth/auth_screens.dart';
import '../../features/creation/create_type_screen.dart';
import '../../features/creation/details_screen.dart';
import '../../features/creation/draft.dart';
import '../../features/creation/editor_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/moments/moment_detail_screen.dart';
import '../../features/moments/moments_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/customize_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/world/world_screen.dart';
import '../../shared/components/app_shell.dart';
import '../../shared/components/splash_screen.dart';

const _authRoutes = {'/welcome', '/login', '/register', '/forgot'};

/// Pure redirect rules, kept separate so they can be unit-tested.
String? redirectFor({
  required String location,
  required bool signedIn,
  required bool prefsLoading,
  required bool prefsError,
  required bool onboarded,
}) {
  if (!signedIn) return _authRoutes.contains(location) ? null : '/welcome';
  if (prefsLoading || prefsError) return location == '/splash' ? null : '/splash';
  if (!onboarded) return location == '/onboarding' ? null : '/onboarding';
  if (location == '/splash' || location == '/' || _authRoutes.contains(location) || location == '/onboarding') return '/home';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionUserProvider, (_, _) => refresh.value++);
  ref.listen(preferencesProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  final router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    onException: (context, state, router) => router.go('/splash'),
    redirect: (context, state) {
      final prefs = ref.read(preferencesProvider);
      return redirectFor(
        location: state.matchedLocation,
        signedIn: ref.read(sessionUserProvider) != null,
        prefsLoading: !prefs.hasValue && !prefs.hasError,
        prefsError: prefs.hasError && !prefs.hasValue,
        onboarded: prefs.value?.onboarded ?? false,
      );
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/', redirect: (_, _) => '/splash'),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/moments', builder: (_, _) => const MomentsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/world', builder: (_, _) => const WorldScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),
      GoRoute(path: '/create', parentNavigatorKey: rootKey, pageBuilder: (_, s) => _fade(s, const CreateTypeScreen())),
      GoRoute(
        path: '/create/edit',
        parentNavigatorKey: rootKey,
        // no working draft (e.g. a restored route): start from the picker
        redirect: (_, _) => ref.read(draftProvider).active ? null : '/create',
        pageBuilder: (_, s) => _fade(s, const EditorScreen()),
      ),
      GoRoute(path: '/create/draw', parentNavigatorKey: rootKey, builder: (_, _) => const DrawScreen()),
      GoRoute(path: '/create/details', parentNavigatorKey: rootKey, builder: (_, _) => const DetailsScreen()),
      GoRoute(
        path: '/moment/:id',
        parentNavigatorKey: rootKey,
        pageBuilder: (_, s) => _fade(s, MomentDetailScreen(id: s.pathParameters['id']!, isNew: s.uri.queryParameters['new'] == '1'), ms: 420),
      ),
      GoRoute(path: '/customize', parentNavigatorKey: rootKey, pageBuilder: (_, s) => _fade(s, const CustomizeScreen())),
      GoRoute(path: '/settings', parentNavigatorKey: rootKey, builder: (_, _) => const SettingsScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

CustomTransitionPage<void> _fade(GoRouterState s, Widget child, {int ms = 360}) => CustomTransitionPage<void>(
  key: s.pageKey,
  child: child,
  transitionDuration: Duration(milliseconds: ms),
  reverseTransitionDuration: const Duration(milliseconds: 260),
  transitionsBuilder: (_, a, _, c) => FadeTransition(
    opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
    child: c,
  ),
);
