import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/language_controller.dart';

/// Accessible pill toggle for switching between Urdu / English / Both (default Both).
/// Minimum 56dp height for effortless tapping.
class LanguageToggle extends ConsumerWidget {
  final bool compact;

  const LanguageToggle({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMode = ref.watch(languageModeProvider);

    return Semantics(
      container: true,
      label: 'Language display mode: ${activeMode.labelEn}',
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTokens.surfaceWarm,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTokens.borderWarm, width: 1.2),
        ),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: LanguageMode.values.map((mode) {
            final selected = mode == activeMode;
            return Semantics(
              button: true,
              selected: selected,
              label: 'Switch language to ${mode.labelEn} (${mode.labelUr})',
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(languageModeProvider.notifier).setMode(mode);
                },
                child: AnimatedContainer(
                  duration: AppTokens.motionFast,
                  constraints: BoxConstraints(
                    minHeight: compact ? 48 : AppTokens.minTapTarget - 8,
                    minWidth: compact ? 68 : 88,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppTokens.primaryTeal : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          mode.labelUr,
                          style: AppTheme.urduBody(
                            fontSize: 22,
                            color: selected ? Colors.white : AppTokens.ink,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        mode.labelEn,
                        style: AppTheme.englishBody(
                          fontSize: 16,
                          color: selected
                              ? Colors.white.withValues(alpha: 0.92)
                              : AppTokens.inkMuted,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
