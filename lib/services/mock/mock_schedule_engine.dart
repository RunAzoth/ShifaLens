import '../../core/models/models.dart';
import '../../core/services/knowledge_service.dart';
import '../../core/services/schedule_engine.dart';
import 'mock_knowledge_service.dart';

class MockScheduleEngine implements ScheduleEngine {
  final KnowledgeService _knowledge;

  MockScheduleEngine({KnowledgeService? knowledge})
      : _knowledge = knowledge ?? MockKnowledgeService();

  @override
  DailyPlan build(
    Prescription rx, {
    bool ramadan = false,
    bool ramadanApproved = false,
  }) {
    final scheduled = <MedicineLine>[];
    final unscheduled = <MedicineLine>[];

    for (final line in rx.lines) {
      final hasLowConfidence =
          line.fieldConfidence.values.any((v) => v < 0.75);
      final missingCritical =
          (line.brandName == null && line.genericName == null) ||
              line.frequencyRaw == null ||
              line.frequencyRaw!.trim().isEmpty;

      if (!line.confirmed ||
          line.needsPharmacist ||
          hasLowConfidence ||
          missingCritical) {
        unscheduled.add(line);
      } else {
        scheduled.add(line);
      }
    }

    final hasCipro = scheduled.any(
      (m) => (m.genericName ?? '').toLowerCase().contains('ciprofloxacin'),
    );

    final doses = <DoseEvent>[];
    final foodCardsByMedId = <String, List<FoodCard>>{};
    final sideEffectsByMedId = <String, SideEffectInfo>{};

    for (final med in scheduled) {
      final gen = (med.genericName ??
              _knowledge.resolveBrand(med.brandName ?? med.rawText).generic ??
              '')
          .toLowerCase();

      if (gen.isNotEmpty) {
        final cards = _knowledge.foodCardsFor(gen);
        if (cards.isNotEmpty) {
          foodCardsByMedId[med.id] = cards;
        }
        final se = _knowledge.sideEffectsFor(gen);
        if (se != null) {
          sideEffectsByMedId[med.id] = se;
        }
      }

      final relation = _resolveRelation(med, gen);
      final slots = _resolveSlots(
        med,
        gen: gen,
        ramadan: ramadan && ramadanApproved,
        separateIronFromCipro: hasCipro && gen.contains('ferrous'),
      );

      final note = _buildDoseNote(
        gen,
        relation,
        separateIronFromCipro: hasCipro && gen.contains('ferrous'),
      );

      for (final slot in slots) {
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
      foodCardsByMedicineId: foodCardsByMedId,
      sideEffectsByMedicineId: sideEffectsByMedId,
      ramadan: ramadan,
      ramadanDoctorApproved: ramadanApproved,
    );
  }

  MealRelation _resolveRelation(MedicineLine med, String gen) {
    final note = (med.timingNote ?? '').toLowerCase();
    if (note.contains('empty') ||
        note.contains('before') ||
        gen == 'omeprazole') {
      return note.contains('empty')
          ? MealRelation.emptyStomach
          : MealRelation.before;
    }
    if (note.contains('with meal') ||
        gen == 'metformin' ||
        gen == 'amoxicillin + clavulanic acid') {
      return MealRelation.withMeal;
    }
    if (note.contains('bedtime') ||
        (med.frequencyRaw ?? '').toUpperCase() == 'HS') {
      return MealRelation.anytime;
    }
    return MealRelation.after;
  }

  List<MealSlot> _resolveSlots(
    MedicineLine med, {
    required String gen,
    required bool ramadan,
    required bool separateIronFromCipro,
  }) {
    final freq = (med.frequencyRaw ?? '').trim().toUpperCase();

    if (separateIronFromCipro) {
      return [ramadan ? MealSlot.bedtime : MealSlot.lunch];
    }

    if (freq == 'HS' || (med.timingNote ?? '').toLowerCase().contains('bed')) {
      return [MealSlot.bedtime];
    }
    if (freq == 'SOS' || freq == 'PRN') {
      return [MealSlot.whenNeeded];
    }
    if (freq == '1+0+0' || freq == 'OD' || freq == 'ONCE DAILY') {
      return [ramadan ? MealSlot.suhoor : MealSlot.breakfast];
    }
    if (freq == '0+0+1') {
      return [ramadan ? MealSlot.iftar : MealSlot.dinner];
    }
    if (freq == '1+0+1' || freq == 'BD' || freq == 'BID') {
      return ramadan
          ? [MealSlot.suhoor, MealSlot.iftar]
          : [MealSlot.breakfast, MealSlot.dinner];
    }
    if (freq == '1+1+1' || freq == 'TDS' || freq == 'TID') {
      return ramadan
          ? [MealSlot.suhoor, MealSlot.iftar, MealSlot.bedtime]
          : [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner];
    }

    return [ramadan ? MealSlot.iftar : MealSlot.breakfast];
  }

  Bilingual? _buildDoseNote(
    String gen,
    MealRelation relation, {
    required bool separateIronFromCipro,
  }) {
    if (separateIronFromCipro) {
      return const Bilingual(
        ur: 'سپرو (Cipro) اور دودھ/چائے سے کم از کم 2 گھنٹے کا وقفہ رکھیں۔',
        en: 'Keep at least 2 hours apart from Cipro, milk, and tea.',
      );
    }
    if (gen == 'ciprofloxacin') {
      return const Bilingual(
        ur: 'دودھ، دہی اور آئرن سے 2 گھنٹے الگ رکھیں۔',
        en: 'Keep 2 hours apart from dairy and iron tablets.',
      );
    }
    if (gen == 'omeprazole' || relation == MealRelation.before) {
      return const Bilingual(
        ur: 'ناشتے سے 30 منٹ پہلے پانی کے ساتھ لیں۔',
        en: 'Take 30 minutes before breakfast with water.',
      );
    }
    if (relation == MealRelation.withMeal) {
      return const Bilingual(
        ur: 'کھانے کے ساتھ لیں۔',
        en: 'Take with your meal.',
      );
    }
    return const Bilingual(
      ur: 'کھانے کے بعد پانی کے ساتھ لیں۔',
      en: 'Take after your meal with water.',
    );
  }
}
