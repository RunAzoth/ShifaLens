import 'package:flutter_test/flutter_test.dart';
import 'package:shifalens/core/models/models.dart';
import 'package:shifalens/core/strings_disclosure.dart';
import 'package:shifalens/data/real_knowledge_service.dart';
import 'package:shifalens/data/real_plan_repository.dart';
import 'package:shifalens/data/real_schedule_engine.dart';
import 'package:shifalens/services/mock/mock_prescription_reader.dart';
import 'package:shifalens/services/real/real_reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final knowledge = RealKnowledgeService();
  final engine = RealScheduleEngine(knowledge: knowledge);

  setUpAll(() async {
    await knowledge.load();
  });

  group('RealScheduleEngine — 25+ Table-Driven Frequency & Timing Tests', () {
    final frequencyCases = <({
      String name,
      String? freq,
      String? note,
      String? generic,
      List<MealSlot>? expected,
    })>[
      (
        name: '1. 1+0+1 standard twice daily',
        freq: '1+0+1',
        note: null,
        generic: 'amoxicillin + clavulanic acid',
        expected: [MealSlot.breakfast, MealSlot.dinner],
      ),
      (
        name: '2. 1-0-1 hyphenated twice daily',
        freq: '1-0-1',
        note: null,
        generic: 'ciprofloxacin',
        expected: [MealSlot.breakfast, MealSlot.dinner],
      ),
      (
        name: '3. 0+0+1 evening/dinner dose',
        freq: '0+0+1',
        note: 'after dinner',
        generic: 'paracetamol',
        expected: [MealSlot.dinner],
      ),
      (
        name: '4. 0+0+1 statin defaults to bedtime',
        freq: '0+0+1',
        note: null,
        generic: 'atorvastatin',
        expected: [MealSlot.bedtime],
      ),
      (
        name: '5. 1+0+0 morning dose',
        freq: '1+0+0',
        note: 'before breakfast',
        generic: 'omeprazole',
        expected: [MealSlot.breakfast],
      ),
      (
        name: '6. 0+1+0 lunch dose',
        freq: '0+1+0',
        note: null,
        generic: 'ferrous sulfate',
        expected: [MealSlot.lunch],
      ),
      (
        name: '7. 1+1+1 three times daily',
        freq: '1+1+1',
        note: null,
        generic: 'paracetamol',
        expected: [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner],
      ),
      (
        name: '8. 1-1-1 hyphenated three times daily',
        freq: '1-1-1',
        note: null,
        generic: 'ibuprofen',
        expected: [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner],
      ),
      (
        name: '9. 1+1+1+1 four times daily',
        freq: '1+1+1+1',
        note: null,
        generic: 'paracetamol',
        expected: [
          MealSlot.breakfast,
          MealSlot.lunch,
          MealSlot.dinner,
          MealSlot.bedtime,
        ],
      ),
      (
        name: '10. OD once daily morning default',
        freq: 'OD',
        note: null,
        generic: 'amlodipine',
        expected: [MealSlot.breakfast],
      ),
      (
        name: '11. QD once daily',
        freq: 'QD',
        note: null,
        generic: 'amlodipine',
        expected: [MealSlot.breakfast],
      ),
      (
        name: '12. OD with statin maps to bedtime',
        freq: 'OD',
        note: null,
        generic: 'rosuvastatin',
        expected: [MealSlot.bedtime],
      ),
      (
        name: '13. BD twice daily',
        freq: 'BD',
        note: null,
        generic: 'metformin',
        expected: [MealSlot.breakfast, MealSlot.dinner],
      ),
      (
        name: '14. BID twice daily',
        freq: 'BID',
        note: null,
        generic: 'metformin',
        expected: [MealSlot.breakfast, MealSlot.dinner],
      ),
      (
        name: '15. TDS three times daily',
        freq: 'TDS',
        note: null,
        generic: 'paracetamol',
        expected: [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner],
      ),
      (
        name: '16. TID three times daily',
        freq: 'TID',
        note: null,
        generic: 'mefenamic acid',
        expected: [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner],
      ),
      (
        name: '17. "3 times daily" natural phrase',
        freq: '3 times daily',
        note: null,
        generic: 'paracetamol',
        expected: [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner],
      ),
      (
        name: '18. q8h every 8 hours',
        freq: 'q8h',
        note: null,
        generic: 'amoxicillin',
        expected: [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner],
      ),
      (
        name: '19. q12h every 12 hours',
        freq: 'q12h',
        note: null,
        generic: 'ciprofloxacin',
        expected: [MealSlot.breakfast, MealSlot.dinner],
      ),
      (
        name: '20. QID four times daily',
        freq: 'QID',
        note: null,
        generic: 'paracetamol',
        expected: [
          MealSlot.breakfast,
          MealSlot.lunch,
          MealSlot.dinner,
          MealSlot.bedtime,
        ],
      ),
      (
        name: '21. HS at bedtime',
        freq: 'HS',
        note: 'at bedtime',
        generic: 'atorvastatin',
        expected: [MealSlot.bedtime],
      ),
      (
        name: '22. SOS when needed',
        freq: 'SOS',
        note: null,
        generic: 'paracetamol',
        expected: [MealSlot.whenNeeded],
      ),
      (
        name: '23. PRN when needed',
        freq: 'PRN',
        note: null,
        generic: 'ibuprofen',
        expected: [MealSlot.whenNeeded],
      ),
      (
        name: '24. 0+0+0 invalid zero dose returns null',
        freq: '0+0+0',
        note: null,
        generic: 'paracetamol',
        expected: null,
      ),
      (
        name: '25. Illegible ??? frequency returns null',
        freq: '???',
        note: null,
        generic: 'paracetamol',
        expected: null,
      ),
      (
        name: '26. Unparseable free-text frequency returns null (never guessed)',
        freq: 'take some whenever',
        note: null,
        generic: 'paracetamol',
        expected: null,
      ),
    ];

    for (final tc in frequencyCases) {
      test(tc.name, () {
        final actual = RealScheduleEngine.parseFrequency(
          tc.freq,
          timingNote: tc.note,
          generic: tc.generic,
        );
        expect(actual, equals(tc.expected));
      });
    }

    final relationCases = <({
      String name,
      String? note,
      String generic,
      MealRelation expected,
    })>[
      (
        name: '27. AC timing note -> MealRelation.before',
        note: 'AC',
        generic: 'paracetamol',
        expected: MealRelation.before,
      ),
      (
        name: '28. PC timing note -> MealRelation.after',
        note: 'PC',
        generic: 'paracetamol',
        expected: MealRelation.after,
      ),
      (
        name: '29. Empty stomach note -> MealRelation.emptyStomach',
        note: 'empty stomach',
        generic: 'omeprazole',
        expected: MealRelation.emptyStomach,
      ),
      (
        name: '30. Omeprazole default -> MealRelation.before',
        note: null,
        generic: 'omeprazole',
        expected: MealRelation.before,
      ),
      (
        name: '31. Levothyroxine default -> MealRelation.emptyStomach',
        note: null,
        generic: 'levothyroxine',
        expected: MealRelation.emptyStomach,
      ),
      (
        name: '32. Metformin default -> MealRelation.withMeal',
        note: null,
        generic: 'metformin',
        expected: MealRelation.withMeal,
      ),
      (
        name: '33. Ibuprofen (NSAID) default -> MealRelation.withMeal',
        note: null,
        generic: 'ibuprofen',
        expected: MealRelation.withMeal,
      ),
    ];

    for (final rc in relationCases) {
      test(rc.name, () {
        final cards = knowledge.foodCardsFor(rc.generic);
        final rel = RealScheduleEngine.resolveMealRelation(
          timingNote: rc.note,
          generic: rc.generic,
          foodCards: cards,
        );
        expect(rel, equals(rc.expected));
      });
    }
  });

  group('Demo Prescriptions Rx1, Rx2, Rx3 & Ramadan Mode', () {
    test('Demo Rx1: schedules 3 confirmed lines and isolates 1 flagged line in unscheduled', () async {
      final rx1 = await MockPrescriptionReader.loadCachedPrescription(0);
      final plan = engine.build(rx1);

      expect(plan.scheduled.length, equals(3));
      expect(plan.unscheduled.length, equals(1));
      expect(plan.unscheduled.first.rawText, contains('?????'));
      expect(plan.foodCardsByMedicineId['rx1_line_1'], isNotEmpty);
      expect(plan.sideEffectsByMedicineId['rx1_line_1'], isNotNull);
    });

    test('Demo Rx2: maps Glucophage with meals, Norvasc morning, Lipitor bedtime', () async {
      final rx2 = await MockPrescriptionReader.loadCachedPrescription(1);
      final plan = engine.build(rx2);

      expect(plan.scheduled.length, equals(3));
      expect(plan.unscheduled, isEmpty);

      final glucoDoses =
          plan.doses.where((d) => d.medicineId == 'rx2_line_1').toList();
      expect(
        glucoDoses.map((d) => d.slot),
        equals([MealSlot.breakfast, MealSlot.dinner]),
      );
      expect(glucoDoses.first.relation, equals(MealRelation.withMeal));

      final lipitorDoses =
          plan.doses.where((d) => d.medicineId == 'rx2_line_3').toList();
      expect(lipitorDoses.single.slot, equals(MealSlot.bedtime));
    });

    test('Demo Rx3: flags Panadol + Calpol duplicate generic and separates Ferrous sulfate from Cipro', () async {
      final rx3 = await MockPrescriptionReader.loadCachedPrescription(2);
      final plan = engine.build(rx3);

      expect(plan.scheduled.length, equals(4));
      expect(plan.duplicates.length, equals(1));
      expect(plan.duplicates.first.sameGeneric, isTrue);
      expect(plan.duplicates.first.label, equals('paracetamol'));

      final ciproSlots = plan.doses
          .where((d) => d.medicineId == 'rx3_line_1')
          .map((d) => d.slot)
          .toSet();
      final ironSlots = plan.doses
          .where((d) => d.medicineId == 'rx3_line_2')
          .map((d) => d.slot)
          .toSet();
      expect(ciproSlots, equals({MealSlot.breakfast, MealSlot.dinner}));
      expect(ironSlots, equals({MealSlot.lunch}));
    });

    test('Ramadan mode maps breakfast->suhoor, dinner->iftar, lunch->bedtime and defaults ramadanDoctorApproved=false', () async {
      final rx1 = await MockPrescriptionReader.loadCachedPrescription(0);
      final plan = engine.build(rx1, ramadan: true);

      expect(plan.ramadan, isTrue);
      expect(plan.ramadanDoctorApproved, isFalse);

      final panadolSlots = plan.doses
          .where((d) => d.medicineId == 'rx1_line_2')
          .map((d) => d.slot)
          .toList();
      expect(
        panadolSlots,
        equals([MealSlot.suhoor, MealSlot.bedtime, MealSlot.iftar]),
      );
    });
  });

  group('RealKnowledgeService — Normalization, Levenshtein Fuzzy Match, Soft Class Duplicates & PlateGuide', () {
    test('Normalizes brand string and resolves exact vs fuzzy Levenshtein <= 2 as ambiguous=true', () {
      expect(
        RealKnowledgeService.normalizeBrand('Tab. Augmentin 625 mg 1+0+1 x5d'),
        equals('augmentin'),
      );

      final exact = knowledge.resolveBrand('Tab. Augmentin 625mg');
      expect(exact.generic, equals('amoxicillin + clavulanic acid'));
      expect(exact.ambiguous, isFalse);

      // Typo "Augmentn" (Levenshtein distance 1 from "augmentin") -> resolves generic but marks ambiguous=true
      final fuzzy = knowledge.resolveBrand('Tab. Augmentn 625mg');
      expect(fuzzy.generic, equals('amoxicillin + clavulanic acid'));
      expect(fuzzy.ambiguous, isTrue);

      // Completely unknown drug -> null generic, ambiguous=true
      final unknown = knowledge.resolveBrand('Tab. XyzUnknownDrug 50mg');
      expect(unknown.generic, isNull);
      expect(unknown.ambiguous, isTrue);
    });

    test('Soft duplicate alert triggers when two lines share drugClass (Brufen + Ponstan = nsaid)', () {
      const lines = [
        MedicineLine(
          id: 'l1',
          rawText: 'Tab. Brufen 400mg',
          brandName: 'Brufen',
          genericName: 'ibuprofen',
          confirmed: true,
        ),
        MedicineLine(
          id: 'l2',
          rawText: 'Tab. Ponstan 500mg',
          brandName: 'Ponstan',
          genericName: 'mefenamic acid',
          confirmed: true,
        ),
      ];

      final dups = knowledge.findDuplicates(lines);
      expect(dups.length, equals(1));
      expect(dups.first.sameGeneric, isFalse);
      expect(
        dups.first.message.en,
        contains('ask your pharmacist if these can be taken together'),
      );
    });

    test('PlateGuide returns valid compressed PNG (<300KB) and qualitative tips without calorie targets', () async {
      final pg = await knowledge.plateGuide();
      expect(pg.imageBytes.isNotEmpty, isTrue);
      expect(pg.imageBytes.length, lessThan(300 * 1024));
      expect(pg.tips.length, greaterThanOrEqualTo(4));
      for (final tip in pg.tips) {
        expect(tip.en.toLowerCase().contains('calorie'), isFalse);
      }
    });
  });

  group('RealPlanRepository, RealReminderService & Disclosure Strings', () {
    test('RealPlanRepository saves and loads DailyPlan and TickEntry locally offline', () async {
      final repo = RealPlanRepository();
      final rx1 = await MockPrescriptionReader.loadCachedPrescription(0);
      final plan = engine.build(rx1);

      await repo.savePlan(plan);
      final loaded = await repo.loadLatest();
      expect(loaded, isNotNull);
      expect(loaded!.id, equals(plan.id));

      final tick = TickEntry(
        doseKey: 'rx1_line_1|breakfast',
        date: '2026-11-11',
        taken: true,
        at: DateTime.now(),
      );
      await repo.saveTick(tick);
      final recent = await repo.tickLog(lastDays: 7).first;
      expect(recent, isNotEmpty);
      expect(recent.first.doseKey, equals('rx1_line_1|breakfast'));
    });

    test('RealReminderService formats bilingual notification and computes TZDateTime', () {
      final reminder = RealReminderService();
      const med = MedicineLine(
        id: 'm1',
        rawText: 'Tab. Augmentin 625 mg',
        brandName: 'Augmentin',
        strength: '625 mg',
        confirmed: true,
      );
      const dose = DoseEvent(
        medicineId: 'm1',
        slot: MealSlot.breakfast,
        relation: MealRelation.after,
      );
      final formatted = RealReminderService.formatBilingualNotification(
        med,
        dose,
      );
      expect(formatted.title, contains('Augmentin'));
      expect(formatted.body, contains('after breakfast'));
      expect(formatted.body, contains('ناشتے'));

      final nextTime = reminder.computeNextInstanceOfTime(
        '08:30',
        relation: MealRelation.before,
      );
      expect(nextTime.hour, equals(8));
      expect(nextTime.minute, equals(0));

      expect(ShifaLensDisclosureStrings.allSections.length, equals(6));
    });
  });
}
