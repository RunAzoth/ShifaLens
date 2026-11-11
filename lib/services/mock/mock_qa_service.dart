import 'dart:convert';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/services/qa_service.dart';

class MockQAService implements QAService {
  final Duration delay;

  MockQAService({this.delay = const Duration(milliseconds: 750)});

  static const Bilingual kFixedFallback = Bilingual(
    ur: 'براہِ کرم اپنے فارماسسٹ یا ڈاکٹر سے مشورہ کریں۔',
    en: 'Please ask your pharmacist or doctor.',
  );

  @override
  Future<QAAnswer> ask({
    String? text,
    Uint8List? audioBytes,
    required DailyPlan plan,
  }) async {
    await Future<void>.delayed(delay);

    final q = (text ?? '').toLowerCase();
    final isRedFlag = q.contains('chest pain') ||
        q.contains('breathing') ||
        q.contains('swelling') ||
        q.contains('faint') ||
        q.contains('rash') ||
        q.contains('سینے میں درد') ||
        q.contains('سانس') ||
        q.contains('سوجن') ||
        q.contains('بے ہوش');

    if (isRedFlag) {
      return const QAAnswer(
        answer: Bilingual(
          ur: 'یہ ہنگامی علامت ہو سکتی ہے۔ براہِ کرم فوراً اپنے ڈاکٹر یا قریبی ایمرجنسی سروسز سے رابطہ کریں۔',
          en: 'This may be an emergency symptom. Please contact a doctor or emergency services right now.',
        ),
        grounded: false,
        escalateToPharmacist: true,
        sources: [],
      );
    }

    final needsEscalation = q.contains('stop') ||
        q.contains('skip') ||
        q.contains('double') ||
        q.contains('change dose') ||
        q.contains('diagnos') ||
        q.contains('چھوڑ') ||
        q.contains('بند') ||
        q.contains('خوراک کم') ||
        q.contains('ڈبل');

    return loadCachedQAAnswer(
      escalate: needsEscalation,
      plan: plan,
    );
  }

  static Future<QAAnswer> loadCachedQAAnswer({
    required bool escalate,
    required DailyPlan plan,
  }) async {
    final availableSources = <String>[];
    for (final cards in plan.foodCardsByMedicineId.values) {
      for (final c in cards) {
        availableSources.add(c.id);
      }
    }
    if (availableSources.isEmpty && plan.scheduled.isNotEmpty) {
      availableSources.add(plan.scheduled.first.id);
    }

    try {
      final raw = await rootBundle.loadString(
        'assets/demo/cached/qa_responses.json',
      );
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final key = escalate ? 'escalate' : 'grounded';
      final answer = QAAnswer.fromJson(
        Map<String, dynamic>.from(map[key] as Map),
      );
      if (!escalate && availableSources.isNotEmpty) {
        return answer.copyWith(sources: [availableSources.first]);
      }
      return answer;
    } catch (_) {
      if (escalate) {
        return const QAAnswer(
          answer: Bilingual(
            ur: 'یہ سوال دوا کی خوراک تبدیل کرنے یا روکنے سے متعلق ہے جو محفوظ معلومات میں شامل نہیں۔ براہِ کرم اپنے فارماسسٹ یا ڈاکٹر سے مشورہ کریں۔',
            en: 'This question involves changing or stopping a dose, which requires professional guidance. Please ask your pharmacist or doctor.',
          ),
          grounded: false,
          escalateToPharmacist: true,
          sources: [],
        );
      }
      return QAAnswer(
        answer: const Bilingual(
          ur: 'آگمینٹن کو کھانے کے ساتھ یا کھانے کے فوراً بعد لیں تاکہ پیٹ خراب نہ ہو۔ رائزک ناشتے سے 30 منٹ پہلے خالی پیٹ لیں۔',
          en: 'Take Augmentin with or right after a meal to reduce stomach upset. Take Risek 30 minutes before breakfast on an empty stomach.',
        ),
        grounded: true,
        escalateToPharmacist: false,
        sources: availableSources.isNotEmpty
            ? [availableSources.first]
            : const ['food_amox_clav_1'],
      );
    }
  }
}
