import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import 'bi_text.dart';

/// Non-negotiable Rule #4: Every curated record has `reviewed` (bool).
/// UI shows "Pending pharmacist review" while false. Never claim clinical validation.
class ReviewBadge extends StatelessWidget {
  final bool reviewed;
  final bool showWhenReviewed;

  const ReviewBadge({
    super.key,
    required this.reviewed,
    this.showWhenReviewed = false,
  });

  static const Bilingual pendingText = Bilingual(
    ur: 'فارماسسٹ کا جائزہ باقی ہے',
    en: 'Pending pharmacist review',
  );

  static const Bilingual curatedText = Bilingual(
    ur: 'مقامی معلوماتی جدول سے',
    en: 'Curated reference note',
  );

  @override
  Widget build(BuildContext context) {
    if (reviewed && !showWhenReviewed) {
      return const SizedBox.shrink();
    }

    final isPending = !reviewed;
    final bg =
        isPending ? AppTokens.warningAmberTint : AppTokens.primaryTealTint;
    final fg =
        isPending ? AppTokens.warningAmberDark : AppTokens.primaryTealDark;
    final border = isPending ? AppTokens.warningAmber : AppTokens.primaryTeal;
    final icon = isPending
        ? Icons.hourglass_top_rounded
        : Icons.menu_book_rounded;
    final text = isPending ? pendingText : curatedText;

    return Semantics(
      label: '${text.ur}. ${text.en}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTokens.chipRadius),
          border: Border.all(color: border.withValues(alpha: 0.55), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 8),
            Flexible(
              child: BiText(
                text,
                urduSize: 22,
                englishSize: 16,
                urduColor: fg,
                englishColor: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
