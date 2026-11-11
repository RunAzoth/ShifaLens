import 'package:flutter/foundation.dart';

import 'bilingual.dart';
import 'enums.dart';

@immutable
class DoseEvent {
  final String medicineId;
  final MealSlot slot;
  final MealRelation relation;
  final Bilingual? note;

  const DoseEvent({
    required this.medicineId,
    required this.slot,
    required this.relation,
    this.note,
  });

  DoseEvent copyWith({
    String? medicineId,
    MealSlot? slot,
    MealRelation? relation,
    Bilingual? note,
  }) {
    return DoseEvent(
      medicineId: medicineId ?? this.medicineId,
      slot: slot ?? this.slot,
      relation: relation ?? this.relation,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'medicineId': medicineId,
        'slot': slot.name,
        'relation': relation.name,
        'note': note?.toJson(),
      };

  factory DoseEvent.fromJson(Map<String, dynamic> json) {
    return DoseEvent(
      medicineId: (json['medicineId'] as String?) ?? '',
      slot: MealSlot.values.firstWhere(
        (e) => e.name == json['slot'],
        orElse: () => MealSlot.breakfast,
      ),
      relation: MealRelation.values.firstWhere(
        (e) => e.name == json['relation'],
        orElse: () => MealRelation.after,
      ),
      note: json['note'] != null
          ? Bilingual.fromJson(Map<String, dynamic>.from(json['note'] as Map))
          : null,
    );
  }
}
