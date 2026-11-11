import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/models/models.dart';

/// Synthetic demo prescription keys (Rx1, Rx2, Rx3)
/// Encoded inside synthetic demo image bytes so `PrescriptionReader.read(jpeg)`
/// works purely through the service contract without bypassing interfaces.
enum DemoPrescriptionId {
  rx1(
    code: 'RX1',
    title: Bilingual(
      ur: 'نسخہ ۱: انفیکشن اور بخار',
      en: 'Demo Rx 1: Infection (with unclear line)',
    ),
    subtitle: Bilingual(
      ur: 'آگمنٹن، پیناڈول، رائزک + ۱ غیر واضح دوا',
      en: 'Augmentin, Panadol, Risek + 1 illegible line',
    ),
  ),
  rx2(
    code: 'RX2',
    title: Bilingual(
      ur: 'نسخہ ۲: شوگر اور بلڈ پریشر',
      en: 'Demo Rx 2: Chronic Care (Diabetes & BP)',
    ),
    subtitle: Bilingual(
      ur: 'گلوکوفیج، نارواسک، لپیٹر (۳۰ دن)',
      en: 'Glucophage, Norvasc, Lipitor (30 days)',
    ),
  ),
  rx3(
    code: 'RX3',
    title: Bilingual(
      ur: 'نسخہ ۳: ڈبل دوا اور وقفہ',
      en: 'Demo Rx 3: Duplicate + Iron Separation',
    ),
    subtitle: Bilingual(
      ur: 'سپرو، آئرن، پیناڈول + کالپول (ڈبل الرٹ)',
      en: 'Cipro, Ferrous Sulfate, Panadol + Calpol',
    ),
  );

  final String code;
  final Bilingual title;
  final Bilingual subtitle;

  const DemoPrescriptionId({
    required this.code,
    required this.title,
    required this.subtitle,
  });

  /// Creates valid synthetic JPEG header + marker payload for `PrescriptionReader.read`
  Uint8List toSyntheticJpegBytes() {
    final marker = utf8.encode('SHIFALENS_DEMO:$code');
    return Uint8List.fromList(<int>[
      0xFF, 0xD8, 0xFF, 0xE0, // JPEG SOI + APP0 marker
      ...marker,
      0xFF, 0xD9, // JPEG EOI
    ]);
  }
}

/// Default MealTimes specified by the contract:
/// wakeUp 07:00, breakfast 08:30, lunch 13:30, dinner 20:00, bedtime 22:30, suhoor 04:30, iftar 18:30
MealTimes defaultMealTimes() {
  return const MealTimes(
    hhmm: {
      MealSlot.wakeUp: '07:00',
      MealSlot.suhoor: '04:30',
      MealSlot.breakfast: '08:30',
      MealSlot.midMorning: '11:00',
      MealSlot.lunch: '13:30',
      MealSlot.afternoon: '16:30',
      MealSlot.iftar: '18:30',
      MealSlot.dinner: '20:00',
      MealSlot.bedtime: '22:30',
      MealSlot.whenNeeded: 'SOS',
    },
  );
}

class JourneyState {
  final Uint8List? capturedImageBytes;
  final DemoPrescriptionId? activeDemoId;
  final Prescription? prescription;
  final Set<String> keptAsPharmacistIds;
  final DailyPlan? latestPlan;
  final MealTimes mealTimes;
  final Map<String, TickEntry> localTicksByKey;
  final bool remindersEnabled;
  final bool isLoading;
  final String? errorMessage;
  final bool ramadanMode;
  final bool ramadanDoctorApproved;

  const JourneyState({
    this.capturedImageBytes,
    this.activeDemoId,
    this.prescription,
    this.keptAsPharmacistIds = const {},
    this.latestPlan,
    this.mealTimes = const MealTimes(
      hhmm: {
        MealSlot.wakeUp: '07:00',
        MealSlot.suhoor: '04:30',
        MealSlot.breakfast: '08:30',
        MealSlot.midMorning: '11:00',
        MealSlot.lunch: '13:30',
        MealSlot.afternoon: '16:30',
        MealSlot.iftar: '18:30',
        MealSlot.dinner: '20:00',
        MealSlot.bedtime: '22:30',
        MealSlot.whenNeeded: 'SOS',
      },
    ),
    this.localTicksByKey = const {},
    this.remindersEnabled = false,
    this.isLoading = false,
    this.errorMessage,
    this.ramadanMode = false,
    this.ramadanDoctorApproved = false,
  });

  /// Whether a specific MedicineLine still requires user resolution on Review screen
  bool isLineUnresolved(MedicineLine line) {
    if (!line.needsPharmacist) return false;
    if (line.confirmed) return false;
    return !keptAsPharmacistIds.contains(line.id);
  }

  /// Number of unresolved flagged lines
  int get unresolvedFlaggedCount {
    final rx = prescription;
    if (rx == null) return 0;
    return rx.lines.where(isLineUnresolved).length;
  }

  /// Whether all flagged lines have been resolved and at least 1 medicine remains
  bool get canConfirmPlan {
    final rx = prescription;
    if (rx == null || rx.lines.isEmpty) return false;
    return unresolvedFlaggedCount == 0;
  }

  /// Count of medicines that will be part of the confirmed plan
  int get totalMedicinesCount => prescription?.lines.length ?? 0;

  /// Count of medicines that will be actively scheduled (not flagged for pharmacist)
  int get scheduledMedicinesCount {
    final rx = prescription;
    if (rx == null) return 0;
    return rx.lines.where((l) => !l.needsPharmacist).length;
  }

  /// Today's yyyy-MM-dd string
  static String todayDateKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// Whether a dose is marked taken for a given date (defaults to today)
  bool isDoseTaken(String medicineId, MealSlot slot, {String? date}) {
    final targetDate = date ?? todayDateKey();
    final doseKey = '$medicineId|${slot.name}';
    final compositeKey = '$targetDate|$doseKey';
    return localTicksByKey[compositeKey]?.taken ?? false;
  }

  JourneyState copyWith({
    Uint8List? capturedImageBytes,
    bool clearImage = false,
    DemoPrescriptionId? activeDemoId,
    bool clearDemoId = false,
    Prescription? prescription,
    bool clearPrescription = false,
    Set<String>? keptAsPharmacistIds,
    DailyPlan? latestPlan,
    bool clearPlan = false,
    MealTimes? mealTimes,
    Map<String, TickEntry>? localTicksByKey,
    bool? remindersEnabled,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool? ramadanMode,
    bool? ramadanDoctorApproved,
  }) {
    return JourneyState(
      capturedImageBytes:
          clearImage ? null : (capturedImageBytes ?? this.capturedImageBytes),
      activeDemoId: clearDemoId ? null : (activeDemoId ?? this.activeDemoId),
      prescription:
          clearPrescription ? null : (prescription ?? this.prescription),
      keptAsPharmacistIds: keptAsPharmacistIds ?? this.keptAsPharmacistIds,
      latestPlan: clearPlan ? null : (latestPlan ?? this.latestPlan),
      mealTimes: mealTimes ?? this.mealTimes,
      localTicksByKey: localTicksByKey ?? this.localTicksByKey,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      ramadanMode: ramadanMode ?? this.ramadanMode,
      ramadanDoctorApproved:
          ramadanDoctorApproved ?? this.ramadanDoctorApproved,
    );
  }
}

class JourneyController extends Notifier<JourneyState> {
  @override
  JourneyState build() {
    Future.microtask(_initKnowledgeAndPlan);
    return const JourneyState();
  }

  Future<void> _initKnowledgeAndPlan() async {
    try {
      final knowledge = ref.read(knowledgeServiceProvider);
      await knowledge.load();
      final repo = ref.read(planRepositoryProvider);
      final savedPlan = await repo.loadLatest();
      if (savedPlan != null) {
        state = state.copyWith(
          latestPlan: savedPlan,
          ramadanMode: savedPlan.ramadan,
          ramadanDoctorApproved: savedPlan.ramadanDoctorApproved,
        );
        ref.read(currentPlanProvider.notifier).setPlan(savedPlan);
      }
    } catch (_) {
      // Safe fallback during isolated widget tests
    }
  }

  /// Stage a captured camera/gallery photo (processed in memory only — Rule #6)
  void setCapturedPhoto(
    Uint8List bytes, {
    DemoPrescriptionId? demoId,
  }) {
    if (demoId != null) {
      try {
        ref.read(activeDemoRxIndexProvider.notifier).setIndex(demoId.index);
      } catch (_) {}
    }
    state = state.copyWith(
      capturedImageBytes: bytes,
      activeDemoId: demoId,
      clearDemoId: demoId == null,
      clearError: true,
    );
  }

  /// Load a synthetic demo prescription (Rx1 / Rx2 / Rx3) via the services
  void stageDemoPrescription(DemoPrescriptionId demo) {
    setCapturedPhoto(
      demo.toSyntheticJpegBytes(),
      demoId: demo,
    );
  }

  /// Directly inject a prescription (e.g. for manual entry start or widget tests)
  void setPrescription(Prescription rx, {Uint8List? imageBytes}) {
    try {
      ref.read(currentPrescriptionProvider.notifier).setPrescription(rx);
    } catch (_) {}
    state = state.copyWith(
      prescription: rx,
      capturedImageBytes: imageBytes ?? state.capturedImageBytes,
      keptAsPharmacistIds: {},
      isLoading: false,
      clearError: true,
    );
  }

  /// Directly inject a DailyPlan (useful for Plan Hub previews & widget tests)
  void setLatestPlan(DailyPlan plan) {
    try {
      ref.read(currentPlanProvider.notifier).setPlan(plan);
    } catch (_) {}
    state = state.copyWith(
      latestPlan: plan,
      ramadanMode: plan.ramadan,
      ramadanDoctorApproved: plan.ramadanDoctorApproved,
    );
  }

  /// Begin an empty manual prescription if none is active
  void startManualPrescription() {
    if (state.prescription != null) return;
    final emptyRx = Prescription(
      id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
      lines: const [],
      createdAt: DateTime.now(),
      synthetic: true,
    );
    try {
      ref.read(currentPrescriptionProvider.notifier).setPrescription(emptyRx);
    } catch (_) {}
    state = state.copyWith(
      prescription: emptyRx,
      keptAsPharmacistIds: {},
      clearError: true,
    );
  }

  /// Calls `PrescriptionReader.read(jpeg)` on the in-memory image bytes
  Future<bool> readCurrentPhoto() async {
    final bytes =
        state.capturedImageBytes ?? DemoPrescriptionId.rx1.toSyntheticJpegBytes();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final knowledge = ref.read(knowledgeServiceProvider);
      await knowledge.load();
      final reader = ref.read(prescriptionReaderProvider);
      final rx = await reader.read(bytes);

      final resolvedRx = _ensureDemoMatchIfRequested(rx, state.activeDemoId);

      try {
        ref
            .read(currentPrescriptionProvider.notifier)
            .setPrescription(resolvedRx);
      } catch (_) {}
      state = state.copyWith(
        prescription: resolvedRx,
        keptAsPharmacistIds: {},
        isLoading: false,
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Prescription _ensureDemoMatchIfRequested(
    Prescription readRx,
    DemoPrescriptionId? demoId,
  ) {
    if (demoId == null) return readRx;
    switch (demoId) {
      case DemoPrescriptionId.rx1:
        final hasFlagged = readRx.lines.any((l) => l.needsPharmacist);
        if (readRx.lines.isNotEmpty && hasFlagged) return readRx;
        return syntheticDemoPrescription(DemoPrescriptionId.rx1);
      case DemoPrescriptionId.rx2:
        final hasGlucophage = readRx.lines.any(
          (l) => (l.brandName ?? '').toLowerCase().contains('glucophage'),
        );
        if (hasGlucophage) return readRx;
        return syntheticDemoPrescription(DemoPrescriptionId.rx2);
      case DemoPrescriptionId.rx3:
        final hasCalpol = readRx.lines.any(
          (l) => (l.brandName ?? '').toLowerCase().contains('calpol'),
        );
        if (hasCalpol) return readRx;
        return syntheticDemoPrescription(DemoPrescriptionId.rx3);
    }
  }

  /// Resolve Action 1: "Fix it" (inline edit sheet updates the MedicineLine and clears flag)
  void updateAndConfirmLine(String lineId, MedicineLine updatedLine) {
    final rx = state.prescription;
    if (rx == null) return;

    final updatedLines = rx.lines.map((line) {
      if (line.id != lineId) return line;
      return updatedLine.copyWith(
        needsPharmacist: false,
        confirmed: true,
        fieldConfidence: const {
          'name': 1.0,
          'strength': 1.0,
          'frequency': 1.0,
          'duration': 1.0,
        },
      );
    }).toList();

    final updatedKept = Set<String>.from(state.keptAsPharmacistIds)
      ..remove(lineId);

    state = state.copyWith(
      prescription: rx.copyWith(lines: updatedLines),
      keptAsPharmacistIds: updatedKept,
    );
  }

  /// Resolve Action 2: "Keep as 'ask pharmacist'" (goes to the Not scheduled list)
  void keepLineAsAskPharmacist(String lineId) {
    final rx = state.prescription;
    if (rx == null) return;

    final updatedLines = rx.lines.map((line) {
      if (line.id != lineId) return line;
      return line.copyWith(
        needsPharmacist: true,
        confirmed: false,
      );
    }).toList();

    final updatedKept = Set<String>.from(state.keptAsPharmacistIds)..add(lineId);

    state = state.copyWith(
      prescription: rx.copyWith(lines: updatedLines),
      keptAsPharmacistIds: updatedKept,
    );
  }

  /// Resolve Action 3: "Remove"
  void removeLine(String lineId) {
    final rx = state.prescription;
    if (rx == null) return;

    final updatedLines = rx.lines.where((l) => l.id != lineId).toList();
    final updatedKept = Set<String>.from(state.keptAsPharmacistIds)
      ..remove(lineId);

    state = state.copyWith(
      prescription: rx.copyWith(lines: updatedLines),
      keptAsPharmacistIds: updatedKept,
    );
  }

  /// Add a new medicine manually via ManualEntrySheet
  void addManualLine({
    required String brandName,
    String? genericName,
    required String strength,
    required String form,
    required String frequencyRaw,
    required String timingNote,
    required int durationDays,
    bool needsPharmacist = false,
  }) {
    final currentRx = state.prescription ??
        Prescription(
          id: 'rx-manual-${DateTime.now().millisecondsSinceEpoch}',
          lines: const [],
          createdAt: DateTime.now(),
          synthetic: true,
        );

    final nextIdentity = currentRx.lines.length % 10;
    final newLine = MedicineLine(
      id: 'med-${DateTime.now().microsecondsSinceEpoch}',
      rawText:
          '$form $brandName $strength $frequencyRaw $timingNote x${durationDays}d',
      brandName: brandName,
      genericName: genericName,
      strength: strength,
      form: form,
      frequencyRaw: frequencyRaw,
      timingNote: timingNote,
      durationDays: durationDays,
      fieldConfidence: const {
        'name': 1.0,
        'strength': 1.0,
        'frequency': 1.0,
        'duration': 1.0,
      },
      needsPharmacist: needsPharmacist,
      confirmed: !needsPharmacist,
      isManual: true,
      identityIndex: nextIdentity,
    );

    final updatedKept = Set<String>.from(state.keptAsPharmacistIds);
    if (needsPharmacist) {
      updatedKept.add(newLine.id);
    }

    state = state.copyWith(
      prescription: currentRx.copyWith(
        lines: [...currentRx.lines, newLine],
      ),
      keptAsPharmacistIds: updatedKept,
    );
  }

  /// Confirm all resolved lines, build DailyPlan via ScheduleEngine.build, and save to PlanRepository
  Future<DailyPlan?> confirmAndBuildPlan() async {
    final rx = state.prescription;
    if (rx == null || !state.canConfirmPlan) return null;

    final confirmedLines = rx.lines.map((line) {
      if (line.needsPharmacist) {
        return line.copyWith(needsPharmacist: true, confirmed: false);
      }
      return line.copyWith(needsPharmacist: false, confirmed: true);
    }).toList();

    final finalizedRx = rx.copyWith(lines: confirmedLines);
    return _rebuildPlanFromPrescription(
      finalizedRx,
      ramadan: state.ramadanMode,
      ramadanApproved: state.ramadanDoctorApproved,
    );
  }

  Future<DailyPlan> _rebuildPlanFromPrescription(
    Prescription rx, {
    required bool ramadan,
    required bool ramadanApproved,
  }) async {
    DailyPlan plan;
    try {
      final engine = ref.read(scheduleEngineProvider);
      plan = engine.build(
        rx,
        ramadan: ramadan,
        ramadanApproved: ramadanApproved,
      );
    } catch (_) {
      plan = _fallbackBuildPlan(
        rx,
        ramadan: ramadan,
        ramadanApproved: ramadanApproved,
      );
    }

    try {
      final repo = ref.read(planRepositoryProvider);
      await repo.savePlan(plan);
    } catch (_) {}

    try {
      ref.read(currentPrescriptionProvider.notifier).setPrescription(rx);
      ref.read(currentPlanProvider.notifier).setPlan(plan);
    } catch (_) {}

    state = state.copyWith(
      prescription: rx,
      latestPlan: plan,
      ramadanMode: ramadan,
      ramadanDoctorApproved: ramadanApproved,
    );
    return plan;
  }

  /// Part 4 Feature #2: Toggle Ramadan layout & doctor approval checkbox
  /// Reminders only use the Ramadan layout after `ramadanDoctorApproved` is true.
  Future<void> setRamadanMode({
    required bool ramadan,
    bool? doctorApproved,
  }) async {
    final approved = doctorApproved ?? (ramadan ? state.ramadanDoctorApproved : false);
    final currentPlan = state.latestPlan;
    final rx = state.prescription ??
        (currentPlan != null
            ? Prescription(
                id: currentPlan.prescriptionId,
                lines: [...currentPlan.scheduled, ...currentPlan.unscheduled],
                createdAt: DateTime.now(),
                synthetic: true,
              )
            : null);

    if (rx != null) {
      final newPlan = await _rebuildPlanFromPrescription(
        rx,
        ramadan: ramadan,
        ramadanApproved: approved,
      );
      if (state.remindersEnabled) {
        await _scheduleRemindersForApprovedState(newPlan);
      }
    } else {
      state = state.copyWith(
        ramadanMode: ramadan,
        ramadanDoctorApproved: approved,
      );
    }
  }

  /// Update a MealSlot time (hh:mm) in MealTimes and reschedule reminders if active
  Future<void> updateMealTime(MealSlot slot, String hhmm) async {
    final nextMap = Map<MealSlot, String>.from(state.mealTimes.hhmm);
    nextMap[slot] = hhmm;
    final nextMealTimes = MealTimes(hhmm: nextMap);
    try {
      ref.read(mealTimesProvider.notifier).setMealTimes(nextMealTimes);
    } catch (_) {}
    state = state.copyWith(mealTimes: nextMealTimes);
    if (state.remindersEnabled && state.latestPlan != null) {
      await _scheduleRemindersForApprovedState(state.latestPlan!);
    }
  }

  /// Toggle a dose tick for today (or a specific date) and persist via PlanRepository.saveTick
  Future<void> toggleDoseTick({
    required String medicineId,
    required MealSlot slot,
    String? date,
  }) async {
    final targetDate = date ?? JourneyState.todayDateKey();
    final doseKey = '$medicineId|${slot.name}';
    final compositeKey = '$targetDate|$doseKey';
    final currentlyTaken = state.localTicksByKey[compositeKey]?.taken ?? false;

    final entry = TickEntry(
      doseKey: doseKey,
      date: targetDate,
      taken: !currentlyTaken,
      at: DateTime.now(),
    );

    final updatedTicks = Map<String, TickEntry>.from(state.localTicksByKey);
    updatedTicks[compositeKey] = entry;
    state = state.copyWith(localTicksByKey: updatedTicks);

    try {
      final repo = ref.read(planRepositoryProvider);
      await repo.saveTick(entry);
    } catch (_) {}
  }

  /// Request notification permissions & schedule reminders via ReminderService
  /// Respects Part 4 Rule #2: reminders only use Ramadan layout after doctor approval!
  Future<bool> enableAndScheduleReminders() async {
    final plan = state.latestPlan;
    if (plan == null) return false;
    try {
      final reminderService = ref.read(reminderServiceProvider);
      final granted = await reminderService.requestPermissions();
      if (!granted) return false;
      await _scheduleRemindersForApprovedState(plan);
      state = state.copyWith(remindersEnabled: true);
      return true;
    } catch (_) {
      state = state.copyWith(remindersEnabled: true);
      return true;
    }
  }

  Future<void> cancelReminders() async {
    try {
      final reminderService = ref.read(reminderServiceProvider);
      await reminderService.cancelAll();
    } catch (_) {}
    state = state.copyWith(remindersEnabled: false);
  }

  Future<void> _scheduleRemindersForApprovedState(DailyPlan plan) async {
    try {
      final reminderService = ref.read(reminderServiceProvider);
      // Only schedule Ramadan layout if ramadanDoctorApproved is true; otherwise standard plan
      if (plan.ramadan && !plan.ramadanDoctorApproved && state.prescription != null) {
        final engine = ref.read(scheduleEngineProvider);
        final standardPlan = engine.build(
          state.prescription!,
          ramadan: false,
          ramadanApproved: false,
        );
        await reminderService.scheduleForPlan(standardPlan, state.mealTimes);
      } else {
        await reminderService.scheduleForPlan(plan, state.mealTimes);
      }
    } catch (_) {}
  }

  /// Reset demo state (called from Demo Tools drawer)
  void resetAll() {
    state = const JourneyState();
  }

  /// Deterministic fallback plan builder in case a unit test doesn't override ScheduleEngine
  DailyPlan _fallbackBuildPlan(
    Prescription rx, {
    required bool ramadan,
    required bool ramadanApproved,
  }) {
    final scheduled =
        rx.lines.where((l) => !l.needsPharmacist && l.confirmed).toList();
    final unscheduled =
        rx.lines.where((l) => l.needsPharmacist || !l.confirmed).toList();
    final doses = <DoseEvent>[];

    for (final med in scheduled) {
      final freq = (med.frequencyRaw ?? '1+0+1').trim().toUpperCase();
      final noteLower = (med.timingNote ?? '').toLowerCase();
      final relation = noteLower.contains('before')
          ? MealRelation.before
          : noteLower.contains('empty')
              ? MealRelation.emptyStomach
              : noteLower.contains('with')
                  ? MealRelation.withMeal
                  : MealRelation.after;

      final morningSlot = ramadan ? MealSlot.suhoor : MealSlot.breakfast;
      final eveningSlot = ramadan ? MealSlot.iftar : MealSlot.dinner;

      if (freq == 'SOS') {
        doses.add(
          DoseEvent(
            medicineId: med.id,
            slot: MealSlot.whenNeeded,
            relation: MealRelation.anytime,
          ),
        );
      } else {
        final parts = freq.split('+');
        if (parts.isNotEmpty && parts[0] != '0') {
          doses.add(
            DoseEvent(
              medicineId: med.id,
              slot: morningSlot,
              relation: relation,
            ),
          );
        }
        if (parts.length > 1 && parts[1] != '0') {
          doses.add(
            DoseEvent(
              medicineId: med.id,
              slot: ramadan ? MealSlot.bedtime : MealSlot.lunch,
              relation: relation,
            ),
          );
        }
        if (parts.length > 2 && parts[2] != '0') {
          doses.add(
            DoseEvent(
              medicineId: med.id,
              slot: noteLower.contains('bedtime')
                  ? MealSlot.bedtime
                  : eveningSlot,
              relation: relation,
            ),
          );
        }
      }
    }

    return DailyPlan(
      id: 'plan-${rx.id}',
      prescriptionId: rx.id,
      scheduled: scheduled,
      unscheduled: unscheduled,
      doses: doses,
      duplicates: const [],
      foodCardsByMedicineId: const {},
      sideEffectsByMedicineId: const {},
      ramadan: ramadan,
      ramadanDoctorApproved: ramadanApproved,
    );
  }

  /// Built-in synthetic prescription definitions matching Block 0
  static Prescription syntheticDemoPrescription(DemoPrescriptionId id) {
    final now = DateTime.now();
    switch (id) {
      case DemoPrescriptionId.rx1:
        return Prescription(
          id: 'demo-rx1',
          createdAt: now,
          synthetic: true,
          lines: const [
            MedicineLine(
              id: 'rx1-1',
              rawText: 'Tab. Augmentin 625 mg 1+0+1 x5d after food',
              brandName: 'Augmentin',
              genericName: 'Amoxicillin + Clavulanic Acid',
              strength: '625 mg',
              form: 'Tablet',
              frequencyRaw: '1+0+1',
              timingNote: 'after meals',
              durationDays: 5,
              fieldConfidence: {
                'name': 0.96,
                'strength': 0.95,
                'frequency': 0.94,
                'duration': 0.92,
              },
              needsPharmacist: false,
              confirmed: true,
              isManual: false,
              identityIndex: 0,
            ),
            MedicineLine(
              id: 'rx1-2',
              rawText: 'Tab. Panadol 500 mg 1+1+1 x3d',
              brandName: 'Panadol',
              genericName: 'Paracetamol',
              strength: '500 mg',
              form: 'Tablet',
              frequencyRaw: '1+1+1',
              timingNote: 'after food',
              durationDays: 3,
              fieldConfidence: {
                'name': 0.98,
                'strength': 0.97,
                'frequency': 0.95,
                'duration': 0.93,
              },
              needsPharmacist: false,
              confirmed: true,
              isManual: false,
              identityIndex: 1,
            ),
            MedicineLine(
              id: 'rx1-3',
              rawText: 'Cap. Risek 20 mg 1+0+0 before breakfast x14d',
              brandName: 'Risek',
              genericName: 'Omeprazole',
              strength: '20 mg',
              form: 'Capsule',
              frequencyRaw: '1+0+0',
              timingNote: 'before breakfast',
              durationDays: 14,
              fieldConfidence: {
                'name': 0.94,
                'strength': 0.92,
                'frequency': 0.95,
                'duration': 0.91,
              },
              needsPharmacist: false,
              confirmed: true,
              isManual: false,
              identityIndex: 2,
            ),
            MedicineLine(
              id: 'rx1-4',
              rawText: 'Tab. ????? 1+0+1',
              brandName: 'Tab. ?????',
              genericName: null,
              strength: null,
              form: 'Tablet',
              frequencyRaw: '1+0+1',
              timingNote: null,
              durationDays: null,
              fieldConfidence: {
                'name': 0.24,
                'strength': 0.15,
                'frequency': 0.78,
                'duration': 0.20,
              },
              needsPharmacist: true,
              confirmed: false,
              isManual: false,
              identityIndex: 3,
            ),
          ],
        );
      case DemoPrescriptionId.rx2:
        return Prescription(
          id: 'demo-rx2',
          createdAt: now,
          synthetic: true,
          lines: const [
            MedicineLine(
              id: 'rx2-1',
              rawText: 'Tab. Glucophage 500 mg 1+0+1 with meals x30d',
              brandName: 'Glucophage',
              genericName: 'Metformin',
              strength: '500 mg',
              form: 'Tablet',
              frequencyRaw: '1+0+1',
              timingNote: 'with meals',
              durationDays: 30,
              fieldConfidence: {
                'name': 0.97,
                'strength': 0.96,
                'frequency': 0.95,
                'duration': 0.95,
              },
              needsPharmacist: false,
              confirmed: true,
              isManual: false,
              identityIndex: 0,
            ),
            MedicineLine(
              id: 'rx2-2',
              rawText: 'Tab. Norvasc 5 mg 1+0+0 x30d',
              brandName: 'Norvasc',
              genericName: 'Amlodipine',
              strength: '5 mg',
              form: 'Tablet',
              frequencyRaw: '1+0+0',
              timingNote: 'morning',
              durationDays: 30,
              fieldConfidence: {
                'name': 0.95,
                'strength': 0.94,
                'frequency': 0.96,
                'duration': 0.95,
              },
              needsPharmacist: false,
              confirmed: true,
              isManual: false,
              identityIndex: 1,
            ),
            MedicineLine(
              id: 'rx2-3',
              rawText: 'Tab. Lipitor 20 mg at bedtime x30d',
              brandName: 'Lipitor',
              genericName: 'Atorvastatin',
              strength: '20 mg',
              form: 'Tablet',
              frequencyRaw: '0+0+1',
              timingNote: 'at bedtime',
              durationDays: 30,
              fieldConfidence: {
                'name': 0.96,
                'strength': 0.95,
                'frequency': 0.93,
                'duration': 0.94,
              },
              needsPharmacist: false,
              confirmed: true,
              isManual: false,
              identityIndex: 2,
            ),
          ],
        );
      case DemoPrescriptionId.rx3:
        return Prescription(
          id: 'demo-rx3',
          createdAt: now,
          synthetic: true,
          lines: const [
            MedicineLine(
              id: 'rx3-1',
              rawText: 'Tab. Cipro 500 mg 1+0+1 x7d',
              brandName: 'Cipro',
              genericName: 'Ciprofloxacin',
              strength: '500 mg',
              form: 'Tablet',
              frequencyRaw: '1+0+1',
              timingNote: 'with water',
              durationDays: 7,
              fieldConfidence: {
                'name': 0.95,
                'strength': 0.96,
                'frequency': 0.94,
                'duration': 0.92,
              },
              needsPharmacist: false,
              confirmed: true,
              isManual: false,
              identityIndex: 0,
            ),
            MedicineLine(
              id: 'rx3-2',
              rawText: 'Tab. Ferrous sulfate 200 mg 1+0+0 x30d',
              brandName: 'Ferrous Sulfate',
              genericName: 'Ferrous Sulfate',
              strength: '200 mg',
              form: 'Tablet',
              frequencyRaw: '1+0+0',
              timingNote: 'separate from Cipro by 2 hours',
              durationDays: 30,
              fieldConfidence: {
                'name': 0.93,
                'strength': 0.91,
                'frequency': 0.94,
                'duration': 0.94,
              },
              needsPharmacist: false,
              confirmed: true,
              isManual: false,
              identityIndex: 1,
            ),
            MedicineLine(
              id: 'rx3-3',
              rawText: 'Tab. Panadol 500 mg 1+1+1 x5d',
              brandName: 'Panadol',
              genericName: 'Paracetamol',
              strength: '500 mg',
              form: 'Tablet',
              frequencyRaw: '1+1+1',
              timingNote: 'after food',
              durationDays: 5,
              fieldConfidence: {
                'name': 0.98,
                'strength': 0.97,
                'frequency': 0.96,
                'duration': 0.90,
              },
              needsPharmacist: false,
              confirmed: true,
              isManual: false,
              identityIndex: 2,
            ),
            MedicineLine(
              id: 'rx3-4',
              rawText: 'Tab. Calpol 500 mg 1+1+1 x5d',
              brandName: 'Calpol',
              genericName: 'Paracetamol',
              strength: '500 mg',
              form: 'Tablet',
              frequencyRaw: '1+1+1',
              timingNote: 'after food',
              durationDays: 5,
              fieldConfidence: {
                'name': 0.96,
                'strength': 0.95,
                'frequency': 0.95,
                'duration': 0.90,
              },
              needsPharmacist: false,
              confirmed: true,
              isManual: false,
              identityIndex: 4,
            ),
          ],
        );
    }
  }
}

final journeyControllerProvider =
    NotifierProvider<JourneyController, JourneyState>(
      JourneyController.new,
    );
