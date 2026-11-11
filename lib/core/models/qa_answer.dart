import 'package:flutter/foundation.dart';

import 'bilingual.dart';

@immutable
class QAAnswer {
  final Bilingual answer;
  final bool grounded;
  final bool escalateToPharmacist;
  final List<String> sources;

  const QAAnswer({
    required this.answer,
    required this.grounded,
    required this.escalateToPharmacist,
    required this.sources,
  });

  QAAnswer copyWith({
    Bilingual? answer,
    bool? grounded,
    bool? escalateToPharmacist,
    List<String>? sources,
  }) {
    return QAAnswer(
      answer: answer ?? this.answer,
      grounded: grounded ?? this.grounded,
      escalateToPharmacist: escalateToPharmacist ?? this.escalateToPharmacist,
      sources: sources ?? this.sources,
    );
  }

  Map<String, dynamic> toJson() => {
        'answer': answer.toJson(),
        'grounded': grounded,
        'escalateToPharmacist': escalateToPharmacist,
        'sources': sources,
      };

  factory QAAnswer.fromJson(Map<String, dynamic> json) {
    return QAAnswer(
      answer: json['answer'] != null
          ? Bilingual.fromJson(Map<String, dynamic>.from(json['answer'] as Map))
          : const Bilingual(ur: '', en: ''),
      grounded: (json['grounded'] as bool?) ?? false,
      escalateToPharmacist: (json['escalateToPharmacist'] as bool?) ?? true,
      sources: (json['sources'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
