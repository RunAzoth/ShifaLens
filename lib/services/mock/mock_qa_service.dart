import 'dart:typed_data';

import '../../core/models/models.dart';
import '../../core/services/qa_service.dart';

class MockQAService implements QAService {
  @override
  Future<QAAnswer> ask({
    String? text,
    Uint8List? audioBytes,
    required DailyPlan plan,
  }) async {
    return const QAAnswer(
      answer: Bilingual(
        ur: 'براہِ کرم اپنے فارماسسٹ یا ڈاکٹر سے مشورہ کریں۔',
        en: 'Please ask your pharmacist or doctor.',
      ),
      grounded: false,
      escalateToPharmacist: true,
      sources: [],
    );
  }
}
