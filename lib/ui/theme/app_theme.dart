import 'package:flutter/material.dart';
import 'app_tokens.dart';

/// ShifaLens Material 3 Light Theme ("calm clinic meets friendly neighbourhood pharmacist")
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppTokens.primaryTeal,
      onPrimary: Colors.white,
      primaryContainer: AppTokens.primaryTealTint,
      onPrimaryContainer: AppTokens.primaryTealDark,
      secondary: AppTokens.morningSaffronDark,
      onSecondary: Colors.white,
      secondaryContainer: AppTokens.morningSaffronTint,
      onSecondaryContainer: AppTokens.ink,
      tertiary: AppTokens.eveningIndigo,
      onTertiary: Colors.white,
      tertiaryContainer: AppTokens.eveningIndigoTint,
      onTertiaryContainer: AppTokens.eveningIndigo,
      error: AppTokens.alertCoral,
      onError: Colors.white,
      errorContainer: AppTokens.alertCoralTint,
      onErrorContainer: AppTokens.alertCoralDark,
      surface: AppTokens.surfaceCream,
      onSurface: AppTokens.ink,
      onSurfaceVariant: AppTokens.inkMuted,
      outline: AppTokens.borderWarm,
      outlineVariant: AppTokens.surfaceWarm,
      shadow: Color(0x1F1F2937),
      scrim: Color(0x661F2937),
      inverseSurface: AppTokens.ink,
      onInverseSurface: AppTokens.surfaceCream,
      inversePrimary: AppTokens.primaryTealTint,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppTokens.surfaceCream,
      fontFamily: AppTokens.fontEnglish,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTokens.surfaceCream,
        foregroundColor: AppTokens.ink,
        elevation: 0,
        scrolledUnderElevation: 2,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppTokens.fontEnglish,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppTokens.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppTokens.cardCream,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          side: const BorderSide(color: AppTokens.borderWarm, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.primaryTeal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTokens.surfaceWarm,
          disabledForegroundColor: AppTokens.inkSubtle,
          minimumSize: const Size(double.infinity, AppTokens.heroTapTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space3,
            vertical: AppTokens.space2,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.buttonRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTokens.fontEnglish,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTokens.primaryTealDark,
          backgroundColor: AppTokens.cardCream,
          minimumSize: const Size(AppTokens.minTapTarget, AppTokens.minTapTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space2,
            vertical: 12,
          ),
          side: const BorderSide(color: AppTokens.primaryTeal, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.buttonRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTokens.fontEnglish,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppTokens.surfaceWarm,
        selectedColor: AppTokens.primaryTealTint,
        labelStyle: const TextStyle(
          fontFamily: AppTokens.fontEnglish,
          fontSize: AppTokens.minEnglishSize,
          fontWeight: FontWeight.w600,
          color: AppTokens.ink,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.chipRadius),
          side: const BorderSide(color: AppTokens.borderWarm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space2,
          vertical: AppTokens.space2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppTokens.borderWarm, width: 1.4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppTokens.borderWarm, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppTokens.primaryTeal, width: 2),
        ),
        labelStyle: const TextStyle(
          color: AppTokens.inkMuted,
          fontSize: AppTokens.minEnglishSize,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppTokens.surfaceCream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.cardRadius),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppTokens.borderWarm,
        thickness: 1,
        space: AppTokens.space3,
      ),
    );
  }

  /// Urdu headline style (Noto Nastaliq Urdu, line-height >= 1.9 so it never clips, min 22sp)
  static TextStyle urduHeadline({
    double fontSize = 24,
    Color color = AppTokens.ink,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    final effectiveSize =
        fontSize < AppTokens.minUrduSize ? AppTokens.minUrduSize : fontSize;
    return TextStyle(
      fontFamily: AppTokens.fontUrduHeadline,
      fontSize: effectiveSize,
      height: AppTokens.nastaliqLineHeight,
      fontWeight: fontWeight,
      color: color,
    );
  }

  /// Urdu body style (Noto Naskh Arabic for clarity at body sizes, min 22sp)
  static TextStyle urduBody({
    double fontSize = 22,
    Color color = AppTokens.ink,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    final effectiveSize =
        fontSize < AppTokens.minUrduSize ? AppTokens.minUrduSize : fontSize;
    return TextStyle(
      fontFamily: AppTokens.fontUrduBody,
      fontSize: effectiveSize,
      height: AppTokens.naskhLineHeight,
      fontWeight: fontWeight,
      color: color,
    );
  }

  /// English subtitle / body style (Inter, min 16sp)
  static TextStyle englishBody({
    double fontSize = 16,
    Color color = AppTokens.inkMuted,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    final effectiveSize = fontSize < AppTokens.minEnglishSize
        ? AppTokens.minEnglishSize
        : fontSize;
    return TextStyle(
      fontFamily: AppTokens.fontEnglish,
      fontSize: effectiveSize,
      height: AppTokens.englishLineHeight,
      fontWeight: fontWeight,
      color: color,
    );
  }
}
