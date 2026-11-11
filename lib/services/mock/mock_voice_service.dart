import 'dart:async';
import 'dart:io';

import '../../core/models/models.dart';
import '../../core/services/voice_service.dart';

class MockVoiceService implements VoiceService {
  final StreamController<bool> _speakingController =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get isSpeaking => _speakingController.stream;

  @override
  Future<void> speak(Bilingual text, {Lang lang = Lang.ur}) async {
    _speakingController.add(true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _speakingController.add(false);
  }

  @override
  Future<void> stop() async {
    _speakingController.add(false);
  }

  @override
  Future<File> synthesizeToFile(String textUr) async {
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/shifalens_voice_mock.mp3');
    if (!await file.exists()) {
      await file.writeAsBytes(const <int>[]);
    }
    return file;
  }

  @override
  String describePlanUrdu(DailyPlan p) {
    return 'آپ کے نسخے میں کل ${p.scheduled.length} دوائیں شیڈول ہیں اور ${p.unscheduled.length} دواؤں کے لیے فارماسسٹ سے مشورہ ضروری ہے۔';
  }
}
