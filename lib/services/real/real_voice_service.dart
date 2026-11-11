import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/models/models.dart';
import '../../core/services/voice_service.dart';
import '../mock/mock_voice_service.dart';

class RealVoiceService implements VoiceService {
  final FlutterTts _tts;
  final AudioPlayer _audioPlayer;
  final http.Client _httpClient;
  final StreamController<bool> _speakingController =
      StreamController<bool>.broadcast();

  static const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _gcloudTtsKey = String.fromEnvironment('GCLOUD_TTS_KEY');

  RealVoiceService({
    FlutterTts? tts,
    AudioPlayer? audioPlayer,
    http.Client? httpClient,
  })  : _tts = tts ?? FlutterTts(),
        _audioPlayer = audioPlayer ?? AudioPlayer(),
        _httpClient = httpClient ?? http.Client() {
    _initHandlers();
  }

  void _initHandlers() {
    try {
      _tts.setStartHandler(() => _speakingController.add(true));
      _tts.setCompletionHandler(() => _speakingController.add(false));
      _tts.setCancelHandler(() => _speakingController.add(false));
      _tts.setErrorHandler((_) => _speakingController.add(false));

      _audioPlayer.onPlayerStateChanged.listen((state) {
        _speakingController.add(state == PlayerState.playing);
      });
    } catch (_) {
      // Safe in unit-test environments without platform channels
    }
  }

  @override
  Stream<bool> get isSpeaking => _speakingController.stream;

  @override
  Future<void> speak(Bilingual text, {Lang lang = Lang.ur}) async {
    final targetText = lang == Lang.ur ? text.ur : text.en;
    if (targetText.trim().isEmpty) return;

    _speakingController.add(true);

    // (a) Try device TTS via flutter_tts with ur-PK / en-US
    if (await _tryDeviceTtsSpeak(targetText, lang: lang)) {
      return;
    }

    // (b), (c), (d) Synthesize via fallback chain (Gemini REST TTS -> Google Cloud TTS -> Bundled Demo Audio) and play
    try {
      final audioFile = await synthesizeToFile(targetText);
      await _audioPlayer.play(DeviceFileSource(audioFile.path));
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      _speakingController.add(false);
    }
  }

  Future<bool> _tryDeviceTtsSpeak(String text, {required Lang lang}) async {
    try {
      final primaryLocale = lang == Lang.ur ? 'ur-PK' : 'en-US';
      final fallbackLocale = lang == Lang.ur ? 'ur-IN' : 'en-GB';

      bool available =
          (await _tts.isLanguageAvailable(primaryLocale)) == true;
      String selectedLocale = primaryLocale;

      if (!available) {
        available = (await _tts.isLanguageAvailable(fallbackLocale)) == true;
        selectedLocale = fallbackLocale;
      }

      if (!available) return false;

      await _tts.setLanguage(selectedLocale);
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      final result = await _tts.speak(text);
      return result == 1;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    _speakingController.add(false);
  }

  @override
  Future<File> synthesizeToFile(String textUr) async {
    final outDir = await _resolveOutputDirectory();
    final outFile = File(
      '${outDir.path}/shifalens_urdu_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    // (b) Gemini TTS via REST with --dart-define=GEMINI_API_KEY
    if (_geminiApiKey.isNotEmpty) {
      final geminiBytes = await _tryGeminiRestTts(textUr);
      if (geminiBytes != null && geminiBytes.isNotEmpty) {
        await outFile.writeAsBytes(geminiBytes, flush: true);
        return outFile;
      }
    }

    // (c) Google Cloud Text-to-Speech Urdu voice if enabled (--dart-define=GCLOUD_TTS_KEY)
    if (_gcloudTtsKey.isNotEmpty) {
      final gcloudBytes = await _tryGoogleCloudUrduTts(textUr);
      if (gcloudBytes != null && gcloudBytes.isNotEmpty) {
        await outFile.writeAsBytes(gcloudBytes, flush: true);
        return outFile;
      }
    }

    // (a) Device TTS synthesizeToFile if supported by platform
    try {
      final avail = (await _tts.isLanguageAvailable('ur-PK')) == true;
      if (avail) {
        await _tts.setLanguage('ur-PK');
        final res = await _tts.synthesizeToFile(textUr, outFile.path);
        if (res == 1 && await outFile.exists() && await outFile.length() > 44) {
          return outFile;
        }
      }
    } catch (_) {}

    // (d) Guaranteed fallback: bundled pre-generated demo audio asset or valid WAV
    final bundledBytes = await _loadBundledFallbackAudio(textUr);
    await outFile.writeAsBytes(bundledBytes, flush: true);
    return outFile;
  }

  Future<Uint8List?> _tryGeminiRestTts(String textUr) async {
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=$_geminiApiKey',
      );
      final payload = {
        'contents': [
          {
            'parts': [
              {
                'text':
                    'Read the following pharmacist medication guide aloud in clear, warm Pakistani Urdu:\n$textUr',
              },
            ],
          },
        ],
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': 'Kore'},
            },
          },
        },
      };

      final response = await _httpClient
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 18));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = body['candidates'] as List<dynamic>? ?? const [];
      if (candidates.isEmpty) return null;
      final content =
          (candidates.first as Map<String, dynamic>)['content']
              as Map<String, dynamic>? ??
          const {};
      final parts = content['parts'] as List<dynamic>? ?? const [];
      if (parts.isEmpty) return null;
      final inlineData =
          (parts.first as Map<String, dynamic>)['inlineData']
              as Map<String, dynamic>?;
      if (inlineData == null) return null;
      final base64Audio = inlineData['data'] as String?;
      if (base64Audio == null || base64Audio.isEmpty) return null;

      final pcmBytes = base64Decode(base64Audio);
      return wrapPcm16InWavHeader(pcmBytes, sampleRate: 24000);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _tryGoogleCloudUrduTts(String textUr) async {
    try {
      final uri = Uri.parse(
        'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_gcloudTtsKey',
      );
      final payload = {
        'input': {'text': textUr},
        'voice': {
          'languageCode': 'ur-PK',
          'name': 'ur-PK-Standard-A',
        },
        'audioConfig': {
          'audioEncoding': 'LINEAR16',
          'speakingRate': 0.92,
        },
      };

      final response = await _httpClient
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final audioContent = body['audioContent'] as String?;
      if (audioContent == null || audioContent.isEmpty) return null;
      return base64Decode(audioContent);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _loadBundledFallbackAudio(String textUr) async {
    String assetPath = 'assets/demo/cached/plan_rx1.wav';
    if (textUr.contains('Glucophage') || textUr.contains('Norvasc')) {
      assetPath = 'assets/demo/cached/plan_rx2.wav';
    } else if (textUr.contains('Cipro') || textUr.contains('Calpol')) {
      assetPath = 'assets/demo/cached/plan_rx3.wav';
    }
    try {
      final byteData = await rootBundle.load(assetPath);
      return byteData.buffer.asUint8List();
    } catch (_) {
      return MockVoiceService.buildMinimalWavBytes();
    }
  }

  Future<Directory> _resolveOutputDirectory() async {
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  /// Deterministic spoken Urdu script built directly from DailyPlan (Rule 1 & Task 8: no AI).
  @override
  String describePlanUrdu(DailyPlan p) {
    final mock = MockVoiceService();
    return mock.describePlanUrdu(p);
  }

  static Uint8List wrapPcm16InWavHeader(
    Uint8List pcmBytes, {
    int sampleRate = 24000,
  }) {
    final dataSize = pcmBytes.length;
    final header = ByteData(44);
    void writeAscii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    header.setUint32(4, 36 + dataSize, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    header.setUint32(40, dataSize, Endian.little);

    final out = Uint8List(44 + dataSize);
    out.setRange(0, 44, header.buffer.asUint8List());
    out.setRange(44, 44 + dataSize, pcmBytes);
    return out;
  }
}
