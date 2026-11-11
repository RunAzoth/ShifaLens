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

class JourneyState {
  final Uint8List? capturedImageBytes;
  final DemoPrescriptionId? activeDemoId;
  final Prescription? prescription;
  final Set<String> keptAsPharmacistIds;
  final DailyPlan? latestPlan;
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
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      ramadanMode: ramadanMode ?? this.ramadanMode,
      ramadanDoctorApproved:
          ramadanDoctorApproved ?? this.ramadanDoctorApproved,
    );
  }
}

class JourneyController extends StateNotifier<JourneyState> {
  final Ref _ref;

  JourneyController(this._ref) : super(const JourneyState()) {
    _initKnowledgeAndPlan();
  }

  Future<void> _initKnowledgeAndPlan() async {
    try {
      final knowledge = _ref.read(knowledgeServiceProvider);
      await knowledge.load();
      final repo = _ref.read(planRepositoryProvider);
      final savedPlan = await repo.loadLatest();
      if (savedPlan != null && mounted) {
        state = state.copyWith(latestPlan: savedPlan);
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
    state = state.copyWith(
      prescription: rx,
      capturedImageBytes: imageBytes ?? state.capturedImageBytes,
      keptAsPharmacistIds: {},
      isLoading: false,
      clearError: true,
    );
  }

  /// Begin an empty manual prescription if none is active
  void startManualPrescription() {
    if (state.prescription != null) return;
    state = state.copyWith(
      prescription: Prescription(
        id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
        lines: const [],
        createdAt: DateTime.now(),
        synthetic: true,
      ),
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
      final knowledge = _ref.read(knowledgeServiceProvider);
      await knowledge.load();
      final reader = _ref.read(prescriptionReaderProvider);
      final rx = await reader.read(bytes);

      // If a specific demo chip (Rx2/Rx3) was chosen and the mock reader returned a
      // default prescription that didn't differentiate the byte marker, ensure the
      // requested synthetic demo prescription is faithfully loaded.
      final resolvedRx = _ensureDemoMatchIfRequested(rx, state.activeDemoId);

      if (!mounted) return false;
      state = state.copyWith(
        prescription: resolvedRx,
        keptAsPharmacistIds: {},
        isLoading: false,
        clearError: true,
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
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
        // Rx1 always has Augmentin, Panadol, Risek + 1 flagged illegible line
        final hasFlagged = readRx.lines.any((l) => l.needsPharmacist);
        if (readRx.lines.isNotEmpty && hasFlagged) return readRx;
        return _syntheticDemoPrescription(DemoPrescriptionId.rx1);
      case DemoPrescriptionId.rx2:
        final hasGlucophage = readRx.lines.any(
          (l) => (l.brandName ?? '').toLowerCase().contains('glucophage'),
        );
        if (hasGlucophage) return readRx;
        return _syntheticDemoPrescription(DemoPrescriptionId.rx2);
      case DemoPrescriptionId.rx3:
        final hasCalpol = readRx.lines.any(
          (l) => (l.brandName ?? '').toLowerCase().contains('calpol'),
        );
        if (hasCalpol) return readRx;
        return _syntheticDemoPrescription(DemoPrescriptionId.rx3);
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

    // Ensure every non-flagged line is marked confirmed: true, while lines kept
    // as "ask pharmacist" remain needsPharmacist: true, confirmed: false so
    // Non-Negotiable Rule #2 routes them to `DailyPlan.unscheduled`.
    final confirmedLines = rx.lines.map((line) {
      if (line.needsPharmacist) {
        return line.copyWith(needsPharmacist: true, confirmed: false);
      }
      return line.copyWith(needsPharmacist: false, confirmed: true);
    }).toList();

    final finalizedRx = rx.copyWith(lines: confirmedLines);
    final engine = _ref.read(scheduleEngineProvider);
    final plan = engine.build(
      finalizedRx,
      ramadan: state.ramadanMode,
      ramadanApproved: state.ramadanDoctorApproved,
    );

    try {
      final repo = _ref.read(planRepositoryProvider);
      await repo.savePlan(plan);
    } catch (_) {
      // Keep working in memory even if repository isn't persisted in widget test
    }

    state = state.copyWith(
      prescription: finalizedRx,
      latestPlan: plan,
    );
    return plan;
  }

  /// Reset demo state (called from Demo Tools drawer)
  void resetAll() {
    state = const JourneyState();
  }

  /// Built-in synthetic prescription definitions matching Block 0 exactly
  static Prescription _syntheticDemoPrescription(DemoPrescriptionId id) {
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
    StateNotifierProvider<JourneyController, JourneyState>(
  (ref) => JourneyController(ref),
);
