import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/config.dart';
import 'app/providers.dart';
import 'core/models/models.dart';
import 'core/strings_disclosure.dart';
import 'firebase_options.dart';
import 'services/real/real_reminder_service.dart';

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
    final lang = ref.watch(langProvider);
    return MaterialApp(
      title: 'ShifaLens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D7377)),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Directionality(
          textDirection:
              lang == Lang.ur ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _BootstrapHomeScreen(),
    );
  }
}

class _BootstrapHomeScreen extends ConsumerWidget {
  const _BootstrapHomeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final lang = ref.watch(langProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(ShifaLensDisclosureStrings.appTitle.forLang(lang)),
        actions: [
          TextButton(
            onPressed: () => ref.read(langProvider.notifier).toggle(),
            child: Text(lang == Lang.ur ? 'EN' : 'اردو'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${ShifaLensDisclosureStrings.tagline.ur}\n'
                '${ShifaLensDisclosureStrings.tagline.en}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Demo Mode: $kDemoMode | Mock Reader: ${config.mockReader}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                ShifaLensDisclosureStrings.prototypeBanner.ur,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
