import '../core/models/models.dart';
import '../core/services/knowledge_service.dart';
import '../core/services/schedule_engine.dart';
import 'real_knowledge_service.dart';

class RealScheduleEngine implements ScheduleEngine {
  final KnowledgeService _knowledge;

  RealScheduleEngine({KnowledgeService? knowledge})
      : _knowledge = knowledge ?? RealKnowledgeService();

  @override
  DailyPlan build(
    Prescription rx, {
    bool ramadan = false,
    bool ramadanApproved = false,
  }) {
    final scheduled = <MedicineLine>[];
    final unscheduled = <MedicineLine>[];

    // Map each scheduled line's resolved generic and parsed base slots
    final resolvedGenerics = <String, String>{};
    final parsedBaseSlots = <String, List<MealSlot>>{};

    for (final line in rx.lines) {
      final critLowConf = _hasCriticalLowConfidence(line.fieldConfidence);
      final hasIdentity =
          (line.brandName != null && line.brandName!.trim().isNotEmpty) ||
              (line.genericName != null && line.genericName!.trim().isNotEmpty);

      String? generic = line.genericName?.trim();
      bool brandAmbiguous = false;
      if ((generic == null || generic.isEmpty) && line.brandName != null) {
        final res = _knowledge.resolveBrand(line.brandName!);
        generic = res.generic;
        brandAmbiguous = res.ambiguous;
      }

      final slots = parseFrequency(
        line.frequencyRaw,
        timingNote: line.timingNote,
        generic: generic,
      );

      if (!line.confirmed ||
          line.needsPharmacist ||
          critLowConf ||
          !hasIdentity ||
          brandAmbiguous ||
          generic == null ||
          generic.isEmpty ||
          slots == null ||
          slots.isEmpty) {
        unscheduled.add(line);
      } else {
        final normalizedLine = line.genericName == null
            ? line.copyWith(genericName: generic)
            : line;
        scheduled.add(normalizedLine);
        resolvedGenerics[normalizedLine.id] = generic.toLowerCase();
        parsedBaseSlots[normalizedLine.id] = slots;
      }
    }

    // Check if any scheduled medicine is a fluoroquinolone or tetracycline requiring separation from iron
    final chelationAntibioticSlots = <MealSlot>{};
    for (final med in scheduled) {
      final gen = resolvedGenerics[med.id] ?? '';
      if (_isChelationSensitiveAntibiotic(gen)) {
        chelationAntibioticSlots.addAll(parsedBaseSlots[med.id] ?? const []);
      }
    }

    final doses = <DoseEvent>[];
    final foodCardsByMedicineId = <String, List<FoodCard>>{};
    final sideEffectsByMedicineId = <String, SideEffectInfo>{};

    for (final med in scheduled) {
      final gen = resolvedGenerics[med.id] ?? '';
      final foodCards = _knowledge.foodCardsFor(gen);
      if (foodCards.isNotEmpty) {
        foodCardsByMedicineId[med.id] = foodCards;
      }

      final sideEffects = _knowledge.sideEffectsFor(gen);
      if (sideEffects != null) {
        sideEffectsByMedicineId[med.id] = sideEffects;
      }

      var baseSlots = List<MealSlot>.from(parsedBaseSlots[med.id] ?? const []);
      final isIron = gen.contains('ferrous') || gen.contains('iron');
      final needsSeparationFromAntibiotic =
          isIron && chelationAntibioticSlots.isNotEmpty;

      if (needsSeparationFromAntibiotic) {
        baseSlots = _separateIronSlots(baseSlots, chelationAntibioticSlots);
      }

      final finalSlots = ramadan
          ? baseSlots.map(mapSlotToRamadan).toList()
          : baseSlots;

      final relation = resolveMealRelation(
        timingNote: med.timingNote,
        generic: gen,
        foodCards: foodCards,
      );

      final note = buildDoseNote(
        generic: gen,
        relation: relation,
        separatedFromAntibiotic: needsSeparationFromAntibiotic,
        ramadan: ramadan,
        ramadanApproved: ramadanApproved,
      );

      for (final slot in finalSlots) {
        doses.add(
          DoseEvent(
            medicineId: med.id,
            slot: slot,
            relation: relation,
            note: note,
          ),
        );
      }
    }

    final duplicates = _knowledge.findDuplicates(scheduled);

    return DailyPlan(
      id: 'plan_${rx.id}',
      prescriptionId: rx.id,
      scheduled: scheduled,
      unscheduled: unscheduled,
      doses: doses,
      duplicates: duplicates,
      foodCardsByMedicineId: foodCardsByMedicineId,
      sideEffectsByMedicineId: sideEffectsByMedicineId,
      ramadan: ramadan,
      ramadanDoctorApproved: ramadan ? ramadanApproved : false,
    );
  }

  static bool _hasCriticalLowConfidence(Map<String, double> conf) {
    for (final key in const ['name', 'strength', 'frequency']) {
      final val = conf[key];
      if (val != null && val < 0.75) {
        return true;
      }
    }
    return false;
  }

  static bool _isChelationSensitiveAntibiotic(String generic) {
    return generic.contains('ciprofloxacin') ||
        generic.contains('levofloxacin') ||
        generic.contains('moxifloxacin') ||
        generic.contains('doxycycline') ||
        generic.contains('tetracycline');
  }

  static List<MealSlot> _separateIronSlots(
    List<MealSlot> ironSlots,
    Set<MealSlot> antibioticSlots,
  ) {
    final result = <MealSlot>[];
    for (final slot in ironSlots) {
      if (!antibioticSlots.contains(slot)) {
        result.add(slot);
      } else if (!antibioticSlots.contains(MealSlot.lunch)) {
        result.add(MealSlot.lunch);
      } else if (!antibioticSlots.contains(MealSlot.afternoon)) {
        result.add(MealSlot.afternoon);
      } else {
        result.add(MealSlot.midMorning);
      }
    }
    return result.toSet().toList();
  }

  /// Deterministically parses frequencyRaw into MealSlots, or returns null if unparseable.
  static List<MealSlot>? parseFrequency(
    String? frequencyRaw, {
    String? timingNote,
    String? generic,
  }) {
    if (frequencyRaw == null) return null;
    final raw = frequencyRaw.trim();
    if (raw.isEmpty || raw.contains('?')) return null;

    final upper = raw.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final noteLower = (timingNote ?? '').toLowerCase();
    final genLower = (generic ?? '').toLowerCase();
    final isStatin = genLower.contains('atorvastatin') ||
        genLower.contains('rosuvastatin') ||
        genLower.contains('simvastatin');
    final isBedtimeNote = noteLower.contains('bedtime') ||
        noteLower.contains('at night') ||
        noteLower.contains('night') ||
        noteLower == 'hs';

    // 1. SOS / PRN / When needed
    if (RegExp(r'^(SOS|PRN|S\.O\.S\.?|P\.R\.N\.?|AS NEEDED|WHEN NEEDED)$')
        .hasMatch(upper)) {
      return const [MealSlot.whenNeeded];
    }

    // 2. HS / Bedtime
    if (RegExp(r'^(HS|H\.S\.?|QHS|AT BEDTIME|BEDTIME|NIGHT)$').hasMatch(upper)) {
      return const [MealSlot.bedtime];
    }

    // 3. 3-part numeric pattern: 1+0+1, 1-0-1, 0+0+1, 1+1+1, 1/0/1, etc.
    final threePart = RegExp(
      r'^(\d+(?:\.\d+)?)\s*[+\-/]\s*(\d+(?:\.\d+)?)\s*[+\-/]\s*(\d+(?:\.\d+)?)$',
    ).firstMatch(upper);
    if (threePart != null) {
      final m = double.tryParse(threePart.group(1)!) ?? 0;
      final a = double.tryParse(threePart.group(2)!) ?? 0;
      final n = double.tryParse(threePart.group(3)!) ?? 0;
      if (m <= 0 && a <= 0 && n <= 0) return null;

      final slots = <MealSlot>[];
      if (m > 0) slots.add(MealSlot.breakfast);
      if (a > 0) slots.add(MealSlot.lunch);
      if (n > 0) {
        if (m == 0 && a == 0 && (isBedtimeNote || isStatin)) {
          slots.add(MealSlot.bedtime);
        } else {
          slots.add(MealSlot.dinner);
        }
      }
      return slots;
    }

    // 4. 4-part numeric pattern: 1+1+1+1 or 1-1-1-1
    final fourPart = RegExp(
      r'^(\d+(?:\.\d+)?)\s*[+\-/]\s*(\d+(?:\.\d+)?)\s*[+\-/]\s*(\d+(?:\.\d+)?)\s*[+\-/]\s*(\d+(?:\.\d+)?)$',
    ).firstMatch(upper);
    if (fourPart != null) {
      final p1 = double.tryParse(fourPart.group(1)!) ?? 0;
      final p2 = double.tryParse(fourPart.group(2)!) ?? 0;
      final p3 = double.tryParse(fourPart.group(3)!) ?? 0;
      final p4 = double.tryParse(fourPart.group(4)!) ?? 0;
      if (p1 <= 0 && p2 <= 0 && p3 <= 0 && p4 <= 0) return null;

      final slots = <MealSlot>[];
      if (p1 > 0) slots.add(MealSlot.breakfast);
      if (p2 > 0) slots.add(MealSlot.lunch);
      if (p3 > 0) slots.add(MealSlot.dinner);
      if (p4 > 0) slots.add(MealSlot.bedtime);
      return slots;
    }

    // 5. Once daily: OD, QD, O.D., Q.D., ONCE DAILY, 1 TIME DAILY, Q24H
    if (RegExp(
      r'^(OD|O\.D\.?|QD|Q\.D\.?|ONCE DAILY|ONCE A DAY|1 TIME DAILY|1X DAILY|DAILY|Q24H|EVERY 24 HOURS)$',
    ).hasMatch(upper)) {
      if (isBedtimeNote || isStatin) return const [MealSlot.bedtime];
      if (noteLower.contains('dinner') || noteLower.contains('evening')) {
        return const [MealSlot.dinner];
      }
      if (noteLower.contains('lunch') || noteLower.contains('noon')) {
        return const [MealSlot.lunch];
      }
      return const [MealSlot.breakfast];
    }

    // 6. Twice daily: BD, BID, B.D., B.I.D., TWICE DAILY, 2 TIMES DAILY, Q12H
    if (RegExp(
      r'^(BD|B\.D\.?|BID|B\.I\.D\.?|TWICE DAILY|TWICE A DAY|2 TIMES DAILY|2 TIMES A DAY|2X DAILY|Q12H|EVERY 12 HOURS)$',
    ).hasMatch(upper)) {
      return const [MealSlot.breakfast, MealSlot.dinner];
    }

    // 7. Three times daily: TDS, TID, T.D.S., T.I.D., 3 TIMES DAILY, THREE TIMES DAILY, Q8H
    if (RegExp(
      r'^(TDS|T\.D\.S\.?|TID|T\.I\.D\.?|3 TIMES DAILY|3 TIMES A DAY|THREE TIMES DAILY|THRICE DAILY|3X DAILY|Q8H|EVERY 8 HOURS)$',
    ).hasMatch(upper)) {
      return const [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner];
    }

    // 8. Four times daily: QID, QDS, 4 TIMES DAILY, Q6H
    if (RegExp(
      r'^(QID|Q\.I\.D\.?|QDS|Q\.D\.S\.?|4 TIMES DAILY|4 TIMES A DAY|FOUR TIMES DAILY|4X DAILY|Q6H|EVERY 6 HOURS)$',
    ).hasMatch(upper)) {
      return const [
        MealSlot.breakfast,
        MealSlot.lunch,
        MealSlot.dinner,
        MealSlot.bedtime,
      ];
    }

    return null;
  }

  /// Maps a standard MealSlot into its Ramadan equivalent:
  /// breakfast -> suhoor, dinner -> iftar, lunch/afternoon -> between iftar and suhoor (bedtime).
  static MealSlot mapSlotToRamadan(MealSlot slot) {
    switch (slot) {
      case MealSlot.wakeUp:
      case MealSlot.breakfast:
        return MealSlot.suhoor;
      case MealSlot.dinner:
        return MealSlot.iftar;
      case MealSlot.midMorning:
      case MealSlot.lunch:
      case MealSlot.afternoon:
        return MealSlot.bedtime;
      case MealSlot.suhoor:
        return MealSlot.suhoor;
      case MealSlot.iftar:
        return MealSlot.iftar;
      case MealSlot.bedtime:
        return MealSlot.bedtime;
      case MealSlot.whenNeeded:
        return MealSlot.whenNeeded;
    }
  }

  /// Resolves MealRelation using timingNote (AC/PC/before/after/empty stomach/with food)
  /// and per-generic defaults from food_med.
  static MealRelation resolveMealRelation({
    String? timingNote,
    String? generic,
    List<FoodCard> foodCards = const [],
  }) {
    final note = (timingNote ?? '').trim().toLowerCase();
    final gen = (generic ?? '').trim().toLowerCase();

    if (note.isNotEmpty) {
      if (note.contains('empty stomach') || note.contains('خالی پیٹ')) {
        return MealRelation.emptyStomach;
      }
      if (RegExp(r'\b(ac|a\.c\.|before)\b').hasMatch(note) ||
          note.contains('پہلے')) {
        return MealRelation.before;
      }
      if (note.contains('with meal') ||
          note.contains('with food') ||
          note.contains('during meal') ||
          note.contains('کھانے کے ساتھ')) {
        return MealRelation.withMeal;
      }
      if (RegExp(r'\b(pc|p\.c\.|after)\b').hasMatch(note) ||
          note.contains('بعد')) {
        return MealRelation.after;
      }
      if (note.contains('bedtime') || note.contains('anytime')) {
        return MealRelation.anytime;
      }
    }

    // Per-generic defaults from food_med / clinical rules
    if (gen == 'levothyroxine') {
      return MealRelation.emptyStomach;
    }
    if (gen == 'omeprazole' ||
        gen == 'esomeprazole' ||
        gen == 'lansoprazole' ||
        gen == 'pantoprazole') {
      return MealRelation.before;
    }
    if (gen == 'atorvastatin' || gen == 'rosuvastatin') {
      return MealRelation.anytime;
    }

    for (final card in foodCards) {
      if (card.type == FoodCardType.emptyStomach) {
        return MealRelation.emptyStomach;
      }
      if (card.type == FoodCardType.takeWithFood) {
        return MealRelation.withMeal;
      }
    }

    if (gen == 'metformin' ||
        gen == 'amoxicillin + clavulanic acid' ||
        gen == 'ibuprofen' ||
        gen == 'mefenamic acid' ||
        gen == 'diclofenac' ||
        gen == 'naproxen') {
      return MealRelation.withMeal;
    }

    return MealRelation.after;
  }

  static Bilingual buildDoseNote({
    required String generic,
    required MealRelation relation,
    required bool separatedFromAntibiotic,
    required bool ramadan,
    required bool ramadanApproved,
  }) {
    final ramadanSuffixUr = ramadan && !ramadanApproved
        ? ' (رمضان کا مجوزہ وقت — ڈاکٹر سے تصدیق کریں)'
        : '';
    final ramadanSuffixEn = ramadan && !ramadanApproved
        ? ' (Suggested Ramadan timing — confirm with your doctor)'
        : '';

    if (separatedFromAntibiotic) {
      return Bilingual(
        ur: 'اینٹی بائیوٹک (Cipro/Doxy) اور دودھ/چائے سے کم از کم 2 گھنٹے کا وقفہ رکھیں۔$ramadanSuffixUr',
        en: 'Keep at least 2 hours apart from your antibiotic, milk, and tea.$ramadanSuffixEn',
      );
    }
    if (generic.contains('ciprofloxacin') || generic.contains('doxycycline')) {
      return Bilingual(
        ur: 'دودھ، دہی، کیلشیم اور آئرن کی گولی سے 2 گھنٹے الگ رکھیں۔$ramadanSuffixUr',
        en: 'Separate by 2 hours from milk, yogurt, calcium, and iron.$ramadanSuffixEn',
      );
    }
    if (relation == MealRelation.emptyStomach) {
      return Bilingual(
        ur: 'کھانے سے 30 تا 60 منٹ پہلے خالی پیٹ سادہ پانی کے ساتھ لیں۔$ramadanSuffixUr',
        en: 'Take on an empty stomach 30–60 minutes before food with plain water.$ramadanSuffixEn',
      );
    }
    if (relation == MealRelation.before) {
      return Bilingual(
        ur: 'کھانے سے 30 منٹ پہلے پانی کے ساتھ لیں۔$ramadanSuffixUr',
        en: 'Take 30 minutes before your meal with water.$ramadanSuffixEn',
      );
    }
    if (relation == MealRelation.withMeal) {
      return Bilingual(
        ur: 'کھانے کے دوران یا کھانے کے فوراً ساتھ لیں۔$ramadanSuffixUr',
        en: 'Take with your meal.$ramadanSuffixEn',
      );
    }
    if (relation == MealRelation.anytime) {
      return Bilingual(
        ur: 'رات سونے سے پہلے مقررہ وقت پر پانی کے ساتھ لیں۔$ramadanSuffixUr',
        en: 'Take at your scheduled bedtime with water.$ramadanSuffixEn',
      );
    }
    return Bilingual(
      ur: 'کھانے کے بعد سادہ پانی کے ساتھ لیں۔$ramadanSuffixUr',
      en: 'Take after your meal with plain water.$ramadanSuffixEn',
    );
  }
}
