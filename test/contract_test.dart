import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifalens/app/config.dart';
import 'package:shifalens/app/providers.dart';
import 'package:shifalens/core/models/models.dart';
import 'package:shifalens/services/mock/mock_services.dart';
import 'package:shifalens/services/real/real_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final wav = MockVoiceService.buildMinimalWavBytes();
    for (final name in ['plan_rx1.wav', 'plan_rx2.wav', 'plan_rx3.wav']) {
      final f = File('assets/demo/cached/$name');
      if (!f.existsSync()) {
        f.writeAsBytesSync(wav);
      }
    }
  });

  group('Contract v1 & All 8 AppConfig Flags', () {
    test('AppConfig defaults all mock flags to true and flips all 8 to Real cleanly', () {
      const config = AppConfig();
      expect(config.mockReader, isTrue);
      expect(config.mockStrips, isTrue);
      expect(config.mockQA, isTrue);
      expect(config.mockVoice, isTrue);
      expect(config.mockKnowledge, isTrue);
      expect(config.mockRepo, isTrue);
      expect(config.mockReminders, isTrue);
      expect(config.mockShare, isTrue);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(prescriptionReaderProvider),
        isA<MockPrescriptionReader>(),
      );
      expect(container.read(stripMatcherProvider), isA<MockStripMatcher>());
      expect(container.read(qaServiceProvider), isA<MockQAService>());
      expect(container.read(voiceServiceProvider), isA<MockVoiceService>());
      expect(
        container.read(knowledgeServiceProvider),
        isA<MockKnowledgeService>(),
      );
      expect(container.read(scheduleEngineProvider), isA<MockScheduleEngine>());
      expect(container.read(planRepositoryProvider), isA<MockPlanRepository>());
      expect(
        container.read(reminderServiceProvider),
        isA<MockReminderService>(),
      );
      expect(container.read(shareServiceProvider), isA<MockShareService>());

      container
          .read(appConfigProvider.notifier)
          .setConfig(const AppConfig.allReal());

      expect(
        container.read(prescriptionReaderProvider),
        isA<RealPrescriptionReader>(),
      );
      expect(container.read(stripMatcherProvider), isA<RealStripMatcher>());
      expect(container.read(qaServiceProvider), isA<RealQAService>());
      expect(container.read(voiceServiceProvider), isA<RealVoiceService>());
      expect(
        container.read(knowledgeServiceProvider),
        isA<RealKnowledgeService>(),
      );
      expect(container.read(scheduleEngineProvider), isA<RealScheduleEngine>());
      expect(container.read(planRepositoryProvider), isA<RealPlanRepository>());
      expect(
        container.read(reminderServiceProvider),
        isA<RealReminderService>(),
      );
      expect(container.read(shareServiceProvider), isA<RealShareService>());
    });

    test('Models serialize and deserialize via toJson/fromJson', () {
      const bi = Bilingual(ur: 'صبح', en: 'Morning');
      expect(Bilingual.fromJson(bi.toJson()), equals(bi));

      final tick = TickEntry(
        doseKey: 'rx1_line_1|breakfast',
        date: '2026-11-11',
        taken: true,
        at: DateTime.parse('2026-11-11T08:30:00.000Z'),
      );
      final restoredTick = TickEntry.fromJson(tick.toJson());
      expect(restoredTick.doseKey, equals(tick.doseKey));
      expect(restoredTick.taken, isTrue);
    });
  });

  group('Rule 1 & 2: Knowledge, ScheduleEngine & Prescription Post-Validation', () {
    test('RealPrescriptionReader nulls fields <0.75 confidence and sets needsPharmacist', () {
      final knowledge = RealKnowledgeService();
      final reader = RealPrescriptionReader(
        client: GeminiClient(),
        knowledge: knowledge,
      );

      final highConfLine = reader.parseAndValidateLine(
        {
          'rawText': 'Tab. Augmentin 625 mg 1+0+1 x 5d',
          'brandName': 'Augmentin',
          'strength': '625 mg',
          'form': 'Tablet',
          'frequencyRaw': '1+0+1',
          'timingNote': 'after meals',
          'durationDays': 5,
          'nameConfidence': 0.95,
          'strengthConfidence': 0.92,
          'frequencyConfidence': 0.96,
          'durationConfidence': 0.90,
          'flaggedIllegible': false,
        },
        index: 0,
      );

      expect(highConfLine.genericName, equals('amoxicillin + clavulanic acid'));
      expect(highConfLine.needsPharmacist, isFalse);
      expect(highConfLine.confirmed, isTrue);
      expect(highConfLine.identityIndex, equals(0));

      final lowConfLine = reader.parseAndValidateLine(
        {
          'rawText': 'Tab. ????? 1+0+1',
          'brandName': 'UnknownGuess',
          'strength': '500 mg',
          'form': 'Tablet',
          'frequencyRaw': '1+0+1',
          'nameConfidence': 0.45,
          'strengthConfidence': 0.30,
          'frequencyConfidence': 0.85,
          'durationConfidence': 0.10,
          'flaggedIllegible': true,
        },
        index: 3,
      );

      expect(lowConfLine.brandName, isNull);
      expect(lowConfLine.genericName, isNull);
      expect(lowConfLine.strength, isNull);
      expect(lowConfLine.needsPharmacist, isTrue);
      expect(lowConfLine.confirmed, isFalse);
      expect(lowConfLine.identityIndex, equals(3));
    });
  });

  group('Task 6: RealStripMatcher deterministic checks', () {
    test('Reports <0.7 confidence as unreadable and detects strength mismatch & shared generic in code', () async {
      final knowledge = RealKnowledgeService();
      final matcher = RealStripMatcher(
        client: GeminiClient(),
        knowledge: knowledge,
      );
      final rx1 = await MockPrescriptionReader.loadCachedPrescription(0);

      final lowConf = matcher.postProcessStripMatch(
        {
          'imageIndex': 0,
          'readText': 'Blurry strip',
          'readBrand': 'Augmentin',
          'readStrength': '625 mg',
          'matchedMedicineId': 'rx1_line_1',
          'confidence': 0.65,
          'issue': 'none',
        },
        defaultIndex: 0,
        prescribedMeds: rx1.lines,
      );
      expect(lowConf.issue, equals(StripIssue.unreadable));
      expect(lowConf.matchedMedicineId, isNull);

      final strengthMismatch = matcher.postProcessStripMatch(
        {
          'imageIndex': 1,
          'readText': 'Risek 40mg Capsules',
          'readBrand': 'Risek',
          'readStrength': '40 mg',
          'matchedMedicineId': 'rx1_line_3',
          'confidence': 0.92,
          'issue': 'none',
        },
        defaultIndex: 1,
        prescribedMeds: rx1.lines,
      );
      expect(strengthMismatch.issue, equals(StripIssue.strengthMismatch));

      final sameGenericDifferentBrand = matcher.postProcessStripMatch(
        {
          'imageIndex': 2,
          'readText': 'Calpol 500mg Tablets',
          'readBrand': 'Calpol',
          'readStrength': '500 mg',
          'matchedMedicineId': null,
          'confidence': 0.90,
          'issue': 'notInPrescription',
        },
        defaultIndex: 2,
        prescribedMeds: rx1.lines,
      );
      expect(sameGenericDifferentBrand.readText, contains('paracetamol'));
    });
  });

  group('Task 7 & 8: RealQAService post-validation and RealVoiceService', () {
    test('RealQAService forces fixed fallback if any source key is not in CONTEXT', () async {
      final qa = RealQAService(client: GeminiClient());
      final rx1 = await MockPrescriptionReader.loadCachedPrescription(0);
      final plan = RealScheduleEngine().build(rx1);
      final context = qa.buildContextBlock(plan);

      final validResult = qa.postValidateResponse(
        {
          'answerUr': 'آگمینٹن کھانے کے ساتھ لیں۔',
          'answerEn': 'Take Augmentin with food.',
          'grounded': true,
          'escalate': false,
          'sources': ['food_amox_clav_1'],
        },
        context.validKeys,
      );
      expect(validResult.grounded, isTrue);
      expect(validResult.escalateToPharmacist, isFalse);

      final hallucinatedSourceResult = qa.postValidateResponse(
        {
          'answerUr': 'آپ یہ دوا چھوڑ سکتے ہیں۔',
          'answerEn': 'You can skip this medicine.',
          'grounded': true,
          'escalate': false,
          'sources': ['invented_source_key_999'],
        },
        context.validKeys,
      );
      expect(hallucinatedSourceResult.grounded, isFalse);
      expect(hallucinatedSourceResult.escalateToPharmacist, isTrue);
      expect(
        hallucinatedSourceResult.answer.en,
        equals('Please ask your pharmacist or doctor.'),
      );

      final redFlagAnswer = await qa.ask(
        text: 'Patient has severe chest pain and trouble breathing',
        plan: plan,
      );
      expect(redFlagAnswer.escalateToPharmacist, isTrue);
      expect(redFlagAnswer.grounded, isFalse);
    });

    test('RealVoiceService builds deterministic Urdu script and synthesizes WAV file', () async {
      final voice = RealVoiceService();
      final rx1 = await MockPrescriptionReader.loadCachedPrescription(0);
      final plan = RealScheduleEngine().build(rx1);

      final script = voice.describePlanUrdu(plan);
      expect(script, contains('Augmentin'));
      expect(script, contains('فارماسسٹ'));

      final wavBytes = RealVoiceService.wrapPcm16InWavHeader(Uint8List(1600));
      expect(wavBytes.length, equals(1644));
    });
  });
}
