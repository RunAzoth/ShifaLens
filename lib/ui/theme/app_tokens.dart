import 'package:flutter/material.dart';
import '../../core/models/models.dart';

/// ShifaLens Design Tokens ("calm clinic meets friendly neighbourhood pharmacist")
/// Light theme only. Contrast >= 4.5:1. Never rely on color alone.
class AppTokens {
  AppTokens._();

  // Core Palette
  static const Color primaryTeal = Color(0xFF0F766E);
  static const Color primaryTealDark = Color(0xFF115E59);
  static const Color primaryTealTint = Color(0xFFCCFBF1);
  static const Color primaryTealSurface = Color(0xFFF0FDFA);

  static const Color surfaceCream = Color(0xFFFFFBF5);
  static const Color cardCream = Color(0xFFFFFFFF);
  static const Color surfaceWarm = Color(0xFFF7F2EA);
  static const Color borderWarm = Color(0xFFE5DEC9);

  static const Color ink = Color(0xFF1F2937);
  static const Color inkMuted = Color(0xFF4B5563);
  static const Color inkSubtle = Color(0xFF6B7280);

  // Time of day accents
  static const Color morningSaffron = Color(0xFFF59E0B);
  static const Color morningSaffronDark = Color(0xFFB45309);
  static const Color morningSaffronTint = Color(0xFFFEF3C7);

  static const Color eveningIndigo = Color(0xFF3730A3);
  static const Color eveningIndigoTint = Color(0xFFE0E7FF);

  // Semantic feedback colors (WCAG AA >= 4.5:1 against soft tints / cream)
  static const Color successGreen = Color(0xFF16A34A);
  static const Color successGreenDark = Color(0xFF166534);
  static const Color successGreenTint = Color(0xFFDCFCE7);

  static const Color warningAmber = Color(0xFFD97706);
  static const Color warningAmberDark = Color(0xFF92400E);
  static const Color warningAmberTint = Color(0xFFFEF3C7);

  static const Color alertCoral = Color(0xFFDC2626);
  static const Color alertCoralDark = Color(0xFF991B1B);
  static const Color alertCoralTint = Color(0xFFFEE2E2);

  // Role and UI accents
  static const Color accentAmber = warningAmber;
  static const Color accentAmberDark = warningAmberDark;
  static const Color textMuted = inkMuted;

  // Typography families (bundled offline-safe in assets/fonts)
  static const String fontUrduHeadline = 'NotoNastaliqUrdu';
  static const String fontUrduBody = 'NotoNaskhArabic';
  static const String fontEnglish = 'Inter';

  // Minimum accessible sizes
  static const double minUrduSize = 22.0;
  static const double minEnglishSize = 16.0;
  static const double nastaliqLineHeight = 1.95;
  static const double naskhLineHeight = 1.65;
  static const double englishLineHeight = 1.45;

  // Shape & space (8dp grid)
  static const double cardRadius = 24.0;
  static const double chipRadius = 16.0;
  static const double radiusMedium = 16.0;
  static const double buttonRadius = 20.0;
  static const double radiusFull = 999.0;
  static const double minTapTarget = 56.0;
  static const double heroTapTarget = 64.0;

  static const double space1 = 8.0;
  static const double space2 = 16.0;
  static const double space3 = 24.0;
  static const double space4 = 32.0;

  // Motion durations (~250-400ms purposeful)
  static const Duration motionFast = Duration(milliseconds: 250);
  static const Duration motionMedium = Duration(milliseconds: 350);

  // Soft layered clinic shadows
  static List<BoxShadow> get cardShadow => const [
        BoxShadow(
          color: Color(0x0D1F2937),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
        BoxShadow(
          color: Color(0x080F766E),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => const [
        BoxShadow(
          color: Color(0x180F766E),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
        BoxShadow(
          color: Color(0x0A1F2937),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ];

  /// Slot palette helper for MealSlot
  static ({Color fg, Color bg, Color accent}) slotColors(MealSlot slot) {
    switch (slot) {
      case MealSlot.wakeUp:
      case MealSlot.suhoor:
      case MealSlot.breakfast:
      case MealSlot.midMorning:
        return (
          fg: morningSaffronDark,
          bg: morningSaffronTint,
          accent: morningSaffron,
        );
      case MealSlot.lunch:
      case MealSlot.afternoon:
        return (
          fg: primaryTealDark,
          bg: primaryTealTint,
          accent: primaryTeal,
        );
      case MealSlot.iftar:
      case MealSlot.dinner:
      case MealSlot.bedtime:
        return (
          fg: eveningIndigo,
          bg: eveningIndigoTint,
          accent: eveningIndigo,
        );
      case MealSlot.whenNeeded:
        return (
          fg: ink,
          bg: surfaceWarm,
          accent: inkMuted,
        );
    }
  }
}

/// 10-slot Medicine Identity System (0..9)
/// Drives unique color + shape + letter everywhere (timeline, cards, strips, stickers).
enum PillShapeType {
  circle,
  capsule,
  triangle,
  square,
  diamond,
  hexagon,
  pentagon,
  octagon,
  shield,
  star,
}

class MedicineIdentity {
  final int index;
  final String letter;
  final String labelEn;
  final String labelUr;
  final Color primaryColor;
  final Color tintColor;
  final PillShapeType shape;

  const MedicineIdentity({
    required this.index,
    required this.letter,
    required this.labelEn,
    required this.labelUr,
    required this.primaryColor,
    required this.tintColor,
    required this.shape,
  });

  static const List<MedicineIdentity> palette = [
    MedicineIdentity(
      index: 0,
      letter: 'A',
      labelEn: 'Teal Circle A',
      labelUr: 'سبز گول دائرہ A',
      primaryColor: Color(0xFF0F766E),
      tintColor: Color(0xFFCCFBF1),
      shape: PillShapeType.circle,
    ),
    MedicineIdentity(
      index: 1,
      letter: 'B',
      labelEn: 'Saffron Capsule B',
      labelUr: 'زرد کیپسول B',
      primaryColor: Color(0xFFB45309),
      tintColor: Color(0xFFFEF3C7),
      shape: PillShapeType.capsule,
    ),
    MedicineIdentity(
      index: 2,
      letter: 'C',
      labelEn: 'Indigo Triangle C',
      labelUr: 'نیلا تکون C',
      primaryColor: Color(0xFF3730A3),
      tintColor: Color(0xFFE0E7FF),
      shape: PillShapeType.triangle,
    ),
    MedicineIdentity(
      index: 3,
      letter: 'D',
      labelEn: 'Green Square D',
      labelUr: 'ہرا چوکور D',
      primaryColor: Color(0xFF15803D),
      tintColor: Color(0xFFDCFCE7),
      shape: PillShapeType.square,
    ),
    MedicineIdentity(
      index: 4,
      letter: 'E',
      labelEn: 'Rose Diamond E',
      labelUr: 'گلابی ہیرا E',
      primaryColor: Color(0xFFBE123C),
      tintColor: Color(0xFFFFE4E6),
      shape: PillShapeType.diamond,
    ),
    MedicineIdentity(
      index: 5,
      letter: 'F',
      labelEn: 'Purple Hexagon F',
      labelUr: 'جامنی مسدس F',
      primaryColor: Color(0xFF6D28D9),
      tintColor: Color(0xFFEDE9FE),
      shape: PillShapeType.hexagon,
    ),
    MedicineIdentity(
      index: 6,
      letter: 'G',
      labelEn: 'Sky Pentagon G',
      labelUr: 'آسمانی مخمس G',
      primaryColor: Color(0xFF0369A1),
      tintColor: Color(0xFFE0F2FE),
      shape: PillShapeType.pentagon,
    ),
    MedicineIdentity(
      index: 7,
      letter: 'H',
      labelEn: 'Copper Octagon H',
      labelUr: 'تانبے کا مثمن H',
      primaryColor: Color(0xFF9A3412),
      tintColor: Color(0xFFFFEDD5),
      shape: PillShapeType.octagon,
    ),
    MedicineIdentity(
      index: 8,
      letter: 'J',
      labelEn: 'Plum Shield J',
      labelUr: 'عنابی ڈھال J',
      primaryColor: Color(0xFF86198F),
      tintColor: Color(0xFFFAE8FF),
      shape: PillShapeType.shield,
    ),
    MedicineIdentity(
      index: 9,
      letter: 'K',
      labelEn: 'Slate Star K',
      labelUr: 'سرمئی ستارہ K',
      primaryColor: Color(0xFF334155),
      tintColor: Color(0xFFF1F5F9),
      shape: PillShapeType.star,
    ),
  ];

  static MedicineIdentity of(int rawIndex) {
    final normalized = rawIndex.abs() % palette.length;
    return palette[normalized];
  }
}
