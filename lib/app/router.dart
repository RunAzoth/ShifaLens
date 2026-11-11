import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../ui/screens/screens.dart';

/// ShifaLens GoRouter configuration [Owner: Person B]
/// Full user journey (Part 3 + Part 4):
/// Splash (/) -> Onboarding (/onboarding) -> Home (/home) ->
/// Capture (/capture) -> AI Reading (/reading) -> Review & Confirm (/review) ->
/// Plan Hub (/plan: Today, Medicines, Ask, Reminders) ->
/// Extras: Strip Matching (/strips), Print Card/Stickers (/print),
/// Plate Guide (/plate-guide), About & Responsible AI (/about).
final routerProvider = Provider<GoRouter>((ref) {
  return createAppRouter();
});

GoRouter createAppRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
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
          final tabParam = state.uri.queryParameters['tab'];
          final initialTab = int.tryParse(tabParam ?? '0') ?? 0;
          return PlanHubScreen(initialTabIndex: initialTab);
        },
      ),
      GoRoute(
        path: '/strips',
        name: 'strips',
        builder: (BuildContext context, GoRouterState state) {
          return const StripMatchingScreen();
        },
      ),
      GoRoute(
        path: '/print',
        name: 'print',
        builder: (BuildContext context, GoRouterState state) {
          final mode = PrintMode.fromQuery(state.uri.queryParameters['mode']);
          return PrintScreen(initialMode: mode);
        },
      ),
      GoRoute(
        path: '/plate-guide',
        name: 'plate_guide',
        builder: (BuildContext context, GoRouterState state) {
          return const PlateGuideScreen();
        },
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (BuildContext context, GoRouterState state) {
          return const AboutScreen();
        },
      ),
    ],
  );
}
