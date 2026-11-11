import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/language_controller.dart';

/// Accessible pill toggle for switching between Urdu / English / Both (default Both).
/// When [compact] is true (inside a 56dp AppBar), uses a single-line scaleDown layout
/// so it never overflows horizontally or vertically even at 1.6x textScale.
class LanguageToggle extends ConsumerWidget {
  final bool compact;

  const LanguageToggle({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMode = ref.watch(languageModeProvider);

    if (compact) {
      return Semantics(
        container: true,
        label: 'Language display mode: ${activeMode.labelEn}',
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 132, maxHeight: 40),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppTokens.surfaceWarm,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTokens.borderWarm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: LanguageMode.values.map((mode) {
                final selected = mode == activeMode;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: 'Switch language to ${mode.labelEn}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(11),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(languageModeProvider.notifier).setMode(mode);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTokens.primaryTeal
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        mode.labelEn,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? Colors.white : AppTokens.ink,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
    }

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
                  constraints: const BoxConstraints(
                    minHeight: AppTokens.minTapTarget - 8,
                    minWidth: 88,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        selected ? AppTokens.primaryTeal : Colors.transparent,
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
