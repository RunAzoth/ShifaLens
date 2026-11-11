import 'package:flutter/foundation.dart';

import 'enums.dart';

@immutable
class StripMatch {
  final int imageIndex;
  final String? matchedMedicineId;
  final String? readText;
  final double confidence;
  final StripIssue issue;

  const StripMatch({
    required this.imageIndex,
    this.matchedMedicineId,
    this.readText,
    required this.confidence,
    required this.issue,
  });

  StripMatch copyWith({
    int? imageIndex,
    String? matchedMedicineId,
    String? readText,
    double? confidence,
    StripIssue? issue,
  }) {
    return StripMatch(
      imageIndex: imageIndex ?? this.imageIndex,
      matchedMedicineId: matchedMedicineId ?? this.matchedMedicineId,
      readText: readText ?? this.readText,
      confidence: confidence ?? this.confidence,
      issue: issue ?? this.issue,
    );
  }

  Map<String, dynamic> toJson() => {
        'imageIndex': imageIndex,
        'matchedMedicineId': matchedMedicineId,
        'readText': readText,
        'confidence': confidence,
        'issue': issue.name,
      };

  factory StripMatch.fromJson(Map<String, dynamic> json) {
    return StripMatch(
      imageIndex: (json['imageIndex'] as num?)?.toInt() ?? 0,
      matchedMedicineId: json['matchedMedicineId'] as String?,
      readText: json['readText'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      issue: StripIssue.values.firstWhere(
        (e) => e.name == json['issue'],
        orElse: () => StripIssue.unreadable,
      ),
    );
  }
}
