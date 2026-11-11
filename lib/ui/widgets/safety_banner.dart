import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import 'bi_text.dart';

enum SafetyBannerVariant {
  prototypeDisclaimer,
  duplicateWarning,
  duplicateHardAlert,
  pharmacistNotice,
}

/// High-visibility clinical safety & duplicate alert banner.
/// Also renders the mandatory prototype limitation: "Prototype. Not a medical device."
class SafetyBanner extends StatelessWidget {
  final Bilingual title;
  final Bilingual? body;
  final SafetyBannerVariant variant;
  final Widget? trailing;

  const SafetyBanner({
    super.key,
    required this.title,
    this.body,
    this.variant = SafetyBannerVariant.prototypeDisclaimer,
    this.trailing,
  });

  /// Standard prototype limitation banner (Non-negotiable Rule #4)
  factory SafetyBanner.prototype({Key? key}) {
    return SafetyBanner(
      key: key,
      variant: SafetyBannerVariant.prototypeDisclaimer,
      title: const Bilingual(
        ur: 'یہ ایک تجرباتی نمونہ ہے، طبی آلہ نہیں۔',
        en: 'Prototype. Not a medical device.',
      ),
      body: const Bilingual(
        ur: 'پہلے اپنے فارماسسٹ یا ڈاکٹر سے تصدیق ضرور کریں۔',
        en: 'Always confirm medicines and timing with your pharmacist or doctor.',
      ),
    );
  }

  /// DuplicateAlert banner for Review & Confirm or Plan screen
  factory SafetyBanner.fromDuplicate(DuplicateAlert alert, {Key? key}) {
    return SafetyBanner(
      key: key,
      variant: alert.sameGeneric
          ? SafetyBannerVariant.duplicateHardAlert
          : SafetyBannerVariant.duplicateWarning,
      title: Bilingual(
        ur: alert.sameGeneric
            ? 'خبردار: ایک جیسی دو دوائیں (${alert.label})'
            : 'توجہ: ملتی جلتی دوائیں (${alert.label})',
        en: alert.sameGeneric
            ? 'Same medicine ingredient twice (${alert.label})'
            : 'Similar medicine class (${alert.label})',
      ),
      body: alert.message,
    );
  }

  @override
  Widget build(BuildContext context) {
    final (:bg, :fg, :border, :icon) = switch (variant) {
      SafetyBannerVariant.duplicateHardAlert => (
          bg: AppTokens.alertCoralTint,
          fg: AppTokens.alertCoralDark,
          border: AppTokens.alertCoral,
          icon: Icons.warning_amber_rounded,
        ),
      SafetyBannerVariant.duplicateWarning ||
      SafetyBannerVariant.pharmacistNotice =>
        (
          bg: AppTokens.warningAmberTint,
          fg: AppTokens.warningAmberDark,
          border: AppTokens.warningAmber,
          icon: Icons.info_outline_rounded,
        ),
      SafetyBannerVariant.prototypeDisclaimer => (
          bg: AppTokens.surfaceWarm,
          fg: AppTokens.ink,
          border: AppTokens.borderWarm,
          icon: Icons.health_and_safety_outlined,
        ),
    };

    return Semantics(
      container: true,
      label: '${title.ur}. ${title.en}',
      child: Container(
        padding: const EdgeInsets.all(AppTokens.space2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          border: Border.all(color: border, width: 1.6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: fg, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BiText(
                    title,
                    urduSize: 22,
                    englishSize: 16,
                    urduColor: fg,
                    englishColor: fg,
                    urduWeight: FontWeight.w700,
                    englishWeight: FontWeight.w700,
                  ),
                  if (body != null) ...[
                    const SizedBox(height: 6),
                    BiText(
                      body!,
                      urduSize: 22,
                      englishSize: 16,
                      urduColor: fg,
                      englishColor: AppTokens.ink,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
