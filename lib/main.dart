import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'firebase_options.dart';
import 'services/real/real_reminder_service.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/language_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase + Anonymous Auth on startup (Rule 6 & Part 2 Task 4)
  try {
    if (DefaultFirebaseOptions.isConfigured) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp();
    }
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (_) {
    // Runs offline/in demo mode even if Firebase credentials are not supplied
  }

  // Reschedule saved local dose notifications after device reboot / app start
  try {
    await RealReminderService().rescheduleSavedPlanIfPresent();
  } catch (_) {}

  runApp(const ProviderScope(child: ShifaLensApp()));
}

class ShifaLensApp extends ConsumerWidget {
  const ShifaLensApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langMode = ref.watch(languageModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'ShifaLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) {
        return Directionality(
          textDirection: langMode.direction,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
