import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/models.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/language_controller.dart';

/// Renders a [Bilingual] string respecting the active [LanguageMode] (Urdu / English / Both).
/// Default mode is Both: Urdu large (RTL), English subtitle beneath (LTR).
/// Supports textScale up to 1.6 with no overflow.
class BiText extends ConsumerWidget {
  final Bilingual text;
  final bool isHeadline;
  final double? urduSize;
  final double? englishSize;
  final Color? urduColor;
  final Color? englishColor;
  final FontWeight? urduWeight;
  final FontWeight? englishWeight;
  final TextAlign? textAlign;
  final CrossAxisAlignment? crossAxisAlignment;
  final int? maxLines;
  final TextOverflow? overflow;
  final double spacing;

  const BiText(
    this.text, {
    super.key,
    this.isHeadline = false,
    this.urduSize,
    this.englishSize,
    this.urduColor,
    this.englishColor,
    this.urduWeight,
    this.englishWeight,
    this.textAlign,
    this.crossAxisAlignment,
    this.maxLines,
    this.overflow,
    this.spacing = 4.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(languageModeProvider);

    final baseUrduSize = urduSize ?? (isHeadline ? 24.0 : AppTokens.minUrduSize);
    final baseEnglishSize =
        englishSize ?? (isHeadline ? 17.0 : AppTokens.minEnglishSize);

    final urStyle = isHeadline
        ? AppTheme.urduHeadline(
            fontSize: baseUrduSize,
            color: urduColor ?? AppTokens.ink,
            fontWeight: urduWeight ?? FontWeight.w700,
          )
        : AppTheme.urduBody(
            fontSize: baseUrduSize,
            color: urduColor ?? AppTokens.ink,
            fontWeight: urduWeight ?? FontWeight.w600,
          );

    final enStyle = AppTheme.englishBody(
      fontSize: baseEnglishSize,
      color: englishColor ??
          (mode == LanguageMode.en
              ? (urduColor ?? AppTokens.ink)
              : AppTokens.inkMuted),
      fontWeight: englishWeight ??
          (mode == LanguageMode.en ? FontWeight.w700 : FontWeight.w500),
    );

    final effectiveAlign = crossAxisAlignment ?? CrossAxisAlignment.stretch;

    return Semantics(
      label: '${text.ur}. ${text.en}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: effectiveAlign,
        children: [
          if (mode.showUrdu && text.ur.trim().isNotEmpty)
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                text.ur,
                style: urStyle,
                textAlign: textAlign ?? TextAlign.start,
                maxLines: maxLines,
                overflow: overflow,
                softWrap: true,
              ),
            ),
          if (mode == LanguageMode.both &&
              text.ur.trim().isNotEmpty &&
              text.en.trim().isNotEmpty)
            SizedBox(height: spacing),
          if (mode.showEnglish && text.en.trim().isNotEmpty)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                text.en,
                style: enStyle,
                textAlign: textAlign ??
                    (mode == LanguageMode.both
                        ? TextAlign.start
                        : TextAlign.start),
                maxLines: maxLines,
                overflow: overflow,
                softWrap: true,
              ),
            ),
        ],
      ),
    );
  }
}
