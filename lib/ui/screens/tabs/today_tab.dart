import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/models/models.dart';
import '../../theme/app_tokens.dart';
import '../../theme/language_controller.dart';
import '../../theme/role_controller.dart';
import '../../widgets/widgets.dart';
import '../journey_controller.dart';

/// Part 4 Feature #1 & #2: TODAY TIMELINE (Hero screen) + RAMADAN TOGGLE
/// - Vertical "day arc" whose background gradient shifts from sunrise saffron to night indigo
/// - Ramadan switch on Today header -> rebuilds via ScheduleEngine(ramadan: true),
///   shows suhoor/iftar slots, persistent banner "Suggested layout. Confirm with your doctor
///   before using it.", and checkbox "My doctor approved this" (ramadanDoctorApproved).
/// - Top of screen:
///   - DuplicateAlert banner (coral, big icon, plain language) if any
///   - "Not scheduled: ask your pharmacist" section for unscheduled lines (never hidden)
///   - Persistent sticky voice bar "🔊 Listen to my plan" (shows waveform while speaking)
///     using VoiceService + describePlanUrdu
///   - AiTag on AI-derived content
///   - ReviewBadge wherever a curated table with reviewed=false is shown
/// - Slots in order with SlotIcon, time from MealTimes, animated "Now" marker, and
///   DoseCards showing PillBadge, generic + brand, strength, and relation chip.
///   Tap a dose to mark taken (haptic + check animation).
class TodayTab extends ConsumerStatefulWidget {
  const TodayTab({super.key});

  @override
  ConsumerState<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends ConsumerState<TodayTab> {
  bool _localSpeakingFallback = false;

  static const List<MealSlot> _standardSlotOrder = [
    MealSlot.wakeUp,
    MealSlot.breakfast,
    MealSlot.midMorning,
    MealSlot.lunch,
    MealSlot.afternoon,
    MealSlot.dinner,
    MealSlot.bedtime,
    MealSlot.whenNeeded,
  ];

  static const List<MealSlot> _ramadanSlotOrder = [
    MealSlot.suhoor,
    MealSlot.iftar,
    MealSlot.dinner,
    MealSlot.bedtime,
    MealSlot.whenNeeded,
  ];

  static Bilingual _relationLabel(MealRelation relation) {
    switch (relation) {
      case MealRelation.before:
        return const Bilingual(ur: 'کھانے سے پہلے', en: 'Before meal');
      case MealRelation.withMeal:
        return const Bilingual(ur: 'کھانے کے ساتھ', en: 'With meal');
      case MealRelation.after:
        return const Bilingual(ur: 'کھانے کے بعد', en: 'After meal');
      case MealRelation.emptyStomach:
        return const Bilingual(ur: 'خالی پیٹ', en: 'Empty stomach');
      case MealRelation.anytime:
        return const Bilingual(ur: 'ضرورت کے وقت', en: 'As needed');
    }
  }

  Future<void> _toggleListenPlan(DailyPlan plan) async {
    HapticFeedback.mediumImpact();
    try {
      final voice = ref.read(voiceServiceProvider);
      if (_localSpeakingFallback) {
        setState(() => _localSpeakingFallback = false);
        await voice.stop();
        return;
      }
      setState(() => _localSpeakingFallback = true);
      final urduSummary = voice.describePlanUrdu(plan);
      final lang = ref.read(languageModeProvider).primaryLang;
      await voice.speak(
        Bilingual(
          ur: urduSummary,
          en: 'Your daily plan has ${plan.scheduled.length} scheduled medicines and ${plan.doses.length} doses.',
        ),
        lang: lang,
      );
    } catch (_) {
      // Keep UI responsive in widget tests
    }
  }

  MealSlot _currentNowSlot(bool ramadan) {
    final hour = DateTime.now().hour;
    if (ramadan) {
      if (hour < 10) return MealSlot.suhoor;
      if (hour < 20) return MealSlot.iftar;
      return MealSlot.bedtime;
    }
    if (hour < 8) return MealSlot.wakeUp;
    if (hour < 11) return MealSlot.breakfast;
    if (hour < 16) return MealSlot.lunch;
    if (hour < 21) return MealSlot.dinner;
    return MealSlot.bedtime;
  }

  bool _hasUnreviewedCuratedContent(DailyPlan plan) {
    for (final cards in plan.foodCardsByMedicineId.values) {
      if (cards.any((c) => !c.reviewed)) return true;
    }
    for (final se in plan.sideEffectsByMedicineId.values) {
      if (!se.reviewed) return true;
    }
    // Default true for safety if curated map is empty so ReviewBadge is visible
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final journey = ref.watch(journeyControllerProvider);
    final plan = journey.latestPlan;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (plan == null) {
      return Padding(
        padding: const EdgeInsets.all(AppTokens.space2),
        child: EmptyState(
          icon: Icons.wb_sunny_rounded,
          title: const Bilingual(
            ur: 'آج کا شیڈول تیار نہیں ہے',
            en: 'No daily timeline yet',
          ),
          subtitle: const Bilingual(
            ur: 'ہوم اسکرین سے نسخے کی تصویر لیں یا ڈیمو نسخہ ۱، ۲، ۳ منتخب کریں۔',
            en: 'Scan a prescription or pick Demo Rx 1/2/3 from Home to see your meal-based timeline.',
          ),
          actionLabel: const Bilingual(
            ur: 'ہوم اسکرین پر جائیں',
            en: 'Go to Home',
          ),
          onAction: () => context.go('/home'),
        ),
      );
    }

    Stream<bool>? speakingStream;
    try {
      speakingStream = ref.watch(voiceServiceProvider).isSpeaking;
    } catch (_) {}

    final slotOrder =
        plan.ramadan ? _ramadanSlotOrder : _standardSlotOrder;
    final activeSlots = slotOrder.where((slot) {
      return plan.doses.any((d) => d.slot == slot);
    }).toList();

    final nowSlot = _currentNowSlot(plan.ramadan);
    final hasUnreviewed = _hasUnreviewedCuratedContent(plan);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Persistent Sticky Voice Bar: "🔊 Listen to my plan"
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space2,
            8,
            AppTokens.space2,
            6,
          ),
          child: StreamBuilder<bool>(
            stream: speakingStream,
            initialData: _localSpeakingFallback,
            builder: (context, snapshot) {
              final isSpeaking =
                  (snapshot.data ?? false) || _localSpeakingFallback;
              return _StickyListenPlanBar(
                isSpeaking: isSpeaking,
                reduceMotion: reduceMotion,
                onTap: () => _toggleListenPlan(plan),
              );
            },
          ),
        ),

        // Scrollable Day Arc Timeline
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppTokens.space2),
            children: [
              const OfflineBanner(),
              const AiTag(compact: true),
              const SizedBox(height: 8),
              if (hasUnreviewed) ...[
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ReviewBadge(reviewed: false),
                ),
                const SizedBox(height: 10),
              ],

              // Top of the screen: DuplicateAlert banner (coral, big icon, plain language) if any
              for (final dup in plan.duplicates) ...[
                SafetyBanner.fromDuplicate(
                  dup,
                  key: Key('today_duplicate_${dup.id}'),
                ),
                const SizedBox(height: 12),
              ],

              // Top of the screen: "Not scheduled: ask your pharmacist" section for unscheduled lines (never hidden)
              if (plan.unscheduled.isNotEmpty) ...[
                _UnscheduledPharmacistSection(
                  unscheduled: plan.unscheduled,
                ),
                const SizedBox(height: 12),
              ],

              // Ramadan Header Switch & Doctor Approval Card
              Consumer(
                builder: (context, ref, _) {
                  final role = ref.watch(userRoleProvider);
                  return _RamadanHeaderCard(
                    ramadan: plan.ramadan,
                    doctorApproved: plan.ramadanDoctorApproved,
                    isCaretaker: role.isCaretaker,
                    onToggleRamadan: (val) {
                      HapticFeedback.selectionClick();
                      ref
                          .read(journeyControllerProvider.notifier)
                          .setRamadanMode(ramadan: val);
                    },
                    onToggleApproved: (val) {
                      HapticFeedback.selectionClick();
                      ref.read(journeyControllerProvider.notifier).setRamadanMode(
                            ramadan: plan.ramadan,
                            doctorApproved: val ?? false,
                          );
                    },
                  );
                },
              ),
              const SizedBox(height: 14),

              // Vertical "Day Arc" Container (sunrise saffron -> midday teal -> night indigo gradient)
              Container(
                key: const Key('today_day_arc_container'),
                padding: const EdgeInsets.all(AppTokens.space2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFFBEB), // Sunrise warm saffron tint
                      Color(0xFFF0FDFA), // Midday calm clinic teal tint
                      Color(0xFFEEF2FF), // Evening/Night soft indigo tint
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                  border: Border.all(color: AppTokens.borderWarm, width: 1.5),
                  boxShadow: AppTokens.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BiText(
                      Bilingual(
                        ur: 'سورج اور چاند کے ساتھ آج کی خوراک کا شیڈول',
                        en: 'Your Meal-Based Daily Timeline',
                      ),
                      isHeadline: true,
                      urduColor: AppTokens.primaryTealDark,
                    ),
                    const SizedBox(height: 16),
                    if (activeSlots.isEmpty)
                      const BiText(
                        Bilingual(
                          ur: 'کوئی شیڈول شدہ خوراک موجود نہیں ہے۔',
                          en: 'No scheduled doses for today.',
                        ),
                      ),
                    for (int sIdx = 0; sIdx < activeSlots.length; sIdx++) ...[
                      _DayArcSlotSection(
                        slot: activeSlots[sIdx],
                        timeLabel:
                            journey.mealTimes.hhmm[activeSlots[sIdx]] ?? '—',
                        isNowSlot: activeSlots[sIdx] == nowSlot ||
                            (sIdx == 0 && !activeSlots.contains(nowSlot)),
                        doses: plan.doses
                            .where((d) => d.slot == activeSlots[sIdx])
                            .toList(),
                        scheduledMedicines: plan.scheduled,
                        journey: journey,
                        reduceMotion: reduceMotion,
                        relationLabelBuilder: _relationLabel,
                        onToggleDose: (medId, slot) {
                          HapticFeedback.mediumImpact();
                          ref
                              .read(journeyControllerProvider.notifier)
                              .toggleDoseTick(medicineId: medId, slot: slot);
                        },
                      ),
                      if (sIdx < activeSlots.length - 1)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 24),
                          child: Container(
                            height: 22,
                            width: 3,
                            color:
                                AppTokens.primaryTeal.withValues(alpha: 0.35),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space2),
              SafetyBanner.prototype(),
              const SizedBox(height: AppTokens.space3),
            ],
          ),
        ),
      ],
    );
  }
}

class _StickyListenPlanBar extends StatelessWidget {
  final bool isSpeaking;
  final bool reduceMotion;
  final VoidCallback onTap;

  const _StickyListenPlanBar({
    required this.isSpeaking,
    required this.reduceMotion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isSpeaking
          ? 'Stop listening to plan. آواز روکیں'
          : 'Listen to my plan in Urdu. میرا شیڈول اردو آواز میں سنیں',
      child: Material(
        color: isSpeaking ? AppTokens.eveningIndigo : AppTokens.primaryTeal,
        borderRadius: BorderRadius.circular(20),
        elevation: 2,
        child: InkWell(
          key: const Key('sticky_listen_plan_bar'),
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppTokens.minTapTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space2,
              vertical: 10,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isSpeaking
                        ? Icons.stop_circle_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BiText(
                    isSpeaking
                        ? const Bilingual(
                            ur: '🔊 آپ کا شیڈول سنایا جا رہا ہے... (روکنے کے لیے ٹیپ کریں)',
                            en: '🔊 Speaking your plan in Urdu... (Tap to stop)',
                          )
                        : const Bilingual(
                            ur: '🔊 میرا شیڈول اردو میں سنیں',
                            en: '🔊 Listen to my plan',
                          ),
                    urduColor: Colors.white,
                    englishColor: Colors.white.withValues(alpha: 0.92),
                    urduWeight: FontWeight.w700,
                    englishWeight: FontWeight.w700,
                  ),
                ),
                if (isSpeaking) ...[
                  const SizedBox(width: 8),
                  _SpeakingWaveform(reduceMotion: reduceMotion),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeakingWaveform extends StatelessWidget {
  final bool reduceMotion;

  const _SpeakingWaveform({required this.reduceMotion});

  @override
  Widget build(BuildContext context) {
    const heights = <double>[14, 26, 18, 28, 16];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(heights.length, (i) {
        final bar = Container(
          width: 4,
          height: heights[i],
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: AppTokens.morningSaffronTint,
            borderRadius: BorderRadius.circular(4),
          ),
        );
        if (reduceMotion) return bar;
        return bar
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleY(
              begin: 0.45,
              end: 1.15,
              delay: Duration(milliseconds: 90 * i),
              duration: const Duration(milliseconds: 360),
            );
      }),
    );
  }
}

class _RamadanHeaderCard extends StatelessWidget {
  final bool ramadan;
  final bool doctorApproved;
  final bool isCaretaker;
  final ValueChanged<bool> onToggleRamadan;
  final ValueChanged<bool?> onToggleApproved;

  const _RamadanHeaderCard({
    required this.ramadan,
    required this.doctorApproved,
    this.isCaretaker = true,
    required this.onToggleRamadan,
    required this.onToggleApproved,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('ramadan_toggle_card'),
      padding: const EdgeInsets.all(AppTokens.space2),
      decoration: BoxDecoration(
        color: ramadan ? AppTokens.eveningIndigoTint : AppTokens.cardCream,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        border: Border.all(
          color: ramadan ? AppTokens.eveningIndigo : AppTokens.borderWarm,
          width: ramadan ? 1.8 : 1.3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ramadan
                      ? Colors.white
                      : AppTokens.eveningIndigoTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.mosque_rounded,
                  color: AppTokens.eveningIndigo,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: BiText(
                  Bilingual(
                    ur: 'رمضان موڈ (سحری اور افطار کے اوقات)',
                    en: 'Ramadan Mode (Suhoor & Iftar timeline)',
                  ),
                  urduWeight: FontWeight.w700,
                  englishWeight: FontWeight.w700,
                ),
              ),
              Semantics(
                label: 'Toggle Ramadan schedule mode',
                child: Switch.adaptive(
                  key: const Key('ramadan_mode_switch'),
                  value: ramadan,
                  activeThumbColor: AppTokens.eveningIndigo,
                  onChanged: onToggleRamadan,
                ),
              ),
            ],
          ),
          if (ramadan) ...[
            const SizedBox(height: 12),
            // Persistent safety banner required by Part 4 #2
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTokens.warningAmberTint,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTokens.warningAmber, width: 1.5),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppTokens.warningAmberDark,
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: BiText(
                      Bilingual(
                        ur: 'تجویز کردہ شیڈول۔ استعمال کرنے سے پہلے اپنے ڈاکٹر سے تصدیق کریں۔',
                        en: 'Suggested layout. Confirm with your doctor before using it.',
                      ),
                      urduColor: AppTokens.warningAmberDark,
                      englishColor: AppTokens.warningAmberDark,
                      urduWeight: FontWeight.w700,
                      englishWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Doctor approval checkbox gate for Ramadan reminders (Caretaker Authority)
            if (isCaretaker)
              InkWell(
                key: const Key('ramadan_doctor_approved_checkbox'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => onToggleApproved(!doctorApproved),
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: AppTokens.minTapTarget,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: doctorApproved
                          ? AppTokens.successGreen
                          : AppTokens.eveningIndigo,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: doctorApproved,
                        activeColor: AppTokens.successGreen,
                        onChanged: onToggleApproved,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: BiText(
                          Bilingual(
                            ur: 'تیماردار/نگران: میرے ڈاکٹر نے اس کی اجازت دی ہے',
                            en: 'Caretaker approval: My doctor approved this layout',
                          ),
                          urduWeight: FontWeight.w700,
                          englishWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: doctorApproved
                      ? AppTokens.successGreenTint
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: doctorApproved
                        ? AppTokens.successGreen
                        : AppTokens.borderWarm,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      doctorApproved
                          ? Icons.check_circle_rounded
                          : Icons.lock_clock_rounded,
                      color: doctorApproved
                          ? AppTokens.successGreenDark
                          : AppTokens.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: BiText(
                        doctorApproved
                            ? const Bilingual(
                                ur: 'نگران نے ڈاکٹر کی منظوری درج کر دی ہے۔',
                                en: 'Caretaker confirmed doctor approval.',
                              )
                            : const Bilingual(
                                ur: 'منظوری درکار ہے: نگران موڈ سے ڈاکٹر کی منظوری حاصل کریں۔',
                                en: 'Approval needed: Ask your caretaker to confirm doctor approval.',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _UnscheduledPharmacistSection extends StatelessWidget {
  final List<MedicineLine> unscheduled;

  const _UnscheduledPharmacistSection({
    required this.unscheduled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('today_unscheduled_section'),
      padding: const EdgeInsets.all(AppTokens.space2),
      decoration: BoxDecoration(
        color: AppTokens.warningAmberTint,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        border: Border.all(color: AppTokens.warningAmber, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.local_pharmacy_rounded,
                  color: AppTokens.warningAmberDark,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BiText(
                  Bilingual(
                    ur: 'شیڈول میں شامل نہیں: اپنے فارماسسٹ سے پوچھیں (${unscheduled.length})',
                    en: 'Not scheduled: ask your pharmacist (${unscheduled.length})',
                  ),
                  isHeadline: true,
                  urduColor: AppTokens.warningAmberDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in unscheduled)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTokens.warningAmber),
              ),
              child: Row(
                children: [
                  PillBadge(item.identityIndex, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BiText(
                      Bilingual(
                        ur: '${item.brandName ?? item.rawText} — لکھائی غیر واضح ہے، فارماسسٹ کو دکھائیں',
                        en: '${item.brandName ?? item.rawText} — Unconfirmed line, verify with your pharmacist',
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
    );
  }
}

class _DayArcSlotSection extends StatelessWidget {
  final MealSlot slot;
  final String timeLabel;
  final bool isNowSlot;
  final List<DoseEvent> doses;
  final List<MedicineLine> scheduledMedicines;
  final JourneyState journey;
  final bool reduceMotion;
  final Bilingual Function(MealRelation) relationLabelBuilder;
  final void Function(String medicineId, MealSlot slot) onToggleDose;

  const _DayArcSlotSection({
    required this.slot,
    required this.timeLabel,
    required this.isNowSlot,
    required this.doses,
    required this.scheduledMedicines,
    required this.journey,
    required this.reduceMotion,
    required this.relationLabelBuilder,
    required this.onToggleDose,
  });

  @override
  Widget build(BuildContext context) {
    final slotLabel = SlotIcon.labelFor(slot);
    final colors = AppTokens.slotColors(slot);

    Widget nowBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTokens.morningSaffron,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, size: 12, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'NOW • ابھی',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );

    if (!reduceMotion && isNowSlot) {
      nowBadge = nowBadge
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(0.96, 0.96),
            end: const Offset(1.04, 1.04),
            duration: const Duration(milliseconds: 700),
          );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Slot Header Row (SlotIcon + Bilingual Slot Name + Time from MealTimes + Animated Now Marker)
        Row(
          children: [
            SlotIcon(slot, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BiText(
                    slotLabel,
                    urduWeight: FontWeight.w700,
                    englishWeight: FontWeight.w700,
                    urduColor: colors.fg,
                  ),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.fg,
                    ),
                  ),
                ],
              ),
            ),
            if (isNowSlot) nowBadge,
          ],
        ),
        const SizedBox(height: 10),

        // DoseCards in this slot
        for (final dose in doses) ...[
          Builder(
            builder: (context) {
              final med = scheduledMedicines
                  .where((m) => m.id == dose.medicineId)
                  .firstOrNull;
              if (med == null) return const SizedBox.shrink();
              final taken = journey.isDoseTaken(med.id, slot);
              final relationText = relationLabelBuilder(dose.relation);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Semantics(
                  button: true,
                  checked: taken,
                  label:
                      '${med.brandName ?? med.rawText} ${med.strength ?? ""}, ${relationText.en}. ${taken ? "Taken" : "Tap to mark taken"}',
                  child: Material(
                    color: taken
                        ? AppTokens.successGreenTint
                        : AppTokens.cardCream,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      key: Key('dose_card_${med.id}_${slot.name}'),
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => onToggleDose(med.id, slot),
                      child: AnimatedContainer(
                        duration: AppTokens.motionFast,
                        constraints: const BoxConstraints(
                          minHeight: AppTokens.heroTapTarget,
                        ),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: taken
                                ? AppTokens.successGreen
                                : AppTokens.borderWarm,
                            width: taken ? 2.0 : 1.4,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            PillBadge(med.identityIndex, size: 52),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  BiText(
                                    Bilingual(
                                      ur: '${med.brandName ?? med.rawText} (${med.strength ?? ""})',
                                      en: '${med.brandName ?? med.rawText} • ${med.strength ?? ""}',
                                    ),
                                    urduWeight: FontWeight.w700,
                                    englishWeight: FontWeight.w700,
                                  ),
                                  if (med.genericName != null &&
                                      med.genericName!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      med.genericName!,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: AppTokens.inkMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  // Relation chip (before / with / after meal)
                                  Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.bg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: colors.accent
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: BiText(
                                        dose.note ?? relationText,
                                        urduSize: 22,
                                        englishSize: 16,
                                        urduColor: colors.fg,
                                        englishColor: colors.fg,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Animated Check / Take Status Badge
                            AnimatedContainer(
                              duration: AppTokens.motionFast,
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: taken
                                    ? AppTokens.successGreen
                                    : AppTokens.surfaceWarm,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: taken
                                      ? AppTokens.successGreenDark
                                      : AppTokens.borderWarm,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                taken
                                    ? Icons.check_rounded
                                    : Icons.touch_app_rounded,
                                color: taken
                                    ? Colors.white
                                    : AppTokens.primaryTealDark,
                                size: 26,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
