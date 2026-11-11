import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/models.dart';
import '../../theme/app_tokens.dart';
import '../../theme/role_controller.dart';
import '../../widgets/widgets.dart';
import '../journey_controller.dart';

/// Part 4 Feature #8: REMINDERS TAB
/// - Meal-time pickers (MealTimes)
/// - Notification permission flow with friendly bilingual explanation
/// - Today's checklist driven by tickLog with tick-off (`PlanRepository.saveTick`)
/// - 7-day strip of completion dots
/// - Custom-painted Adherence Ring (no medical claims)
/// - Schedules via `ReminderService.scheduleForPlan`
class RemindersTab extends ConsumerWidget {
  const RemindersTab({super.key});

  static const List<MealSlot> _editableSlots = [
    MealSlot.wakeUp,
    MealSlot.breakfast,
    MealSlot.lunch,
    MealSlot.dinner,
    MealSlot.bedtime,
    MealSlot.suhoor,
    MealSlot.iftar,
  ];

  Future<void> _pickSlotTime(
    BuildContext context,
    WidgetRef ref,
    MealSlot slot,
    String currentHhmm,
  ) async {
    final parts = currentHhmm.split(':');
    final initialHour = parts.length == 2 ? (int.tryParse(parts[0]) ?? 8) : 8;
    final initialMin = parts.length == 2 ? (int.tryParse(parts[1]) ?? 30) : 30;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMin),
    );
    if (picked != null) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      await ref
          .read(journeyControllerProvider.notifier)
          .updateMealTime(slot, '$hh:$mm');
    }
  }

  List<String> _last7DateKeys() {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      return JourneyState.todayDateKey(day);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(journeyControllerProvider);
    final plan = journey.latestPlan;

    if (plan == null) {
      return const Padding(
        padding: EdgeInsets.all(AppTokens.space2),
        child: EmptyState(
          icon: Icons.notifications_active_rounded,
          title: Bilingual(
            ur: 'یاد دہانی کے لیے پہلے شیڈول بنائیں',
            en: 'Confirm your plan first to set meal reminders',
          ),
          subtitle: Bilingual(
            ur: 'کھانے کے اوقات کے مطابق یاد دہانی اور روزانہ کا ٹک لاگ یہاں نظر آئے گا۔',
            en: 'Meal-time alerts and your 7-day tick-off log will appear here.',
          ),
        ),
      );
    }

    Stream<List<TickEntry>>? tickStream;
    try {
      tickStream = ref.watch(planRepositoryProvider).tickLog(lastDays: 7);
    } catch (_) {}

    return StreamBuilder<List<TickEntry>>(
      stream: tickStream,
      initialData: journey.localTicksByKey.values.toList(),
      builder: (context, snapshot) {
        // Merge repository stream ticks with instantaneous local ticks
        final mergedByComposite = <String, TickEntry>{};
        for (final t in snapshot.data ?? const <TickEntry>[]) {
          mergedByComposite['${t.date}|${t.doseKey}'] = t;
        }
        mergedByComposite.addAll(journey.localTicksByKey);

        final todayKey = JourneyState.todayDateKey();
        final scheduledDoses = plan.doses
            .where((d) => d.slot != MealSlot.whenNeeded)
            .toList();
        final totalToday = scheduledDoses.length;
        int takenToday = 0;
        for (final d in scheduledDoses) {
          final key = '$todayKey|${d.medicineId}|${d.slot.name}';
          if (mergedByComposite[key]?.taken ?? false) {
            takenToday++;
          }
        }
        final ratio =
            totalToday == 0 ? 0.0 : (takenToday / totalToday).clamp(0.0, 1.0);
        final last7Dates = _last7DateKeys();

        return ListView(
          padding: const EdgeInsets.all(AppTokens.space2),
          children: [
            const OfflineBanner(),

            // 1. Adherence Ring + 7-Day Completion Dots Card
            Container(
              key: const Key('reminders_adherence_card'),
              padding: const EdgeInsets.all(AppTokens.space2),
              decoration: BoxDecoration(
                color: AppTokens.cardCream,
                borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                border: Border.all(color: AppTokens.borderWarm, width: 1.5),
                boxShadow: AppTokens.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 88,
                        height: 88,
                        child: CustomPaint(
                          painter: _AdherenceRingPainter(progress: ratio),
                          child: Center(
                            child: Text(
                              '$takenToday/$totalToday',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTokens.primaryTealDark,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const BiText(
                              Bilingual(
                                ur: 'آج کی خوراک کا ریکارڈ',
                                en: "Today's Dose Log",
                              ),
                              isHeadline: true,
                              urduColor: AppTokens.primaryTealDark,
                            ),
                            const SizedBox(height: 4),
                            BiText(
                              Bilingual(
                                ur: 'آج $totalToday میں سے $takenToday خوراک لی جا چکی ہیں۔ (صرف ذاتی یاد دہانی کے لیے)',
                                en: '$takenToday of $totalToday doses ticked today. Personal log only — not a medical assessment.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  const BiText(
                    Bilingual(
                      ur: 'پچھلے ۷ دنوں کا ریکارڈ:',
                      en: 'Last 7 Days Completion Strip:',
                    ),
                    urduWeight: FontWeight.w700,
                    englishWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    runSpacing: 8,
                    children: last7Dates.map((dateStr) {
                      final isToday = dateStr == todayKey;
                      int countForDate = 0;
                      for (final d in scheduledDoses) {
                        if (mergedByComposite[
                                    '$dateStr|${d.medicineId}|${d.slot.name}']
                                ?.taken ??
                            false) {
                          countForDate++;
                        }
                      }
                      final complete =
                          totalToday > 0 && countForDate >= totalToday;
                      final partial = countForDate > 0 && !complete;
                      final shortLabel = dateStr.substring(dateStr.length - 2);

                      return Semantics(
                        label:
                            'Date $dateStr: $countForDate of $totalToday doses taken',
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: complete
                                    ? AppTokens.successGreen
                                    : partial
                                        ? AppTokens.morningSaffronTint
                                        : AppTokens.surfaceWarm,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isToday
                                      ? AppTokens.primaryTeal
                                      : complete
                                          ? AppTokens.successGreenDark
                                          : AppTokens.borderWarm,
                                  width: isToday ? 2.4 : 1.4,
                                ),
                              ),
                              child: Icon(
                                complete
                                    ? Icons.check_rounded
                                    : partial
                                        ? Icons.timelapse_rounded
                                        : Icons.circle_outlined,
                                size: 20,
                                color: complete
                                    ? Colors.white
                                    : partial
                                        ? AppTokens.morningSaffronDark
                                        : AppTokens.inkSubtle,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isToday ? 'Today' : shortLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isToday
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isToday
                                    ? AppTokens.primaryTealDark
                                    : AppTokens.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space2),

            // 2. Notification Permission & Reminder Scheduling Flow
            Container(
              padding: const EdgeInsets.all(AppTokens.space2),
              decoration: BoxDecoration(
                color: journey.remindersEnabled
                    ? AppTokens.primaryTealSurface
                    : AppTokens.cardCream,
                borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                border: Border.all(
                  color: journey.remindersEnabled
                      ? AppTokens.primaryTeal
                      : AppTokens.borderWarm,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BiText(
                    Bilingual(
                      ur: 'فون پر دوا کی یاد دہانی (Notifications)',
                      en: 'Phone Meal-Time Reminders',
                    ),
                    isHeadline: true,
                  ),
                  const SizedBox(height: 6),
                  const BiText(
                    Bilingual(
                      ur: 'کھانے کے وقت فون پر گھنٹی اور اردو پیغام کے ذریعے دوا کی یاد دہانی حاصل کریں۔',
                      en: 'Get gentle local notifications at your chosen meal times so you never miss a dose.',
                    ),
                  ),
                  if (plan.ramadan && !plan.ramadanDoctorApproved) ...[
                    const SizedBox(height: 8),
                    const BiText(
                      Bilingual(
                        ur: 'نوٹ: ڈاکٹر کی منظوری کے ٹک کے بغیر رمضان کے بجائے عام اوقات استعمال ہوں گے۔',
                        en: 'Note: Standard meal times are used for reminders until "My doctor approved this" is checked on Today.',
                      ),
                      urduColor: AppTokens.warningAmberDark,
                      englishColor: AppTokens.warningAmberDark,
                    ),
                  ],
                  const SizedBox(height: 12),
                  BigActionButton(
                    key: const Key('reminders_permission_button'),
                    icon: journey.remindersEnabled
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    isPrimary: !journey.remindersEnabled,
                    label: journey.remindersEnabled
                        ? const Bilingual(
                            ur: 'یاد دہانی فعال ہے (دوبارہ ترتیب دیں)',
                            en: 'Reminders Active (Tap to refresh schedule)',
                          )
                        : const Bilingual(
                            ur: 'یاد دہانی کی اجازت دیں اور وقت مقرر کریں',
                            en: 'Enable Notifications & Schedule Reminders',
                          ),
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await ref
                          .read(journeyControllerProvider.notifier)
                          .enableAndScheduleReminders();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space2),

            // 3. Today's Checklist with Tick-Off
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
                  const BiText(
                    Bilingual(
                      ur: 'آج کی خوراک پر نشان لگائیں (ٹک لاگ):',
                      en: "Today's Dose Checklist (Tap to tick off):",
                    ),
                    isHeadline: true,
                  ),
                  const SizedBox(height: 12),
                  for (final dose in scheduledDoses) ...[
                    Builder(
                      builder: (context) {
                        final med = plan.scheduled
                            .where((m) => m.id == dose.medicineId)
                            .firstOrNull;
                        if (med == null) return const SizedBox.shrink();
                        final key =
                            '$todayKey|${med.id}|${dose.slot.name}';
                        final taken = mergedByComposite[key]?.taken ?? false;
                        final slotLabel = SlotIcon.labelFor(dose.slot);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            key: Key(
                              'reminder_tick_${med.id}_${dose.slot.name}',
                            ),
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              ref
                                  .read(journeyControllerProvider.notifier)
                                  .toggleDoseTick(
                                    medicineId: med.id,
                                    slot: dose.slot,
                                  );
                            },
                            child: Container(
                              constraints: const BoxConstraints(
                                minHeight: AppTokens.minTapTarget,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: taken
                                    ? AppTokens.successGreenTint
                                    : AppTokens.surfaceWarm,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: taken
                                      ? AppTokens.successGreen
                                      : AppTokens.borderWarm,
                                ),
                              ),
                              child: Row(
                                children: [
                                  PillBadge(med.identityIndex, size: 44),
                                  const SizedBox(width: 10),
                                  SlotIcon(dose.slot, size: 40),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: BiText(
                                      Bilingual(
                                        ur: '${med.brandName ?? med.rawText} — ${slotLabel.ur}',
                                        en: '${med.brandName ?? med.rawText} (${slotLabel.en})',
                                      ),
                                      urduWeight: FontWeight.w700,
                                      englishWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Checkbox(
                                    value: taken,
                                    activeColor: AppTokens.successGreen,
                                    onChanged: (_) {
                                      HapticFeedback.mediumImpact();
                                      ref
                                          .read(
                                            journeyControllerProvider.notifier,
                                          )
                                          .toggleDoseTick(
                                            medicineId: med.id,
                                            slot: dose.slot,
                                          );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space2),

            // 4. Meal-Time Pickers (MealTimes) - Caretaker Authority
            Consumer(
              builder: (context, ref, _) {
                final role = ref.watch(userRoleProvider);
                return Container(
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
                          Expanded(
                            child: BiText(
                              role.isCaretaker
                                  ? const Bilingual(
                                      ur: 'کھانے کے اوقات تبدیل کریں (نگران کا اختیار):',
                                      en: 'Customize Meal Times (Caretaker Authority):',
                                    )
                                  : const Bilingual(
                                      ur: 'کھانے کے اوقات (نگران کے طے کردہ):',
                                      en: 'Configured Meal Times (Read Only):',
                                    ),
                              isHeadline: true,
                            ),
                          ),
                          if (!role.isCaretaker)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTokens.accentAmber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'محفوظ شدہ • Locked',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTokens.accentAmberDark,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final slot in _editableSlots) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            key: Key('meal_time_picker_${slot.name}'),
                            borderRadius: BorderRadius.circular(16),
                            onTap: role.isCaretaker
                                ? () => _pickSlotTime(
                                      context,
                                      ref,
                                      slot,
                                      journey.mealTimes.hhmm[slot] ?? '08:30',
                                    )
                                : null,
                            child: Container(
                              constraints: const BoxConstraints(
                                minHeight: AppTokens.minTapTarget,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTokens.surfaceWarm,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTokens.borderWarm),
                              ),
                              child: Row(
                                children: [
                                  SlotIcon(slot, size: 42),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: BiText(SlotIcon.labelFor(slot)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppTokens.primaryTeal,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.access_time_rounded,
                                          size: 18,
                                          color: AppTokens.primaryTealDark,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          journey.mealTimes.hhmm[slot] ?? '—',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: AppTokens.primaryTealDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (role.isCaretaker) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.edit_rounded,
                                      size: 18,
                                      color: AppTokens.primaryTeal,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppTokens.space2),
            SafetyBanner.prototype(),
          ],
        );
      },
    );
  }
}

class _AdherenceRingPainter extends CustomPainter {
  final double progress;

  const _AdherenceRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = (Offset.zero & size).center;
    final radius = (math.min(size.width, size.height) / 2) - 6;

    final trackPaint = Paint()
      ..color = AppTokens.surfaceWarm
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = AppTokens.successGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AdherenceRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
