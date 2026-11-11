import 'package:flutter/foundation.dart';

import 'dose_event.dart';
import 'duplicate_alert.dart';
import 'food_card.dart';
import 'medicine_line.dart';
import 'side_effect_info.dart';

@immutable
class DailyPlan {
  final String id;
  final String prescriptionId;
  final List<MedicineLine> scheduled;
  final List<MedicineLine> unscheduled;
  final List<DoseEvent> doses;
  final List<DuplicateAlert> duplicates;
  final Map<String, List<FoodCard>> foodCardsByMedicineId;
  final Map<String, SideEffectInfo> sideEffectsByMedicineId;
  final bool ramadan;
  final bool ramadanDoctorApproved;

  const DailyPlan({
    required this.id,
    required this.prescriptionId,
    required this.scheduled,
    required this.unscheduled,
    required this.doses,
    required this.duplicates,
    required this.foodCardsByMedicineId,
    required this.sideEffectsByMedicineId,
    this.ramadan = false,
    this.ramadanDoctorApproved = false,
  });

  DailyPlan copyWith({
    String? id,
    String? prescriptionId,
    List<MedicineLine>? scheduled,
    List<MedicineLine>? unscheduled,
    List<DoseEvent>? doses,
    List<DuplicateAlert>? duplicates,
    Map<String, List<FoodCard>>? foodCardsByMedicineId,
    Map<String, SideEffectInfo>? sideEffectsByMedicineId,
    bool? ramadan,
    bool? ramadanDoctorApproved,
  }) {
    return DailyPlan(
      id: id ?? this.id,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      scheduled: scheduled ?? this.scheduled,
      unscheduled: unscheduled ?? this.unscheduled,
      doses: doses ?? this.doses,
      duplicates: duplicates ?? this.duplicates,
      foodCardsByMedicineId:
          foodCardsByMedicineId ?? this.foodCardsByMedicineId,
      sideEffectsByMedicineId:
          sideEffectsByMedicineId ?? this.sideEffectsByMedicineId,
      ramadan: ramadan ?? this.ramadan,
      ramadanDoctorApproved:
          ramadanDoctorApproved ?? this.ramadanDoctorApproved,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'prescriptionId': prescriptionId,
        'scheduled': scheduled.map((e) => e.toJson()).toList(),
        'unscheduled': unscheduled.map((e) => e.toJson()).toList(),
        'doses': doses.map((e) => e.toJson()).toList(),
        'duplicates': duplicates.map((e) => e.toJson()).toList(),
        'foodCardsByMedicineId': foodCardsByMedicineId.map(
          (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()),
        ),
        'sideEffectsByMedicineId': sideEffectsByMedicineId.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'ramadan': ramadan,
        'ramadanDoctorApproved': ramadanDoctorApproved,
      };

  factory DailyPlan.fromJson(Map<String, dynamic> json) {
    final rawFood =
        json['foodCardsByMedicineId'] as Map<String, dynamic>? ?? const {};
    final rawSide =
        json['sideEffectsByMedicineId'] as Map<String, dynamic>? ?? const {};

    return DailyPlan(
      id: (json['id'] as String?) ?? '',
      prescriptionId: (json['prescriptionId'] as String?) ?? '',
      scheduled: (json['scheduled'] as List<dynamic>? ?? const [])
          .map((e) => MedicineLine.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      unscheduled: (json['unscheduled'] as List<dynamic>? ?? const [])
          .map((e) => MedicineLine.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      doses: (json['doses'] as List<dynamic>? ?? const [])
          .map((e) => DoseEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      duplicates: (json['duplicates'] as List<dynamic>? ?? const [])
          .map(
            (e) => DuplicateAlert.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      foodCardsByMedicineId: rawFood.map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>)
              .map((e) => FoodCard.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
        ),
      ),
      sideEffectsByMedicineId: rawSide.map(
        (key, value) => MapEntry(
          key,
          SideEffectInfo.fromJson(Map<String, dynamic>.from(value as Map)),
        ),
      ),
      ramadan: (json['ramadan'] as bool?) ?? false,
      ramadanDoctorApproved: (json['ramadanDoctorApproved'] as bool?) ?? false,
    );
  }
}
