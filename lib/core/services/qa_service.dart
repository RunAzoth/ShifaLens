import 'dart:typed_data';

import '../models/models.dart';

abstract class QAService {
  Future<QAAnswer> ask({
    String? text,
    Uint8List? audioBytes,
    required DailyPlan plan,
  });
}
