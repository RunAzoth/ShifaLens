import 'package:flutter/foundation.dart';

import 'bilingual.dart';

@immutable
class SideEffectInfo {
  final String generic;
  final Bilingual common;
  final List<Bilingual> callDoctorIf;
  final bool reviewed;

  const SideEffectInfo({
    required this.generic,
    required this.common,
    required this.callDoctorIf,
    required this.reviewed,
  });

  SideEffectInfo copyWith({
    String? generic,
    Bilingual? common,
    List<Bilingual>? callDoctorIf,
    bool? reviewed,
  }) {
    return SideEffectInfo(
      generic: generic ?? this.generic,
      common: common ?? this.common,
      callDoctorIf: callDoctorIf ?? this.callDoctorIf,
      reviewed: reviewed ?? this.reviewed,
    );
  }

  Map<String, dynamic> toJson() => {
        'generic': generic,
        'common': common.toJson(),
        'callDoctorIf': callDoctorIf.map((e) => e.toJson()).toList(),
        'reviewed': reviewed,
      };

  factory SideEffectInfo.fromJson(Map<String, dynamic> json) {
    return SideEffectInfo(
      generic: (json['generic'] as String?) ?? '',
      common: json['common'] != null
          ? Bilingual.fromJson(Map<String, dynamic>.from(json['common'] as Map))
          : const Bilingual(ur: '', en: ''),
      callDoctorIf: (json['callDoctorIf'] as List<dynamic>? ?? const [])
          .map((e) => Bilingual.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      reviewed: (json['reviewed'] as bool?) ?? false,
    );
  }
}
