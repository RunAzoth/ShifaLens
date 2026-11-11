import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import 'bi_text.dart';

/// Displays field confidence for a MedicineLine field (name, strength, frequency, duration: 0..1).
/// Never relies on color alone — pairs distinct icon + bilingual field label + status word.
class ConfidenceChip extends StatelessWidget {
  final Bilingual fieldLabel;
  final String? valueText;
  final double confidence;

  const ConfidenceChip({
    super.key,
    required this.fieldLabel,
    required this.confidence,
    this.valueText,
  });

  bool get isHigh => confidence >= 0.80;
  bool get isMedium => confidence >= 0.55 && confidence < 0.80;

  @override
  Widget build(BuildContext context) {
    final (:bg, :fg, :border, :icon, :status) = isHigh
        ? (
            bg: AppTokens.successGreenTint,
            fg: AppTokens.successGreenDark,
            border: AppTokens.successGreen,
            icon: Icons.check_circle_rounded,
            status: const Bilingual(ur: 'واضح', en: 'Clear'),
          )
        : isMedium
            ? (
                bg: AppTokens.warningAmberTint,
                fg: AppTokens.warningAmberDark,
                border: AppTokens.warningAmber,
                icon: Icons.help_rounded,
                status: const Bilingual(ur: 'چیک کریں', en: 'Check'),
              )
            : (
                bg: AppTokens.alertCoralTint,
                fg: AppTokens.alertCoralDark,
                border: AppTokens.alertCoral,
                icon: Icons.error_rounded,
                status: const Bilingual(
                  ur: 'فارماسسٹ سے پوچھیں',
                  en: 'Ask pharmacist',
                ),
              );

    final pct = (confidence.clamp(0.0, 1.0) * 100).round();
    final displayValue =
        (valueText == null || valueText!.trim().isEmpty) ? '—' : valueText!;

    return Semantics(
      label:
          '${fieldLabel.en}: $displayValue, ${status.en} ($pct percent confidence)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTokens.chipRadius),
          border: Border.all(
            color: border.withValues(alpha: 0.55),
            width: 1.3,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  BiText(
                    Bilingual(
                      ur: '${fieldLabel.ur}: $displayValue',
                      en: '${fieldLabel.en}: $displayValue',
                    ),
                    urduSize: 22,
                    englishSize: 16,
                    urduColor: AppTokens.ink,
                    englishColor: AppTokens.ink,
                    urduWeight: FontWeight.w700,
                    englishWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 2),
                  BiText(
                    Bilingual(
                      ur: '${status.ur} ($pct%)',
                      en: '${status.en} ($pct%)',
                    ),
                    urduSize: 22,
                    englishSize: 16,
                    urduColor: fg,
                    englishColor: fg,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
