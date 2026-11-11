import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import 'bi_text.dart';

/// Big pictorial action button (minimum 64dp height, icon + Urdu + English).
/// Supports primary filled, secondary warm surface, and warning variants.
/// Scales cleanly up to 1.6x textScale without vertical clipping.
class BigActionButton extends StatelessWidget {
  final IconData icon;
  final Bilingual label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? iconBadgeColor;
  final Widget? trailing;
  final String? semanticHint;

  const BigActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    this.backgroundColor,
    this.foregroundColor,
    this.iconBadgeColor,
    this.trailing,
    this.semanticHint,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg = !enabled
        ? AppTokens.surfaceWarm
        : (backgroundColor ??
            (isPrimary ? AppTokens.primaryTeal : AppTokens.cardCream));
    final fg = !enabled
        ? AppTokens.inkSubtle
        : (foregroundColor ?? (isPrimary ? Colors.white : AppTokens.ink));
    final subFg = !enabled
        ? AppTokens.inkSubtle
        : (isPrimary && foregroundColor == null
            ? Colors.white.withValues(alpha: 0.92)
            : AppTokens.inkMuted);
    final badgeBg = !enabled
        ? AppTokens.borderWarm
        : (iconBadgeColor ??
            (isPrimary
                ? Colors.white.withValues(alpha: 0.18)
                : AppTokens.primaryTealTint));
    final badgeFg = !enabled
        ? AppTokens.inkSubtle
        : (isPrimary ? Colors.white : AppTokens.primaryTealDark);

    return Semantics(
      button: true,
      enabled: enabled,
      label: '${label.ur}. ${label.en}',
      hint: semanticHint,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                }
              : null,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppTokens.heroTapTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space2,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.cardRadius),
              border: Border.all(
                color: !enabled
                    ? AppTokens.borderWarm
                    : (isPrimary
                        ? AppTokens.primaryTealDark
                        : AppTokens.primaryTeal.withValues(alpha: 0.45)),
                width: isPrimary ? 1.0 : 1.6,
              ),
              boxShadow: enabled && isPrimary ? AppTokens.elevatedShadow : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: badgeFg,
                  ),
                ),
                const SizedBox(width: AppTokens.space2),
                Expanded(
                  child: BiText(
                    label,
                    urduSize: 22,
                    englishSize: 16,
                    urduColor: fg,
                    englishColor: subFg,
                    urduWeight: FontWeight.w700,
                    englishWeight: FontWeight.w600,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ] else ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: fg.withValues(alpha: 0.85),
                    size: 24,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
