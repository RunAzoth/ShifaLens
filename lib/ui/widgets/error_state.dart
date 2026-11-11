import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import 'bi_text.dart';
import 'big_action_button.dart';

/// Friendly ErrorState with both "Try again" and "Use manual entry" actions.
class ErrorState extends StatelessWidget {
  final Bilingual? title;
  final Bilingual? message;
  final VoidCallback onRetry;
  final VoidCallback? onManualEntry;

  const ErrorState({
    super.key,
    this.title,
    this.message,
    required this.onRetry,
    this.onManualEntry,
  });

  static const Bilingual defaultTitle = Bilingual(
    ur: 'نسخہ پڑھنے میں مشکل پیش آئی',
    en: 'Could not read the prescription clearly',
  );

  static const Bilingual defaultMessage = Bilingual(
    ur: 'آپ دوبارہ تصویر لے سکتے ہیں یا ہاتھ سے دوا کا نام درج کر سکتے ہیں۔',
    en: 'You can try taking the photo again or enter your medicines manually.',
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space3),
      decoration: BoxDecoration(
        color: AppTokens.cardCream,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        border: Border.all(color: AppTokens.alertCoral, width: 1.5),
        boxShadow: AppTokens.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTokens.alertCoralTint,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: AppTokens.alertCoralDark,
            ),
          ),
          const SizedBox(height: AppTokens.space2),
          BiText(
            title ?? defaultTitle,
            isHeadline: true,
            urduColor: AppTokens.alertCoralDark,
            textAlign: TextAlign.center,
            crossAxisAlignment: CrossAxisAlignment.center,
          ),
          const SizedBox(height: AppTokens.space1),
          BiText(
            message ?? defaultMessage,
            textAlign: TextAlign.center,
            crossAxisAlignment: CrossAxisAlignment.center,
          ),
          const SizedBox(height: AppTokens.space3),
          BigActionButton(
            icon: Icons.refresh_rounded,
            label: const Bilingual(
              ur: 'دوبارہ کوشش کریں',
              en: 'Try again',
            ),
            onPressed: onRetry,
          ),
          if (onManualEntry != null) ...[
            const SizedBox(height: 12),
            BigActionButton(
              icon: Icons.edit_note_rounded,
              isPrimary: false,
              label: const Bilingual(
                ur: 'ہاتھ سے دوا درج کریں',
                en: 'Use manual entry',
              ),
              onPressed: onManualEntry,
            ),
          ],
        ],
      ),
    );
  }
}
