import 'package:flutter/foundation.dart';

import 'enums.dart';

@immutable
class Bilingual {
  final String ur;
  final String en;

  const Bilingual({
    required this.ur,
    required this.en,
  });

  String forLang(Lang lang) => lang == Lang.ur ? ur : en;

  Bilingual copyWith({
    String? ur,
    String? en,
  }) {
    return Bilingual(
      ur: ur ?? this.ur,
      en: en ?? this.en,
    );
  }

  Map<String, dynamic> toJson() => {
        'ur': ur,
        'en': en,
      };

  factory Bilingual.fromJson(Map<String, dynamic> json) {
    return Bilingual(
      ur: (json['ur'] as String?) ?? '',
      en: (json['en'] as String?) ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bilingual &&
          runtimeType == other.runtimeType &&
          ur == other.ur &&
          en == other.en;

  @override
  int get hashCode => Object.hash(ur, en);

  @override
  String toString() => 'Bilingual(ur: $ur, en: $en)';
}
