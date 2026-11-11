import 'package:flutter/foundation.dart';

import 'medicine_line.dart';

@immutable
class Prescription {
  final String id;
  final List<MedicineLine> lines;
  final DateTime createdAt;
  final bool synthetic;

  const Prescription({
    required this.id,
    required this.lines,
    required this.createdAt,
    this.synthetic = true,
  });

  Prescription copyWith({
    String? id,
    List<MedicineLine>? lines,
    DateTime? createdAt,
    bool? synthetic,
  }) {
    return Prescription(
      id: id ?? this.id,
      lines: lines ?? this.lines,
      createdAt: createdAt ?? this.createdAt,
      synthetic: synthetic ?? this.synthetic,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lines': lines.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'synthetic': synthetic,
      };

  factory Prescription.fromJson(Map<String, dynamic> json) {
    return Prescription(
      id: (json['id'] as String?) ?? '',
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .map((e) => MedicineLine.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      synthetic: (json['synthetic'] as bool?) ?? true,
    );
  }
}
