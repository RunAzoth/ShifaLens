import 'package:flutter/foundation.dart';

import 'bilingual.dart';

@immutable
class DuplicateAlert {
  final String id;
  final bool sameGeneric;
  final String label;
  final List<String> medicineIds;
  final Bilingual message;

  const DuplicateAlert({
    required this.id,
    required this.sameGeneric,
    required this.label,
    required this.medicineIds,
    required this.message,
  });

  DuplicateAlert copyWith({
    String? id,
    bool? sameGeneric,
    String? label,
    List<String>? medicineIds,
    Bilingual? message,
  }) {
    return DuplicateAlert(
      id: id ?? this.id,
      sameGeneric: sameGeneric ?? this.sameGeneric,
      label: label ?? this.label,
      medicineIds: medicineIds ?? this.medicineIds,
      message: message ?? this.message,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sameGeneric': sameGeneric,
        'label': label,
        'medicineIds': medicineIds,
        'message': message.toJson(),
      };

  factory DuplicateAlert.fromJson(Map<String, dynamic> json) {
    return DuplicateAlert(
      id: (json['id'] as String?) ?? '',
      sameGeneric: (json['sameGeneric'] as bool?) ?? true,
      label: (json['label'] as String?) ?? '',
      medicineIds: (json['medicineIds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      message: json['message'] != null
          ? Bilingual.fromJson(
              Map<String, dynamic>.from(json['message'] as Map),
            )
          : const Bilingual(ur: '', en: ''),
    );
  }
}
