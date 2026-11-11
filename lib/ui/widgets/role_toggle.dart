import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import '../theme/role_controller.dart';
import 'bi_text.dart';

class RoleToggle extends ConsumerWidget {
  final bool compact;

  const RoleToggle({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);

    if (compact) {
      return InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          ref.read(userRoleProvider.notifier).toggle();
        },
        borderRadius: BorderRadius.circular(AppTokens.chipRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: role.isCaretaker
                ? AppTokens.primaryTeal.withValues(alpha: 0.12)
                : AppTokens.warningAmber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTokens.chipRadius),
            border: Border.all(
              color: role.isCaretaker
                  ? AppTokens.primaryTeal
                  : AppTokens.warningAmber,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                role.icon,
                size: 16,
                color: role.isCaretaker
                    ? AppTokens.primaryTealDark
                    : AppTokens.warningAmberDark,
              ),
              const SizedBox(width: 4),
              Text(
                role.isCaretaker ? 'نگران / Caretaker' : 'مریض / Patient',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: role.isCaretaker
                      ? AppTokens.primaryTealDark
                      : AppTokens.warningAmberDark,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: role.isCaretaker
          ? AppTokens.primaryTeal.withValues(alpha: 0.08)
          : AppTokens.warningAmber.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        side: BorderSide(
          color: role.isCaretaker
              ? AppTokens.primaryTeal
              : AppTokens.warningAmber,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space2),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: role.isCaretaker
                    ? AppTokens.primaryTeal
                    : AppTokens.warningAmber,
                shape: BoxShape.circle,
              ),
              child: Icon(
                role.icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BiText(
                    role.title,
                    isHeadline: true,
                  ),
                  const SizedBox(height: 2),
                  BiText(
                    role.description,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(userRoleProvider.notifier).toggle();
              },
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: Text(
                role.isCaretaker ? 'مریض موڈ' : 'نگران موڈ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                foregroundColor: role.isCaretaker
                    ? AppTokens.primaryTealDark
                    : AppTokens.warningAmberDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
