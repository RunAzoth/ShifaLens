import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import '../theme/language_controller.dart';
import '../widgets/widgets.dart';
import 'journey_controller.dart';

/// Screen 8 (Part 3 Deliverable Target): Plan route navigated to after
/// calling `ScheduleEngine.build`.
/// Displays the confirmed scheduled doses (with SlotIcon & PillBadge) and the
/// separate "Not scheduled — Ask your pharmacist" list (Non-negotiable Rule #2).
/// Person B expands this with full Part 4 features in the next phase.
class PlanPlaceholderScreen extends ConsumerWidget {
  const PlanPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(languageModeProvider);
    final journey = ref.watch(journeyControllerProvider);
    final plan = journey.latestPlan;

    return Directionality(
      textDirection: mode.direction,
      child: Scaffold(
        backgroundColor: AppTokens.surfaceCream,
        appBar: AppBar(
          title: const Text('My Daily Plan • میرا روزانہ شیڈول'),
          actions: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: LanguageToggle(compact: true),
            ),
          ],
        ),
        body: SafeArea(
          child: plan == null
              ? Padding(
                  padding: const EdgeInsets.all(AppTokens.space2),
                  child: EmptyState(
                    icon: Icons.calendar_today_rounded,
                    title: const Bilingual(
                      ur: 'ابھی کوئی شیڈول تیار نہیں ہوا',
                      en: 'No daily plan created yet',
                    ),
                    subtitle: const Bilingual(
                      ur: 'پہلے نسخے کی تصویر لیں اور دوائیوں کی تصدیق کریں۔',
                      en: 'Scan and confirm a prescription first to generate your plan.',
                    ),
                    actionLabel: const Bilingual(
                      ur: 'ہوم اسکرین پر جائیں',
                      en: 'Go to Home',
                    ),
                    onAction: () => context.go('/home'),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTokens.space2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const OfflineBanner(),
                      const AiTag(),
                      const SizedBox(height: 12),

                      // Duplicate alerts if any
                      for (final dup in plan.duplicates) ...[
                        SafetyBanner.fromDuplicate(dup),
                        const SizedBox(height: 12),
                      ],

                      // Scheduled Medicines Summary Card
                      Container(
                        padding: const EdgeInsets.all(AppTokens.space2),
                        decoration: BoxDecoration(
                          color: AppTokens.cardCream,
                          borderRadius:
                              BorderRadius.circular(AppTokens.cardRadius),
                          border: Border.all(
                            color: AppTokens.primaryTeal,
                            width: 1.6,
                          ),
                          boxShadow: AppTokens.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BiText(
                              Bilingual(
                                ur: 'شیڈول شدہ دوائیں (${plan.scheduled.length})',
                                en: 'Scheduled Medicines (${plan.scheduled.length})',
                              ),
                              isHeadline: true,
                              urduColor: AppTokens.primaryTealDark,
                            ),
                            const SizedBox(height: 12),
                            for (final med in plan.scheduled) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Hero(
                                      tag: 'pill_badge_${med.id}',
                                      child: PillBadge(
                                        med.identityIndex,
                                        size: 48,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: BiText(
                                        Bilingual(
                                          ur: '${med.brandName ?? med.rawText} (${med.strength ?? ""})',
                                          en: '${med.brandName ?? med.rawText} ${med.strength ?? ""} • ${med.frequencyRaw ?? ""}',
                                        ),
                                        urduWeight: FontWeight.w700,
                                        englishWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (plan.doses.isNotEmpty) ...[
                              const Divider(),
                              const BiText(
                                Bilingual(
                                  ur: 'کھانے کے اوقات کے مطابق خوراک:',
                                  en: 'Meal-Based Daily Doses:',
                                ),
                                urduWeight: FontWeight.w700,
                                englishWeight: FontWeight.w700,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: plan.doses.map((dose) {
                                  final med = plan.scheduled
                                      .where((m) => m.id == dose.medicineId)
                                      .firstOrNull;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTokens.surfaceWarm,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppTokens.borderWarm,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SlotIcon(
                                          dose.slot,
                                          size: 40,
                                          showLabel: true,
                                        ),
                                        if (med != null) ...[
                                          const SizedBox(width: 8),
                                          PillBadge(
                                            med.identityIndex,
                                            size: 36,
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Non-Negotiable Rule #2: Separate "Not scheduled — Ask your pharmacist" list
                      if (plan.unscheduled.isNotEmpty) ...[
                        const SizedBox(height: AppTokens.space2),
                        Container(
                          key: const Key('plan_unscheduled_section'),
                          padding: const EdgeInsets.all(AppTokens.space2),
                          decoration: BoxDecoration(
                            color: AppTokens.warningAmberTint,
                            borderRadius:
                                BorderRadius.circular(AppTokens.cardRadius),
                            border: Border.all(
                              color: AppTokens.warningAmber,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.local_pharmacy_rounded,
                                    color: AppTokens.warningAmberDark,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: BiText(
                                      Bilingual(
                                        ur: 'شیڈول میں شامل نہیں — فارماسسٹ سے پوچھیں (${plan.unscheduled.length})',
                                        en: 'Not scheduled — Ask your pharmacist (${plan.unscheduled.length})',
                                      ),
                                      isHeadline: true,
                                      urduColor: AppTokens.warningAmberDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              for (final unsched in plan.unscheduled)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      PillBadge(
                                        unsched.identityIndex,
                                        size: 42,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: BiText(
                                          Bilingual(
                                            ur: '${unsched.rawText} — پہلے فارماسسٹ سے تصدیق کریں',
                                            en: '${unsched.rawText} — Verify with your pharmacist before taking',
                                          ),
                                          urduColor: AppTokens.warningAmberDark,
                                          englishColor: AppTokens.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppTokens.space3),
                      BigActionButton(
                        icon: Icons.home_rounded,
                        isPrimary: false,
                        label: const Bilingual(
                          ur: 'ہوم اسکرین پر واپس جائیں',
                          en: 'Back to Home',
                        ),
                        onPressed: () => context.go('/home'),
                      ),
                      const SizedBox(height: AppTokens.space2),
                      SafetyBanner.prototype(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
