import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'bilingual.dart';

@immutable
class PlateGuide {
  final Bilingual title;
  final Uint8List imageBytes;
  final List<Bilingual> tips;

  const PlateGuide({
    required this.title,
    required this.imageBytes,
    required this.tips,
  });

  PlateGuide copyWith({
    Bilingual? title,
    Uint8List? imageBytes,
    List<Bilingual>? tips,
  }) {
    return PlateGuide(
      title: title ?? this.title,
      imageBytes: imageBytes ?? this.imageBytes,
      tips: tips ?? this.tips,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title.toJson(),
        'imageBytes': base64Encode(imageBytes),
        'tips': tips.map((e) => e.toJson()).toList(),
      };

  factory PlateGuide.fromJson(Map<String, dynamic> json) {
    return PlateGuide(
      title: json['title'] != null
          ? Bilingual.fromJson(Map<String, dynamic>.from(json['title'] as Map))
          : const Bilingual(ur: '', en: ''),
      imageBytes: json['imageBytes'] is String
          ? base64Decode(json['imageBytes'] as String)
          : Uint8List(0),
      tips: (json['tips'] as List<dynamic>? ?? const [])
          .map((e) => Bilingual.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
