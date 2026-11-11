import 'package:flutter/foundation.dart';

import 'enums.dart';

@immutable
class MealTimes {
  final Map<MealSlot, String> hhmm;

  const MealTimes({
    required this.hhmm,
  });

  factory MealTimes.defaults() {
    return const MealTimes(
      hhmm: {
        MealSlot.wakeUp: '07:00',
        MealSlot.breakfast: '08:30',
        MealSlot.midMorning: '11:00',
        MealSlot.lunch: '13:30',
        MealSlot.afternoon: '16:30',
        MealSlot.dinner: '20:00',
        MealSlot.bedtime: '22:30',
        MealSlot.suhoor: '04:30',
        MealSlot.iftar: '18:30',
      },
    );
  }

  MealTimes copyWith({
    Map<MealSlot, String>? hhmm,
  }) {
    return MealTimes(
      hhmm: hhmm ?? this.hhmm,
    );
  }

  Map<String, dynamic> toJson() => {
        'hhmm': hhmm.map((key, value) => MapEntry(key.name, value)),
      };

  factory MealTimes.fromJson(Map<String, dynamic> json) {
    final raw = json['hhmm'] as Map<String, dynamic>? ?? const {};
    final map = <MealSlot, String>{};
    for (final entry in raw.entries) {
      final slot = MealSlot.values.firstWhere(
        (e) => e.name == entry.key,
        orElse: () => MealSlot.breakfast,
      );
      map[slot] = entry.value.toString();
    }
    return MealTimes(hhmm: map.isEmpty ? MealTimes.defaults().hhmm : map);
  }
}
