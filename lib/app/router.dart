import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../ui/screens/screens.dart';

/// ShifaLens GoRouter configuration [Owner: Person B]
/// Core user journey:
/// Splash (/) -> Onboarding (/onboarding) -> Home (/home) ->
/// Capture (/capture) -> AI Reading (/reading) -> Review & Confirm (/review) ->
/// Daily Plan (/plan)
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (BuildContext context, GoRouterState state) {
          return const SplashScreen();
        },
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (BuildContext context, GoRouterState state) {
          return const OnboardingScreen();
        },
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (BuildContext context, GoRouterState state) {
          return const HomeScreen();
        },
      ),
      GoRoute(
        path: '/capture',
        name: 'capture',
        builder: (BuildContext context, GoRouterState state) {
          final source = state.uri.queryParameters['source'] ?? 'camera';
          return CaptureScreen(initialSource: source);
        },
      ),
      GoRoute(
        path: '/reading',
        name: 'reading',
        builder: (BuildContext context, GoRouterState state) {
          return const AiReadingScreen();
        },
      ),
      GoRoute(
        path: '/review',
        name: 'review',
        builder: (BuildContext context, GoRouterState state) {
          return const ReviewConfirmScreen();
        },
      ),
      GoRoute(
        path: '/plan',
        name: 'plan',
        builder: (BuildContext context, GoRouterState state) {
          return const PlanPlaceholderScreen();
        },
      ),
    ],
  );
});

/// Convenience builder for creating a standalone GoRouter in tests or main.dart
GoRouter createAppRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const HomeScreen(),
      ),
      GoRoute(
        path: '/capture',
        builder: (_, state) => CaptureScreen(
          initialSource: state.uri.queryParameters['source'] ?? 'camera',
        ),
      ),
      GoRoute(
        path: '/reading',
        builder: (_, _) => const AiReadingScreen(),
      ),
      GoRoute(
        path: '/review',
        builder: (_, _) => const ReviewConfirmScreen(),
      ),
      GoRoute(
        path: '/plan',
        builder: (_, _) => const PlanPlaceholderScreen(),
      ),
    ],
  );
}
