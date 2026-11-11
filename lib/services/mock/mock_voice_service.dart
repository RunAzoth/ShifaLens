import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../core/models/models.dart';
import '../../core/services/voice_service.dart';

class MockVoiceService implements VoiceService {
  final StreamController<bool> _speakingController =
      StreamController<bool>.broadcast();
  bool _currentlySpeaking = false;

  @override
  Stream<bool> get isSpeaking => _speakingController.stream;

  @override
  Future<void> speak(Bilingual text, {Lang lang = Lang.ur}) async {
    _currentlySpeaking = true;
    _speakingController.add(true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (_currentlySpeaking) {
      _currentlySpeaking = false;
      _speakingController.add(false);
    }
  }

  @override
  Future<void> stop() async {
    _currentlySpeaking = false;
    _speakingController.add(false);
  }

  @override
  Future<File> synthesizeToFile(String textUr) async {
    try {
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/shifalens_plan_urdu.wav');
      await file.writeAsBytes(buildMinimalWavBytes());
      return file;
    } catch (_) {
      return File('shifalens_plan_urdu.wav');
    }
  }

  @override
  String describePlanUrdu(DailyPlan p) {
    final buffer = StringBuffer();
    buffer.writeln('شفا لینز کی جانب سے آپ کی دواؤں کا روزانہ شیڈول:');

    if (p.scheduled.isEmpty) {
      buffer.writeln('اس وقت کوئی دوا تصدیق شدہ شیڈول میں شامل نہیں ہے۔');
    } else {
      for (final med in p.scheduled) {
        final name = med.brandName ?? med.genericName ?? med.rawText;
        final strength = med.strength != null ? ' (${med.strength})' : '';
        final medDoses =
            p.doses.where((d) => d.medicineId == med.id).toList();
        final slotsUr = medDoses.map((d) => _slotUrdu(d.slot)).join('، ');
        final relUr = medDoses.isNotEmpty
            ? _relationUrdu(medDoses.first.relation)
            : 'کھانے کے بعد';
        final daysUr = med.durationDays != null
            ? '، ${med.durationDays} دن تک'
            : '';
        buffer.writeln('• $name$strength: $slotsUr، $relUr لیں$daysUr۔');
      }
    }

    if (p.duplicates.isNotEmpty) {
      for (final dup in p.duplicates) {
        buffer.writeln('• اہم انتباہ: ${dup.message.ur}');
      }
    }

    if (p.unscheduled.isNotEmpty) {
      buffer.writeln(
        '• توجہ: ${p.unscheduled.length} دوا واضح نہیں ہے، اسے شیڈول میں شامل نہیں کیا گیا۔ براہِ کرم اپنے فارماسسٹ سے پوچھیں۔',
      );
    }

    buffer.write(
      'یہ معلومات اے آئی کی مدد سے تیار کی گئی ہیں، استعمال سے پہلے فارماسسٹ سے تصدیق کریں۔',
    );
    return buffer.toString();
  }

  static String _slotUrdu(MealSlot slot) {
    switch (slot) {
      case MealSlot.wakeUp:
        return 'صبح اٹھتے ہی';
      case MealSlot.suhoor:
        return 'سحری میں';
      case MealSlot.breakfast:
        return 'ناشتے میں';
      case MealSlot.midMorning:
        return 'دوپہر سے پہلے';
      case MealSlot.lunch:
        return 'دوپہر کے کھانے میں';
      case MealSlot.afternoon:
        return 'سہ پہر کو';
      case MealSlot.iftar:
        return 'افطار میں';
      case MealSlot.dinner:
        return 'رات کے کھانے میں';
      case MealSlot.bedtime:
        return 'رات سونے سے پہلے';
      case MealSlot.whenNeeded:
        return 'ضرورت کے وقت';
    }
  }

  static String _relationUrdu(MealRelation rel) {
    switch (rel) {
      case MealRelation.before:
        return 'کھانے سے پہلے';
      case MealRelation.withMeal:
        return 'کھانے کے ساتھ';
      case MealRelation.after:
        return 'کھانے کے بعد';
      case MealRelation.emptyStomach:
        return 'خالی پیٹ';
      case MealRelation.anytime:
        return 'مقررہ وقت پر';
    }
  }

  /// Generates a valid 0.5-second 8kHz mono PCM WAV header + soft chime tone
  /// so audio playback and email file attachments always have a valid audio file.
  static Uint8List buildMinimalWavBytes() {
    const sampleRate = 8000;
    const numSamples = 4000; // 0.5s
    const dataSize = numSamples * 2; // 16-bit mono
    final byteData = ByteData(44 + dataSize);

    void writeAscii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        byteData.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    byteData.setUint32(4, 36 + dataSize, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    byteData.setUint32(16, 16, Endian.little); // PCM chunk size
    byteData.setUint16(20, 1, Endian.little); // PCM format
    byteData.setUint16(22, 1, Endian.little); // 1 channel
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    byteData.setUint16(32, 2, Endian.little); // block align
    byteData.setUint16(34, 16, Endian.little); // bits per sample
    writeAscii(36, 'data');
    byteData.setUint32(40, dataSize, Endian.little);

    for (var i = 0; i < numSamples; i++) {
      // Gentle envelope silence/soft tone
      byteData.setInt16(44 + i * 2, 0, Endian.little);
    }

    return byteData.buffer.asUint8List();
  }
}
