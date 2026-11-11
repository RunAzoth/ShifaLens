import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/config.dart';
import 'app/providers.dart';
import 'core/models/models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        title: Text(
          lang == Lang.ur
              ? 'شفا لینز (ShifaLens)'
              : 'ShifaLens — Pharmacist Companion',
        ),
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
              const Text(
                'ہر مریض کے لیے فارماسسٹ کی وضاحت، اردو میں، تصویروں کے ساتھ۔\n'
                'A pharmacist\'s explanation for every patient, in Urdu, with pictures.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Demo Mode: $kDemoMode | Mock Reader: ${config.mockReader}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Prototype. Not a medical device. / پروٹوٹائپ۔ یہ طبی آلہ نہیں ہے۔',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
