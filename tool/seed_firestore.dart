import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// Standalone pure-Dart CLI seeder script (`dart run tool/seed_firestore.dart`).
/// 1. Generates the compressed flat Pakistani plate illustration PNG (< 300KB),
///    base64-encodes it, and updates `assets/data/plate_guide.json`.
/// 2. If `--project=<PROJECT_ID>` and `--token=<BEARER_TOKEN>` (or `FIREBASE_ACCESS_TOKEN`)
///    are supplied, uploads `brands_generics`, `food_med`, `side_effects`, and
///    `plate_guide/main` directly to Cloud Firestore.
Future<void> main(List<String> args) async {
  stdout.writeln('=== ShifaLens Knowledge & Plate Guide Seeder ===');

  // 1. Generate and embed the <300KB PNG plate illustration into assets/data/plate_guide.json
  final pngBytes = _buildFlatPlateIllustrationPng();
  final sizeKb = (pngBytes.length / 1024).toStringAsFixed(1);
  stdout.writeln(
    'Generated flat Pakistani plate illustration PNG: ${pngBytes.length} bytes ($sizeKb KB, well under 300 KB limit).',
  );

  final plateFile = File('assets/data/plate_guide.json');
  if (plateFile.existsSync()) {
    final map =
        jsonDecode(plateFile.readAsStringSync()) as Map<String, dynamic>;
    map['imageBase64'] = base64Encode(pngBytes);
    plateFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(map),
    );
    stdout.writeln('Updated assets/data/plate_guide.json with imageBase64.');
  }

  // 2. Verify all local curated JSON files
  final brands =
      jsonDecode(File('assets/data/brands_generics.json').readAsStringSync())
          as List<dynamic>;
  final foodCards =
      jsonDecode(File('assets/data/food_med.json').readAsStringSync())
          as List<dynamic>;
  final sideEffects =
      jsonDecode(File('assets/data/side_effects.json').readAsStringSync())
          as List<dynamic>;
  final plateGuide =
      jsonDecode(plateFile.readAsStringSync()) as Map<String, dynamic>;

  stdout.writeln(
    'Verified local JSON tables: '
    '${brands.length} brands, '
    '${foodCards.length} food_med cards, '
    '${sideEffects.length} side_effects records, '
    '1 plate_guide/main document.',
  );

  final projectId = _argValue(args, '--project') ??
      Platform.environment['FIREBASE_PROJECT_ID'] ??
      'madlab-9b032';
  final token = _argValue(args, '--token') ??
      Platform.environment['FIREBASE_ACCESS_TOKEN'];

  if (token == null || token.isEmpty) {
    stdout.writeln(
      'Note: No --token or FIREBASE_ACCESS_TOKEN provided; local assets updated and ready for offline fallback.\n'
      'To push to Cloud Firestore ($projectId), run:\n'
      '  dart run tool/seed_firestore.dart --project=$projectId --token=<OAUTH_ACCESS_TOKEN>',
    );
    return;
  }

  final client = http.Client();
  try {
    for (final item in brands) {
      final map = Map<String, dynamic>.from(item as Map);
      final docId = (map['brand'] as String)
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      await _upsertFirestoreDoc(
        client: client,
        projectId: projectId,
        token: token,
        collection: 'brands_generics',
        docId: docId,
        data: map,
      );
    }

    for (final item in foodCards) {
      final map = Map<String, dynamic>.from(item as Map);
      final docId = map['id'] as String;
      await _upsertFirestoreDoc(
        client: client,
        projectId: projectId,
        token: token,
        collection: 'food_med',
        docId: docId,
        data: map,
      );
    }

    for (final item in sideEffects) {
      final map = Map<String, dynamic>.from(item as Map);
      final docId = (map['generic'] as String)
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      await _upsertFirestoreDoc(
        client: client,
        projectId: projectId,
        token: token,
        collection: 'side_effects',
        docId: docId,
        data: map,
      );
    }

    await _upsertFirestoreDoc(
      client: client,
      projectId: projectId,
      token: token,
      collection: 'plate_guide',
      docId: 'main',
      data: plateGuide,
    );

    stdout.writeln('Successfully seeded Cloud Firestore project "$projectId"!');
  } finally {
    client.close();
  }
}

Uint8List _buildFlatPlateIllustrationPng() {
  final canvas = img.Image(width: 280, height: 280);
  img.fill(canvas, color: img.ColorRgb8(248, 246, 240));
  img.fillCircle(
    canvas,
    x: 140,
    y: 140,
    radius: 124,
    color: img.ColorRgb8(13, 115, 119),
  );
  img.fillCircle(
    canvas,
    x: 140,
    y: 140,
    radius: 112,
    color: img.ColorRgb8(255, 255, 255),
  );
  // Left half: Sabzi & Salad
  img.fillCircle(
    canvas,
    x: 92,
    y: 140,
    radius: 52,
    color: img.ColorRgb8(76, 175, 80),
  );
  // Top-right quarter: Daal / Chana
  img.fillCircle(
    canvas,
    x: 182,
    y: 98,
    radius: 38,
    color: img.ColorRgb8(230, 161, 45),
  );
  // Bottom-right quarter: Whole-wheat Roti
  img.fillCircle(
    canvas,
    x: 182,
    y: 182,
    radius: 40,
    color: img.ColorRgb8(210, 170, 115),
  );
  img.drawLine(
    canvas,
    x1: 140,
    y1: 28,
    x2: 140,
    y2: 252,
    color: img.ColorRgb8(13, 115, 119),
    thickness: 3,
  );
  img.drawLine(
    canvas,
    x1: 140,
    y1: 140,
    x2: 252,
    y2: 140,
    color: img.ColorRgb8(13, 115, 119),
    thickness: 3,
  );
  return Uint8List.fromList(img.encodePng(canvas, level: 6));
}

String? _argValue(List<String> args, String prefix) {
  for (final arg in args) {
    if (arg.startsWith('$prefix=')) {
      return arg.substring(prefix.length + 1);
    }
  }
  return null;
}

Future<void> _upsertFirestoreDoc({
  required http.Client client,
  required String projectId,
  required String token,
  required String collection,
  required String docId,
  required Map<String, dynamic> data,
}) async {
  final uri = Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collection/$docId',
  );
  final fields = <String, dynamic>{};
  data.forEach((key, value) {
    fields[key] = _toFirestoreValue(value);
  });

  final response = await client.patch(
    uri,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'fields': fields}),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    stderr.writeln(
      'Failed to seed $collection/$docId (${response.statusCode}): ${response.body}',
    );
  }
}

Map<String, dynamic> _toFirestoreValue(dynamic value) {
  if (value == null) return {'nullValue': null};
  if (value is bool) return {'booleanValue': value};
  if (value is int) return {'integerValue': value.toString()};
  if (value is double) return {'doubleValue': value};
  if (value is String) return {'stringValue': value};
  if (value is List) {
    return {
      'arrayValue': {
        'values': value.map(_toFirestoreValue).toList(),
      },
    };
  }
  if (value is Map) {
    final fields = <String, dynamic>{};
    value.forEach((k, v) {
      fields[k.toString()] = _toFirestoreValue(v);
    });
    return {
      'mapValue': {'fields': fields},
    };
  }
  return {'stringValue': value.toString()};
}
