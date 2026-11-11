import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import 'bi_text.dart';

/// Non-negotiable Rule #5: Every AI-produced output carries a visible
/// "AI-generated: verify with your pharmacist" tag.
class AiTag extends StatelessWidget {
  final bool compact;

  const AiTag({
    super.key,
    this.compact = false,
  });

  static const Bilingual tagText = Bilingual(
    ur: 'مصنوعی ذہانت (AI) سے پڑھا گیا: فارماسسٹ سے تصدیق کریں',
    en: 'AI-generated: verify with your pharmacist',
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${tagText.ur}. ${tagText.en}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: AppTokens.primaryTealSurface,
          borderRadius: BorderRadius.circular(AppTokens.chipRadius),
          border: Border.all(
            color: AppTokens.primaryTeal.withValues(alpha: 0.4),
            width: 1.4,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTokens.primaryTealTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: AppTokens.primaryTealDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BiText(
                tagText,
                urduSize: 22,
                englishSize: 16,
                urduColor: AppTokens.primaryTealDark,
                englishColor: AppTokens.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
