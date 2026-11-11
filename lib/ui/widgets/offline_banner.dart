import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import '../theme/language_controller.dart';
import 'bi_text.dart';

/// Offline indicator banner. Shows when [isOffline] is true or when Demo Tools
/// simulates offline mode via [simulatedOfflineProvider].
class OfflineBanner extends ConsumerWidget {
  final bool isOffline;

  const OfflineBanner({
    super.key,
    this.isOffline = false,
  });

  static const Bilingual offlineText = Bilingual(
    ur: 'انٹرنیٹ بند ہے — محفوظ شدہ جدول اور ڈیمو کام کر رہے ہیں',
    en: 'Offline mode — local medicine guide & saved plan remain available',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simulated = ref.watch(simulatedOfflineProvider);
    if (!isOffline && !simulated) {
      return const SizedBox.shrink();
    }

    return Semantics(
      liveRegion: true,
      label: '${offlineText.ur}. ${offlineText.en}',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AppTokens.space2),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space2,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: AppTokens.warningAmberTint,
          borderRadius: BorderRadius.circular(AppTokens.chipRadius),
          border: Border.all(color: AppTokens.warningAmber, width: 1.4),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppTokens.warningAmberDark,
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BiText(
                offlineText,
                urduSize: 22,
                englishSize: 16,
                urduColor: AppTokens.warningAmberDark,
                englishColor: AppTokens.warningAmberDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
