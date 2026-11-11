import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/models.dart';

/// Language display modes required by Part 3:
/// Urdu / English / Both (default Both: Urdu large, English subtitle beneath).
enum LanguageMode {
  ur,
  en,
  both;

  bool get showUrdu => this == LanguageMode.ur || this == LanguageMode.both;
  bool get showEnglish => this == LanguageMode.en || this == LanguageMode.both;
  bool get isRtlPrimary => this == LanguageMode.ur || this == LanguageMode.both;

  TextDirection get direction =>
      isRtlPrimary ? TextDirection.rtl : TextDirection.ltr;

  Lang get primaryLang =>
      this == LanguageMode.en ? Lang.en : Lang.ur;

  String get labelUr {
    switch (this) {
      case LanguageMode.ur:
        return 'صرف اردو';
      case LanguageMode.en:
        return 'انگریزی';
      case LanguageMode.both:
        return 'اردو + انگریزی';
    }
  }

  String get labelEn {
    switch (this) {
      case LanguageMode.ur:
        return 'Urdu';
      case LanguageMode.en:
        return 'English';
      case LanguageMode.both:
        return 'Both';
    }
  }
}

class LanguageModeNotifier extends StateNotifier<LanguageMode> {
  LanguageModeNotifier([super.initial = LanguageMode.both]);

  void setMode(LanguageMode mode) => state = mode;

  void cycle() {
    switch (state) {
      case LanguageMode.both:
        state = LanguageMode.ur;
        break;
      case LanguageMode.ur:
        state = LanguageMode.en;
        break;
      case LanguageMode.en:
        state = LanguageMode.both;
        break;
    }
  }
}

/// Riverpod controller for LanguageMode (default: LanguageMode.both)
final languageModeProvider =
    StateNotifierProvider<LanguageModeNotifier, LanguageMode>(
  (ref) => LanguageModeNotifier(),
);

/// Simulated offline flag for Demo Tools ("simulate offline" in long-press logo drawer)
final simulatedOfflineProvider = StateProvider<bool>((ref) => false);

/// Consent accepted state for Onboarding -> Home gate
final consentAcceptedProvider = StateProvider<bool>((ref) => false);
