import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/config.dart';
import '../../app/providers.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import '../theme/language_controller.dart';
import '../widgets/widgets.dart';
import 'journey_controller.dart';
import 'manual_entry_sheet.dart';

/// Screen 3: Home Screen
/// - Hero BigActionButton: "Take a photo of the prescription" (camera) + "Choose from gallery"
/// - Row/wrap of "Demo prescriptions 1/2/3" chips (loads cached demos through the services)
/// - "My plan" (if saved)
/// - "Type medicines manually"
/// - LanguageToggle
/// - Long-press the logo to open Demo Tools (kDemoMode: quick-load Rx1/2/3, switch language,
///   reset, simulate offline)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _startDemoFlow(
    BuildContext context,
    WidgetRef ref,
    DemoPrescriptionId demo,
  ) async {
    HapticFeedback.mediumImpact();
    ref.read(journeyControllerProvider.notifier).stageDemoPrescription(demo);
    context.push('/reading');
  }

  Future<void> _openManualStart(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    ref.read(journeyControllerProvider.notifier).startManualPrescription();
    final added = await ManualEntrySheet.show(context);
    if (added == true && context.mounted) {
      context.push('/review');
    }
  }

  void _openDemoToolsSheet(BuildContext context, WidgetRef ref) {
    if (!kDemoMode) return;
    HapticFeedback.heavyImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Consumer(
          builder: (context, ref, _) {
            final offline = ref.watch(simulatedOfflineProvider);
            final cfg = ref.watch(appConfigProvider);
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTokens.space3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.science_rounded,
                          color: AppTokens.primaryTeal,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: BiText(
                            Bilingual(
                              ur: 'ڈیمو ٹولز (ججز اور ٹیسٹنگ کے لیے)',
                              en: 'Judge & Demo Tools (kDemoMode)',
                            ),
                            isHeadline: true,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                        ),
                      ],
                    ),
                    const Divider(),
                    const BiText(
                      Bilingual(
                        ur: 'فوری ڈیمو نسخہ لوڈ کریں:',
                        en: 'Quick-load synthetic demo prescription:',
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final demo in DemoPrescriptionId.values) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: BigActionButton(
                          icon: Icons.receipt_long_rounded,
                          isPrimary: false,
                          label: demo.title,
                          onPressed: () {
                            Navigator.of(sheetCtx).pop();
                            _startDemoFlow(context, ref, demo);
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const BiText(
                      Bilingual(
                        ur: 'زبان تبدیل کریں:',
                        en: 'Switch display language:',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(child: LanguageToggle()),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: offline,
                      activeThumbColor: AppTokens.primaryTeal,
                      title: const Text(
                        'Simulate Offline Mode • آف لائن موڈ',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: const Text(
                        'Tests OfflineBanner & local curated fallbacks',
                      ),
                      onChanged: (val) {
                        ref
                            .read(simulatedOfflineProvider.notifier)
                            .setOffline(val);
                      },
                    ),
                    const Divider(),
                    const BiText(
                      Bilingual(
                        ur: 'سروسز موڈ (Mock بمقابلہ Real Gemini/Firebase):',
                        en: 'Service Flags (Mock vs Real AI & Backend):',
                      ),
                      urduWeight: FontWeight.w700,
                      englishWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              ref
                                  .read(appConfigProvider.notifier)
                                  .setConfig(const AppConfig.allMock());
                            },
                            child: const Text('All Mock (Safe Demo)'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              ref
                                  .read(appConfigProvider.notifier)
                                  .setConfig(const AppConfig.allReal());
                            },
                            child: const Text('All Real (Gemini Live)'),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: !cfg.mockReader,
                      title: const Text('Real Gemini PrescriptionReader'),
                      onChanged: (real) => ref
                          .read(appConfigProvider.notifier)
                          .update((c) => c.copyWith(mockReader: !real)),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: !cfg.mockKnowledge,
                      title: const Text('Real Curated Knowledge & ScheduleEngine'),
                      onChanged: (real) => ref
                          .read(appConfigProvider.notifier)
                          .update((c) => c.copyWith(mockKnowledge: !real)),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: !cfg.mockQA,
                      title: const Text('Real Gemini Grounded QAService'),
                      onChanged: (real) => ref
                          .read(appConfigProvider.notifier)
                          .update((c) => c.copyWith(mockQA: !real)),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: !cfg.mockStrips,
                      title: const Text('Real Gemini StripMatcher'),
                      onChanged: (real) => ref
                          .read(appConfigProvider.notifier)
                          .update((c) => c.copyWith(mockStrips: !real)),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: !cfg.mockVoice,
                      title: const Text('Real Urdu TTS VoiceService'),
                      onChanged: (real) => ref
                          .read(appConfigProvider.notifier)
                          .update((c) => c.copyWith(mockVoice: !real)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        ref
                            .read(journeyControllerProvider.notifier)
                            .resetAll();
                        ref
                            .read(simulatedOfflineProvider.notifier)
                            .setOffline(false);
                        Navigator.of(sheetCtx).pop();
                      },
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Reset Demo State • ری سیٹ کریں'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(languageModeProvider);
    final journey = ref.watch(journeyControllerProvider);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final sections = <Widget>[
      const OfflineBanner(),
      // Clinic Header with Long-Press Logo for Demo Tools
      Container(
        padding: const EdgeInsets.all(AppTokens.space2),
        decoration: BoxDecoration(
          color: AppTokens.cardCream,
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          border: Border.all(color: AppTokens.borderWarm, width: 1.4),
          boxShadow: AppTokens.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Semantics(
                  button: true,
                  label:
                      'ShifaLens logo. Long press to open Demo Tools when in demo mode.',
                  child: GestureDetector(
                    key: const Key('home_logo_long_press'),
                    onLongPress: () => _openDemoToolsSheet(context, ref),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTokens.primaryTeal,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppTokens.cardShadow,
                      ),
                      child: const Icon(
                        Icons.local_pharmacy_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.space2),
                const Expanded(
                  child: BiText(
                    Bilingual(
                      ur: 'شفا لینز — آپ کا مہربان فارماسسٹ',
                      en: 'ShifaLens • Friendly Pharmacist Guide',
                    ),
                    isHeadline: true,
                    urduColor: AppTokens.primaryTealDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const BiText(
              Bilingual(
                ur: 'نسخے کی تصویر لیں، اپنی دوائیوں کی تصدیق کریں، اور کھانے کے اوقات کے مطابق تصویری شیڈول بنائیں۔',
                en: 'Take a photo of your prescription, confirm each medicine, and get a clear meal-based picture schedule.',
              ),
            ),
            const SizedBox(height: 14),
            const Center(child: LanguageToggle()),
          ],
        ),
      ),
      const SizedBox(height: AppTokens.space3),

      // Primary Hero Actions: Camera + Gallery
      BigActionButton(
        key: const Key('home_take_photo_button'),
        icon: Icons.camera_alt_rounded,
        label: const Bilingual(
          ur: 'نسخے کی تصویر لیں (کیمرہ)',
          en: 'Take a photo of the prescription',
        ),
        onPressed: () => context.push('/capture?source=camera'),
      ),
      const SizedBox(height: 14),
      BigActionButton(
        key: const Key('home_choose_gallery_button'),
        icon: Icons.photo_library_rounded,
        isPrimary: false,
        label: const Bilingual(
          ur: 'گیلری سے تصویر منتخب کریں',
          en: 'Choose from gallery',
        ),
        onPressed: () => context.push('/capture?source=gallery'),
      ),
      const SizedBox(height: 14),
      BigActionButton(
        key: const Key('home_manual_entry_button'),
        icon: Icons.edit_note_rounded,
        isPrimary: false,
        label: const Bilingual(
          ur: 'دوائیں خود لکھ کر درج کریں',
          en: 'Type medicines manually',
        ),
        onPressed: () => _openManualStart(context, ref),
      ),

      // Saved Plan button (if a DailyPlan is saved in state/repository)
      if (journey.latestPlan != null) ...[
        const SizedBox(height: 14),
        BigActionButton(
          key: const Key('home_my_plan_button'),
          icon: Icons.calendar_month_rounded,
          backgroundColor: AppTokens.morningSaffronTint,
          foregroundColor: AppTokens.ink,
          iconBadgeColor: AppTokens.morningSaffron,
          isPrimary: false,
          label: Bilingual(
            ur: 'میرا محفوظ شدہ شیڈول دیکھیں (${journey.latestPlan!.scheduled.length} دوائیں)',
            en: 'My plan (${journey.latestPlan!.scheduled.length} scheduled medicines)',
          ),
          onPressed: () => context.push('/plan'),
        ),
      ],

      const SizedBox(height: AppTokens.space3),

      // Demo Prescriptions 1 / 2 / 3 Section
      Container(
        padding: const EdgeInsets.all(AppTokens.space2),
        decoration: BoxDecoration(
          color: AppTokens.cardCream,
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          border: Border.all(color: AppTokens.borderWarm, width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTokens.morningSaffronTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: AppTokens.morningSaffronDark,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: BiText(
                    Bilingual(
                      ur: 'ڈیمو نسخے آزمائیں (فرضی مریض ۱، ۲، ۳)',
                      en: 'Try Demo Prescriptions (Synthetic Rx 1 / 2 / 3)',
                    ),
                    isHeadline: true,
                    urduSize: 22,
                    englishSize: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final demo in DemoPrescriptionId.values) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Semantics(
                  button: true,
                  label: '${demo.title.ur}. ${demo.title.en}',
                  child: InkWell(
                    key: Key('demo_chip_${demo.code.toLowerCase()}'),
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _startDemoFlow(context, ref, demo),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: AppTokens.minTapTarget,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTokens.surfaceWarm,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppTokens.primaryTeal.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          PillBadge(demo.index, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                BiText(
                                  demo.title,
                                  urduWeight: FontWeight.w700,
                                  englishWeight: FontWeight.w700,
                                ),
                                const SizedBox(height: 2),
                                BiText(demo.subtitle),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.play_circle_fill_rounded,
                            color: AppTokens.primaryTeal,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppTokens.space3),
      SafetyBanner.prototype(),
    ];

    return Directionality(
      textDirection: mode.direction,
      child: Scaffold(
        backgroundColor: AppTokens.surfaceCream,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.space2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < sections.length; i++)
                  reduceMotion
                      ? sections[i]
                      : sections[i]
                          .animate()
                          .fadeIn(
                            delay: Duration(milliseconds: 35 * i),
                            duration: AppTokens.motionFast,
                          ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
