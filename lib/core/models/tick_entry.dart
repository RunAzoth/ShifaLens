import 'package:flutter/foundation.dart';

@immutable
class TickEntry {
  final String doseKey;
  final String date;
  final bool taken;
  final DateTime at;

  const TickEntry({
    required this.doseKey,
    required this.date,
    required this.taken,
    required this.at,
  });

  TickEntry copyWith({
    String? doseKey,
    String? date,
    bool? taken,
    DateTime? at,
  }) {
    return TickEntry(
      doseKey: doseKey ?? this.doseKey,
      date: date ?? this.date,
      taken: taken ?? this.taken,
      at: at ?? this.at,
    );
  }

  Map<String, dynamic> toJson() => {
        'doseKey': doseKey,
        'date': date,
        'taken': taken,
        'at': at.toIso8601String(),
      };

  factory TickEntry.fromJson(Map<String, dynamic> json) {
    return TickEntry(
      doseKey: (json['doseKey'] as String?) ?? '',
      date: (json['date'] as String?) ?? '',
      taken: (json['taken'] as bool?) ?? false,
      at: json['at'] != null
          ? DateTime.parse(json['at'] as String)
          : DateTime.now(),
    );
  }
}
