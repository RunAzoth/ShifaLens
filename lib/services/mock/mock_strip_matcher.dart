import 'dart:convert';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/services/strip_matcher.dart';

class MockStripMatcher implements StripMatcher {
  final Duration delay;

  MockStripMatcher({this.delay = const Duration(milliseconds: 800)});

  @override
  Future<List<StripMatch>> match(
    List<Uint8List> strips,
    List<MedicineLine> meds,
  ) async {
    await Future<void>.delayed(delay);
    final defaults = await loadCachedStripMatches(meds);
    if (strips.isEmpty) return defaults;

    final results = <StripMatch>[];
    for (var i = 0; i < strips.length && i < 6; i++) {
      if (i < defaults.length) {
        results.add(defaults[i].copyWith(imageIndex: i));
      } else {
        results.add(
          StripMatch(
            imageIndex: i,
            matchedMedicineId: null,
            readText: null,
            confidence: 0.42,
            issue: StripIssue.unreadable,
          ),
        );
      }
    }
    return results;
  }

  static Future<List<StripMatch>> loadCachedStripMatches(
    List<MedicineLine> meds,
  ) async {
    final firstId = meds.isNotEmpty ? meds.first.id : 'rx1_line_1';
    final thirdId = meds.length >= 3
        ? meds[2].id
        : (meds.length >= 2 ? meds[1].id : 'rx1_line_3');

    try {
      final raw = await rootBundle.loadString(
        'assets/demo/cached/strip_matches.json',
      );
      final decoded = jsonDecode(raw) as List<dynamic>;
      final list = decoded
          .map((e) => StripMatch.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (list.length >= 2 && meds.isNotEmpty) {
        list[0] = list[0].copyWith(matchedMedicineId: firstId);
        list[1] = list[1].copyWith(matchedMedicineId: thirdId);
      }
      return list;
    } catch (_) {
      return [
        StripMatch(
          imageIndex: 0,
          matchedMedicineId: firstId,
          readText: 'Augmentin 625mg Co-amoxiclav Tablets GSK',
          confidence: 0.94,
          issue: StripIssue.none,
        ),
        StripMatch(
          imageIndex: 1,
          matchedMedicineId: thirdId,
          readText: 'Risek 40mg Omeprazole Capsules Getz Pharma',
          confidence: 0.91,
          issue: StripIssue.strengthMismatch,
        ),
        const StripMatch(
          imageIndex: 2,
          matchedMedicineId: null,
          readText: 'Brufen 400mg Ibuprofen Tablets Abbott',
          confidence: 0.89,
          issue: StripIssue.notInPrescription,
        ),
      ];
    }
  }
}
