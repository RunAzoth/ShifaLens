import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/models/models.dart';

/// Language display modes required by Part 3 & Part 4:
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

  Lang get primaryLang => this == LanguageMode.en ? Lang.en : Lang.ur;

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

class LanguageModeNotifier extends Notifier<LanguageMode> {
  @override
  LanguageMode build() => LanguageMode.both;

  void setMode(LanguageMode mode) {
    state = mode;
    try {
      ref.read(langProvider.notifier).setLang(mode.primaryLang);
    } catch (_) {}
  }

  void cycle() {
    switch (state) {
      case LanguageMode.both:
        setMode(LanguageMode.ur);
        break;
      case LanguageMode.ur:
        setMode(LanguageMode.en);
        break;
      case LanguageMode.en:
        setMode(LanguageMode.both);
        break;
    }
  }
}

/// Riverpod 3 NotifierProvider for LanguageMode (default: LanguageMode.both)
final languageModeProvider =
    NotifierProvider<LanguageModeNotifier, LanguageMode>(
      LanguageModeNotifier.new,
    );

class SimulatedOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setOffline(bool value) => state = value;
}

/// Simulated offline flag for Demo Tools ("simulate offline" in long-press logo drawer)
final simulatedOfflineProvider =
    NotifierProvider<SimulatedOfflineNotifier, bool>(
      SimulatedOfflineNotifier.new,
    );

class ConsentAcceptedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setAccepted(bool value) => state = value;
}

/// Consent accepted state for Onboarding -> Home gate
final consentAcceptedProvider =
    NotifierProvider<ConsentAcceptedNotifier, bool>(
      ConsentAcceptedNotifier.new,
    );
