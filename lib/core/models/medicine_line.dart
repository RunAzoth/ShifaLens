import 'package:flutter/foundation.dart';

@immutable
class MedicineLine {
  final String id;
  final String rawText;
  final String? brandName;
  final String? genericName;
  final String? strength;
  final String? form;
  final String? frequencyRaw;
  final String? timingNote;
  final int? durationDays;
  final Map<String, double> fieldConfidence;
  final bool needsPharmacist;
  final bool confirmed;
  final bool isManual;
  final int identityIndex;

  const MedicineLine({
    required this.id,
    required this.rawText,
    this.brandName,
    this.genericName,
    this.strength,
    this.form,
    this.frequencyRaw,
    this.timingNote,
    this.durationDays,
    this.fieldConfidence = const {},
    this.needsPharmacist = false,
    this.confirmed = false,
    this.isManual = false,
    this.identityIndex = 0,
  });

  MedicineLine copyWith({
    String? id,
    String? rawText,
    String? brandName,
    String? genericName,
    String? strength,
    String? form,
    String? frequencyRaw,
    String? timingNote,
    int? durationDays,
    Map<String, double>? fieldConfidence,
    bool? needsPharmacist,
    bool? confirmed,
    bool? isManual,
    int? identityIndex,
  }) {
    return MedicineLine(
      id: id ?? this.id,
      rawText: rawText ?? this.rawText,
      brandName: brandName ?? this.brandName,
      genericName: genericName ?? this.genericName,
      strength: strength ?? this.strength,
      form: form ?? this.form,
      frequencyRaw: frequencyRaw ?? this.frequencyRaw,
      timingNote: timingNote ?? this.timingNote,
      durationDays: durationDays ?? this.durationDays,
      fieldConfidence: fieldConfidence ?? this.fieldConfidence,
      needsPharmacist: needsPharmacist ?? this.needsPharmacist,
      confirmed: confirmed ?? this.confirmed,
      isManual: isManual ?? this.isManual,
      identityIndex: identityIndex ?? this.identityIndex,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rawText': rawText,
        'brandName': brandName,
        'genericName': genericName,
        'strength': strength,
        'form': form,
        'frequencyRaw': frequencyRaw,
        'timingNote': timingNote,
        'durationDays': durationDays,
        'fieldConfidence': fieldConfidence,
        'needsPharmacist': needsPharmacist,
        'confirmed': confirmed,
        'isManual': isManual,
        'identityIndex': identityIndex,
      };

  factory MedicineLine.fromJson(Map<String, dynamic> json) {
    final rawConf = json['fieldConfidence'] as Map<String, dynamic>? ?? const {};
    return MedicineLine(
      id: (json['id'] as String?) ?? '',
      rawText: (json['rawText'] as String?) ?? '',
      brandName: json['brandName'] as String?,
      genericName: json['genericName'] as String?,
      strength: json['strength'] as String?,
      form: json['form'] as String?,
      frequencyRaw: json['frequencyRaw'] as String?,
      timingNote: json['timingNote'] as String?,
      durationDays: (json['durationDays'] as num?)?.toInt(),
      fieldConfidence: rawConf.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      needsPharmacist: (json['needsPharmacist'] as bool?) ?? false,
      confirmed: (json['confirmed'] as bool?) ?? false,
      isManual: (json['isManual'] as bool?) ?? false,
      identityIndex: (json['identityIndex'] as num?)?.toInt() ?? 0,
    );
  }
}
