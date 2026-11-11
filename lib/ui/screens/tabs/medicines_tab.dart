import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/models.dart';
import '../../theme/app_tokens.dart';
import '../../theme/language_controller.dart';
import '../../widgets/widgets.dart';
import '../journey_controller.dart';

/// Part 4 Feature #3: MEDICINES TAB + DETAIL SHEET
/// - One card per medicine showing PillBadge, brand + generic, strength, duration,
///   and tap prompt.
/// - On tap, a detail bottom sheet shows:
///   (a) Food-medicine cards as big pictograms (avoid / keep steady / take with food /
///       empty stomach / separate by hours), each with BiText + listen button + ReviewBadge;
///   (b) "Common effects" in calm style and "Call your doctor if..." in a distinct
///       red-tinted style; both with ReviewBadge when reviewed=false.
///   No invented text: renders ONLY what DailyPlan / KnowledgeService returns.
class MedicinesTab extends ConsumerWidget {
  const MedicinesTab({super.key});

  List<FoodCard> _resolveFoodCards(
    WidgetRef ref,
    DailyPlan plan,
    MedicineLine med,
  ) {
    final fromPlan = plan.foodCardsByMedicineId[med.id];
    if (fromPlan != null && fromPlan.isNotEmpty) return fromPlan;
    final generic = med.genericName;
    if (generic == null || generic.trim().isEmpty) return const [];
    try {
      return ref.read(knowledgeServiceProvider).foodCardsFor(generic);
    } catch (_) {
      return const [];
    }
  }

  SideEffectInfo? _resolveSideEffects(
    WidgetRef ref,
    DailyPlan plan,
    MedicineLine med,
  ) {
    final fromPlan = plan.sideEffectsByMedicineId[med.id];
    if (fromPlan != null) return fromPlan;
    final generic = med.genericName;
    if (generic == null || generic.trim().isEmpty) return null;
    try {
      return ref.read(knowledgeServiceProvider).sideEffectsFor(generic);
    } catch (_) {
      return null;
    }
  }

  void _openMedicineDetailSheet(
    BuildContext context,
    WidgetRef ref,
    DailyPlan plan,
    MedicineLine med,
  ) {
    HapticFeedback.lightImpact();
    final foodCards = _resolveFoodCards(ref, plan, med);
    final sideEffects = _resolveSideEffects(ref, plan, med);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MedicineDetailSheet(
        medicine: med,
        foodCards: foodCards,
        sideEffects: sideEffects,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(journeyControllerProvider);
    final plan = journey.latestPlan;

    if (plan == null) {
      return const Padding(
        padding: EdgeInsets.all(AppTokens.space2),
        child: EmptyState(
          icon: Icons.medication_rounded,
          title: Bilingual(
            ur: 'ابھی کوئی دوا شامل نہیں ہے',
            en: 'No medicines loaded yet',
          ),
          subtitle: Bilingual(
            ur: 'پہلے نسخے کی تصدیق کریں تاکہ دوائیوں اور کھانے کی ہدایات نظر آئیں۔',
            en: 'Confirm a prescription first to view medicine food cards and safety notes.',
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppTokens.space2),
      children: [
        const OfflineBanner(),
        const BiText(
          Bilingual(
            ur: 'آپ کی دوائیں، پرہیز اور احتیاطی ہدایات',
            en: 'Your Medicines, Food Guides & Side Effects',
          ),
          isHeadline: true,
          urduColor: AppTokens.primaryTealDark,
        ),
        const SizedBox(height: 6),
        const BiText(
          Bilingual(
            ur: 'کھانے کے اصول اور علامات دیکھنے کے لیے کسی بھی دوا پر ٹیپ کریں۔',
            en: 'Tap any medicine card to open its food pictograms and "Call your doctor if..." safety sheet.',
          ),
        ),
        const SizedBox(height: 16),

        for (final med in plan.scheduled) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.space2),
            child: Semantics(
              button: true,
              label:
                  'View food rules and side effects for ${med.brandName ?? med.rawText}',
              child: Material(
                color: AppTokens.cardCream,
                borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                child: InkWell(
                  key: Key('medicine_tab_card_${med.id}'),
                  borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                  onTap: () =>
                      _openMedicineDetailSheet(context, ref, plan, med),
                  child: Container(
                    padding: const EdgeInsets.all(AppTokens.space2),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppTokens.cardRadius),
                      border: Border.all(
                        color: AppTokens.borderWarm,
                        width: 1.5,
                      ),
                      boxShadow: AppTokens.cardShadow,
                    ),
                    child: Row(
                      children: [
                        PillBadge(med.identityIndex, size: 56),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              BiText(
                                Bilingual(
                                  ur: '${med.brandName ?? med.rawText} (${med.strength ?? ""})',
                                  en: '${med.brandName ?? med.rawText} • ${med.strength ?? ""}',
                                ),
                                isHeadline: true,
                              ),
                              const SizedBox(height: 4),
                              BiText(
                                Bilingual(
                                  ur: 'فارمولا: ${med.genericName ?? "—"}',
                                  en: 'Generic: ${med.genericName ?? "—"} • ${med.durationDays ?? "—"} days',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 32,
                          color: AppTokens.primaryTeal,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],

        if (plan.unscheduled.isNotEmpty) ...[
          const SizedBox(height: 8),
          const BiText(
            Bilingual(
              ur: 'غیر واضح دوائیں (پہلے فارماسسٹ سے پوچھیں):',
              en: 'Unscheduled — Ask your pharmacist first:',
            ),
            isHeadline: true,
            urduColor: AppTokens.warningAmberDark,
          ),
          const SizedBox(height: 8),
          for (final u in plan.unscheduled)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(AppTokens.space2),
              decoration: BoxDecoration(
                color: AppTokens.warningAmberTint,
                borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                border: Border.all(color: AppTokens.warningAmber, width: 1.5),
              ),
              child: Row(
                children: [
                  PillBadge(u.identityIndex, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BiText(
                      Bilingual(
                        ur: '${u.rawText} — فارماسسٹ سے تصدیق کریں',
                        en: '${u.rawText} — Verify with your pharmacist',
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: AppTokens.space2),
        SafetyBanner.prototype(),
      ],
    );
  }
}

class _MedicineDetailSheet extends ConsumerWidget {
  final MedicineLine medicine;
  final List<FoodCard> foodCards;
  final SideEffectInfo? sideEffects;

  const _MedicineDetailSheet({
    required this.medicine,
    required this.foodCards,
    required this.sideEffects,
  });

  static ({IconData icon, Color fg, Color bg, Bilingual typeBadge})
      _foodTypeVisual(FoodCardType type) {
    switch (type) {
      case FoodCardType.avoid:
        return (
          icon: Icons.no_food_rounded,
          fg: AppTokens.alertCoralDark,
          bg: AppTokens.alertCoralTint,
          typeBadge: const Bilingual(ur: 'پرہیز کریں', en: 'Avoid'),
        );
      case FoodCardType.keepSteady:
        return (
          icon: Icons.balance_rounded,
          fg: AppTokens.eveningIndigo,
          bg: AppTokens.eveningIndigoTint,
          typeBadge:
              const Bilingual(ur: 'مقدار یکساں رکھیں', en: 'Keep steady'),
        );
      case FoodCardType.takeWithFood:
        return (
          icon: Icons.restaurant_rounded,
          fg: AppTokens.successGreenDark,
          bg: AppTokens.successGreenTint,
          typeBadge:
              const Bilingual(ur: 'کھانے کے ساتھ لیں', en: 'Take with food'),
        );
      case FoodCardType.emptyStomach:
        return (
          icon: Icons.schedule_rounded,
          fg: AppTokens.morningSaffronDark,
          bg: AppTokens.morningSaffronTint,
          typeBadge: const Bilingual(ur: 'خالی پیٹ لیں', en: 'Empty stomach'),
        );
      case FoodCardType.separateFrom:
        return (
          icon: Icons.compare_arrows_rounded,
          fg: AppTokens.warningAmberDark,
          bg: AppTokens.warningAmberTint,
          typeBadge:
              const Bilingual(ur: 'وقفہ رکھیں', en: 'Separate by hours'),
        );
    }
  }

  Future<void> _speakText(WidgetRef ref, Bilingual text) async {
    HapticFeedback.selectionClick();
    try {
      final lang = ref.read(languageModeProvider).primaryLang;
      await ref.read(voiceServiceProvider).speak(text, lang: lang);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(languageModeProvider);

    return Directionality(
      textDirection: mode.direction,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sheet Header
            Row(
              children: [
                PillBadge(medicine.identityIndex, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: BiText(
                    Bilingual(
                      ur: '${medicine.brandName ?? medicine.rawText} (${medicine.strength ?? ""})',
                      en: '${medicine.brandName ?? medicine.rawText} • ${medicine.genericName ?? ""}',
                    ),
                    isHeadline: true,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),

            // (a) Food-Medicine Cards as Big Pictograms
            const BiText(
              Bilingual(
                ur: 'کھانے اور پرہیز کی ہدایات (تصویری کارڈز):',
                en: 'Food & Medicine Pictogram Cards:',
              ),
              isHeadline: true,
              urduColor: AppTokens.primaryTealDark,
            ),
            const SizedBox(height: 12),

            if (foodCards.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppTokens.space2),
                decoration: BoxDecoration(
                  color: AppTokens.surfaceWarm,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTokens.borderWarm),
                ),
                child: const BiText(
                  Bilingual(
                    ur: 'مقامی جدول میں اس دوا کے لیے کوئی خاص غذائی احتیاط درج نہیں ہے۔ اپنے فارماسسٹ سے پوچھیں۔',
                    en: 'No specific curated food cards on file for this generic. Ask your pharmacist if unsure.',
                  ),
                ),
              ),

            for (final card in foodCards) ...[
              Builder(
                builder: (context) {
                  final vis = _foodTypeVisual(card.type);
                  return Container(
                    key: Key('food_card_${card.id}'),
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(AppTokens.space2),
                    decoration: BoxDecoration(
                      color: AppTokens.cardCream,
                      borderRadius:
                          BorderRadius.circular(AppTokens.cardRadius),
                      border: Border.all(
                        color: vis.fg.withValues(alpha: 0.45),
                        width: 1.6,
                      ),
                      boxShadow: AppTokens.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Big Pictogram Badge
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: vis.bg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                vis.icon,
                                size: 36,
                                color: vis.fg,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  BiText(
                                    vis.typeBadge,
                                    urduColor: vis.fg,
                                    englishColor: vis.fg,
                                    urduWeight: FontWeight.w700,
                                    englishWeight: FontWeight.w700,
                                  ),
                                  const SizedBox(height: 4),
                                  BiText(
                                    card.title,
                                    isHeadline: true,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Listen in Urdu • آواز میں سنیں',
                              icon: const Icon(
                                Icons.volume_up_rounded,
                                color: AppTokens.primaryTeal,
                                size: 28,
                              ),
                              onPressed: () => _speakText(
                                ref,
                                Bilingual(
                                  ur: '${card.title.ur}۔ ${card.body.ur}',
                                  en: '${card.title.en}. ${card.body.en}',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        BiText(card.body),
                        if (!card.reviewed) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: ReviewBadge(reviewed: card.reviewed),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 12),

            // (b) Side Effects: "Common effects" (calm style) + "Call your doctor if..." (red-tinted style)
            if (sideEffects != null) ...[
              // Calm Common Effects Card
              Container(
                key: const Key('side_effects_common_card'),
                padding: const EdgeInsets.all(AppTokens.space2),
                decoration: BoxDecoration(
                  color: AppTokens.primaryTealSurface,
                  borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                  border: Border.all(
                    color: AppTokens.primaryTeal.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.spa_rounded,
                          color: AppTokens.primaryTealDark,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: BiText(
                            Bilingual(
                              ur: 'عام اور معمولی اثرات (گھبرانے کی بات نہیں):',
                              en: 'Common effects (usually mild):',
                            ),
                            isHeadline: true,
                            urduColor: AppTokens.primaryTealDark,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Listen to common effects',
                          icon: const Icon(
                            Icons.volume_up_rounded,
                            color: AppTokens.primaryTealDark,
                          ),
                          onPressed: () =>
                              _speakText(ref, sideEffects!.common),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    BiText(sideEffects!.common),
                    if (!sideEffects!.reviewed) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ReviewBadge(reviewed: sideEffects!.reviewed),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Distinct Red-Tinted "Call your doctor if..." Card
              if (sideEffects!.callDoctorIf.isNotEmpty)
                Container(
                  key: const Key('side_effects_call_doctor_card'),
                  padding: const EdgeInsets.all(AppTokens.space2),
                  decoration: BoxDecoration(
                    color: AppTokens.alertCoralTint,
                    borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                    border: Border.all(
                      color: AppTokens.alertCoral,
                      width: 2.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.emergency_rounded,
                            color: AppTokens.alertCoralDark,
                            size: 30,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: BiText(
                              Bilingual(
                                ur: 'فوراً اپنے ڈاکٹر سے رابطہ کریں اگر:',
                                en: 'Call your doctor if...',
                              ),
                              isHeadline: true,
                              urduColor: AppTokens.alertCoralDark,
                              englishColor: AppTokens.alertCoralDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final warning in sideEffects!.callDoctorIf)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Icon(
                                  Icons.warning_rounded,
                                  color: AppTokens.alertCoralDark,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: BiText(
                                  warning,
                                  urduColor: AppTokens.alertCoralDark,
                                  englishColor: AppTokens.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!sideEffects!.reviewed) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: ReviewBadge(reviewed: sideEffects!.reviewed),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
            const SizedBox(height: AppTokens.space2),
            SafetyBanner.prototype(),
          ],
        ),
      ),
    );
  }
}
