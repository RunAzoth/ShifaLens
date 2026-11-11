import 'package:flutter/foundation.dart';

import 'bilingual.dart';
import 'enums.dart';

@immutable
class FoodCard {
  final String id;
  final String generic;
  final FoodCardType type;
  final String iconKey;
  final Bilingual title;
  final Bilingual body;
  final bool reviewed;

  const FoodCard({
    required this.id,
    required this.generic,
    required this.type,
    required this.iconKey,
    required this.title,
    required this.body,
    required this.reviewed,
  });

  FoodCard copyWith({
    String? id,
    String? generic,
    FoodCardType? type,
    String? iconKey,
    Bilingual? title,
    Bilingual? body,
    bool? reviewed,
  }) {
    return FoodCard(
      id: id ?? this.id,
      generic: generic ?? this.generic,
      type: type ?? this.type,
      iconKey: iconKey ?? this.iconKey,
      title: title ?? this.title,
      body: body ?? this.body,
      reviewed: reviewed ?? this.reviewed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'generic': generic,
        'type': type.name,
        'iconKey': iconKey,
        'title': title.toJson(),
        'body': body.toJson(),
        'reviewed': reviewed,
      };

  factory FoodCard.fromJson(Map<String, dynamic> json) {
    return FoodCard(
      id: (json['id'] as String?) ?? '',
      generic: (json['generic'] as String?) ?? '',
      type: FoodCardType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => FoodCardType.takeWithFood,
      ),
      iconKey: (json['iconKey'] as String?) ?? 'food',
      title: json['title'] != null
          ? Bilingual.fromJson(Map<String, dynamic>.from(json['title'] as Map))
          : const Bilingual(ur: '', en: ''),
      body: json['body'] != null
          ? Bilingual.fromJson(Map<String, dynamic>.from(json['body'] as Map))
          : const Bilingual(ur: '', en: ''),
      reviewed: (json['reviewed'] as bool?) ?? false,
    );
  }
}
