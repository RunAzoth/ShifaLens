import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_tokens.dart';

/// Accessible skeleton placeholder that respects MediaQuery.disableAnimations.
class SkeletonLoader extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const SkeletonLoader({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 112.0,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Semantics(
      label: 'Loading content, براہ کرم انتظار کریں',
      child: Column(
        children: List.generate(itemCount, (index) {
          final card = Container(
            height: itemHeight,
            margin: const EdgeInsets.only(bottom: AppTokens.space2),
            padding: const EdgeInsets.all(AppTokens.space2),
            decoration: BoxDecoration(
              color: AppTokens.surfaceWarm,
              borderRadius: BorderRadius.circular(AppTokens.cardRadius),
              border: Border.all(color: AppTokens.borderWarm),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTokens.borderWarm,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                const SizedBox(width: AppTokens.space2),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 20,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTokens.borderWarm,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 16,
                        width: 180,
                        decoration: BoxDecoration(
                          color: AppTokens.borderWarm.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          if (reduceMotion) return card;
          return card
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(
                duration: const Duration(milliseconds: 1100),
                color: Colors.white.withValues(alpha: 0.65),
              );
        }),
      ),
    );
  }
}
