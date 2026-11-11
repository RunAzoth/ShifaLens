import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/models.dart';

/// User Role: Patient (low-literacy, visual-first, Urdu audio) vs Caretaker (supervisor, doctor approvals, export/share, dose confirmation, notifications).
enum UserRole {
  patient,
  caretaker;

  bool get isCaretaker => this == UserRole.caretaker;
  bool get isPatient => this == UserRole.patient;

  Bilingual get title => switch (this) {
        UserRole.patient => const Bilingual(
            ur: 'مریض (سادہ تصویری انداز)',
            en: 'Patient (Visual & Voice)',
          ),
        UserRole.caretaker => const Bilingual(
            ur: 'نگران / تیماردار (اختیارات اور نگرانی)',
            en: 'Caretaker (Supervisor & Controls)',
          ),
      };

  Bilingual get description => switch (this) {
        UserRole.patient => const Bilingual(
            ur: 'بڑی تصاویر، آسان آواز، کھانا اور دوائی کے نشانات، اور سادہ سوال جواب۔',
            en: 'Big visual icons, loud Urdu voice, simple meal slots, and safe Q&A.',
          ),
        UserRole.caretaker => const Bilingual(
            ur: 'ڈاکٹر کی منظوری، پرنٹ و ای میل، ادویات کا معائنہ، اور الارم سیٹنگز۔',
            en: 'Doctor approvals, PDF/email export, strip matcher, and full supervisory control.',
          ),
      };

  IconData get icon => switch (this) {
        UserRole.patient => Icons.person_rounded,
        UserRole.caretaker => Icons.health_and_safety_rounded,
      };
}

class UserRoleNotifier extends Notifier<UserRole> {
  @override
  UserRole build() => UserRole.caretaker; // Caretaker enabled by default for full authority or toggleable

  void setRole(UserRole role) {
    state = role;
  }

  void toggle() {
    state = state == UserRole.patient ? UserRole.caretaker : UserRole.patient;
  }
}

/// Riverpod Provider for Active User Role
final userRoleProvider = NotifierProvider<UserRoleNotifier, UserRole>(
  UserRoleNotifier.new,
);
