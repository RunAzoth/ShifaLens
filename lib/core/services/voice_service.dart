import 'dart:io';

import '../models/models.dart';

abstract class VoiceService {
  Future<void> speak(Bilingual text, {Lang lang = Lang.ur});
  Future<void> stop();
  Future<File> synthesizeToFile(String textUr);
  Stream<bool> get isSpeaking;
  String describePlanUrdu(DailyPlan p);
}
