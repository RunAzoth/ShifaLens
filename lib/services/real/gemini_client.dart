import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../../app/config.dart';

enum GeminiErrorType {
  timeout,
  network,
  quota,
  safety,
  invalidJson,
  unconfigured,
  unknown,
}

class GeminiClientException implements Exception {
  final GeminiErrorType type;
  final String message;
  final Object? cause;

  const GeminiClientException({
    required this.type,
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'GeminiClientException($type): $message';
}

/// Top-level isolate function to resize/compress images to max 1600px JPEG q80.
Uint8List _resizeAndCompressJpegSync(Uint8List inputBytes) {
  final decoded = img.decodeImage(inputBytes);
  if (decoded == null) {
    return inputBytes;
  }

  img.Image processed = decoded;
  const maxDim = 1600;
  if (decoded.width > maxDim || decoded.height > maxDim) {
    if (decoded.width >= decoded.height) {
      processed = img.copyResize(decoded, width: maxDim);
    } else {
      processed = img.copyResize(decoded, height: maxDim);
    }
  }

  return Uint8List.fromList(img.encodeJpg(processed, quality: 80));
}

class GeminiClient {
  final String modelName;
  final double temperature;
  final Duration timeout;
  final int maxRetries;
  final http.Client _httpClient;

  static const String _dartDefineApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
  );

  GeminiClient({
    this.modelName = kGeminiModel,
    this.temperature = 0.1,
    this.timeout = const Duration(seconds: 25),
    this.maxRetries = 1,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Resizes and compresses an image to max 1600px JPEG (quality 80) in a background isolate.
  Future<Uint8List> prepareImageJpeg(Uint8List rawBytes) async {
    if (rawBytes.isEmpty) return rawBytes;
    try {
      return await Isolate.run(() => _resizeAndCompressJpegSync(rawBytes));
    } catch (_) {
      return rawBytes;
    }
  }

  /// Sends a multimodal or text prompt to Gemini and parses the structured JSON response.
  /// Retries once on timeout or transient failure. Throws [GeminiClientException] on failure.
  Future<Map<String, dynamic>> generateStructuredJson({
    required String systemInstruction,
    required String promptText,
    required Schema responseSchema,
    List<({String mimeType, Uint8List bytes})> mediaParts = const [],
  }) async {
    final clampedTemp = temperature.clamp(0.0, 0.2);

    final preparedMedia = <({String mimeType, Uint8List bytes})>[];
    for (final part in mediaParts) {
      if (part.mimeType.startsWith('image/')) {
        final compressed = await prepareImageJpeg(part.bytes);
        preparedMedia.add((mimeType: 'image/jpeg', bytes: compressed));
      } else {
        preparedMedia.add(part);
      }
    }

    GeminiClientException? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final rawJson = await _invokeOnce(
          systemInstruction: systemInstruction,
          promptText: promptText,
          responseSchema: responseSchema,
          temperature: clampedTemp,
          mediaParts: preparedMedia,
        ).timeout(timeout);

        final cleaned = _stripMarkdownFences(rawJson);
        final decoded = jsonDecode(cleaned);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is List) {
          return {'items': decoded};
        }
        throw const GeminiClientException(
          type: GeminiErrorType.invalidJson,
          message: 'Model output was not a JSON object.',
        );
      } on TimeoutException catch (e) {
        lastError = GeminiClientException(
          type: GeminiErrorType.timeout,
          message: 'Gemini request timed out after ${timeout.inSeconds}s.',
          cause: e,
        );
      } on GeminiClientException catch (e) {
        lastError = e;
        if (e.type == GeminiErrorType.unconfigured ||
            e.type == GeminiErrorType.safety) {
          break; // Do not retry non-transient configuration/safety errors
        }
      } on FirebaseAIException catch (e) {
        lastError = _mapFirebaseError(e);
      } catch (e) {
        lastError = GeminiClientException(
          type: GeminiErrorType.unknown,
          message: 'Unexpected Gemini error: $e',
          cause: e,
        );
      }
    }

    throw lastError ??
        const GeminiClientException(
          type: GeminiErrorType.unknown,
          message: 'Gemini request failed.',
        );
  }

  Future<String> _invokeOnce({
    required String systemInstruction,
    required String promptText,
    required Schema responseSchema,
    required double temperature,
    required List<({String mimeType, Uint8List bytes})> mediaParts,
  }) async {
    final hasFirebaseApp = Firebase.apps.isNotEmpty;
    if (hasFirebaseApp) {
      final model = FirebaseAI.googleAI().generativeModel(
        model: modelName,
        systemInstruction: Content.system(systemInstruction),
        generationConfig: GenerationConfig(
          temperature: temperature,
          responseMimeType: 'application/json',
          responseSchema: responseSchema,
        ),
      );

      final parts = <Part>[
        for (final media in mediaParts)
          InlineDataPart(media.mimeType, media.bytes),
        TextPart(promptText),
      ];

      final response = await model.generateContent([Content.multi(parts)]);
      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        throw const GeminiClientException(
          type: GeminiErrorType.invalidJson,
          message: 'Gemini returned an empty response.',
        );
      }
      return text;
    }

    if (_dartDefineApiKey.isNotEmpty) {
      return _invokeRestFallback(
        apiKey: _dartDefineApiKey,
        systemInstruction: systemInstruction,
        promptText: promptText,
        responseSchema: responseSchema,
        temperature: temperature,
        mediaParts: mediaParts,
      );
    }

    throw const GeminiClientException(
      type: GeminiErrorType.unconfigured,
      message:
          'Neither Firebase AI Logic nor --dart-define=GEMINI_API_KEY is configured.',
    );
  }

  Future<String> _invokeRestFallback({
    required String apiKey,
    required String systemInstruction,
    required String promptText,
    required Schema responseSchema,
    required double temperature,
    required List<({String mimeType, Uint8List bytes})> mediaParts,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
    );

    final partsJson = <Map<String, dynamic>>[
      for (final m in mediaParts)
        {
          'inlineData': {
            'mimeType': m.mimeType,
            'data': base64Encode(m.bytes),
          },
        },
      {'text': promptText},
    ];

    final payload = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': partsJson,
        },
      ],
      'generationConfig': {
        'temperature': temperature,
        'responseMimeType': 'application/json',
        'responseSchema': responseSchema.toJson(),
      },
    };

    final response = await _httpClient.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 429) {
      throw const GeminiClientException(
        type: GeminiErrorType.quota,
        message: 'Gemini quota exceeded (HTTP 429).',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GeminiClientException(
        type: GeminiErrorType.network,
        message: 'Gemini REST error HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) {
      throw const GeminiClientException(
        type: GeminiErrorType.safety,
        message: 'No candidates returned by Gemini.',
      );
    }
    final first = candidates.first as Map<String, dynamic>;
    final content = first['content'] as Map<String, dynamic>? ?? const {};
    final parts = content['parts'] as List<dynamic>? ?? const [];
    if (parts.isEmpty) {
      throw const GeminiClientException(
        type: GeminiErrorType.invalidJson,
        message: 'Empty content parts in Gemini response.',
      );
    }
    final text = (parts.first as Map<String, dynamic>)['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw const GeminiClientException(
        type: GeminiErrorType.invalidJson,
        message: 'No text found in Gemini candidate.',
      );
    }
    return text;
  }

  GeminiClientException _mapFirebaseError(FirebaseAIException error) {
    if (error is QuotaExceeded) {
      return GeminiClientException(
        type: GeminiErrorType.quota,
        message: error.message,
        cause: error,
      );
    }
    if (error is InvalidApiKey || error is ServiceApiNotEnabled) {
      return GeminiClientException(
        type: GeminiErrorType.unconfigured,
        message: error.message,
        cause: error,
      );
    }
    return GeminiClientException(
      type: GeminiErrorType.network,
      message: error.message,
      cause: error,
    );
  }

  static String _stripMarkdownFences(String raw) {
    var trimmed = raw.trim();
    if (trimmed.startsWith('```')) {
      final firstNewline = trimmed.indexOf('\n');
      if (firstNewline != -1) {
        trimmed = trimmed.substring(firstNewline + 1);
      }
      if (trimmed.endsWith('```')) {
        trimmed = trimmed.substring(0, trimmed.length - 3);
      }
    }
    return trimmed.trim();
  }
}
