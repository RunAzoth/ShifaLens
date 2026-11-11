import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import 'bi_text.dart';
import 'big_action_button.dart';

/// Warm pictorial empty state widget with optional primary action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final Bilingual title;
  final Bilingual subtitle;
  final Bilingual? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space3),
      decoration: BoxDecoration(
        color: AppTokens.cardCream,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        border: Border.all(color: AppTokens.borderWarm, width: 1.4),
        boxShadow: AppTokens.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTokens.primaryTealTint,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              icon,
              size: 40,
              color: AppTokens.primaryTealDark,
            ),
          ),
          const SizedBox(height: AppTokens.space2),
          BiText(
            title,
            isHeadline: true,
            textAlign: TextAlign.center,
            crossAxisAlignment: CrossAxisAlignment.center,
          ),
          const SizedBox(height: AppTokens.space1),
          BiText(
            subtitle,
            textAlign: TextAlign.center,
            crossAxisAlignment: CrossAxisAlignment.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppTokens.space3),
            BigActionButton(
              icon: actionIcon ?? Icons.add_circle_outline_rounded,
              label: actionLabel!,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
