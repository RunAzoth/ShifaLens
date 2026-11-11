import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import '../theme/language_controller.dart';
import '../widgets/widgets.dart';
import 'journey_controller.dart';
import 'manual_entry_sheet.dart';

/// Screen 5: AI Reading Screen
/// - Shimmering "scanning" overlay with a sweeping line while the AI reads the photo
/// - Rotating friendly bilingual status lines ("Reading handwriting...", "Matching brand names...", etc.)
/// - ErrorState with "Try again" and "Use manual entry" if reading fails
class AiReadingScreen extends ConsumerStatefulWidget {
  final Duration minimumDisplayDuration;

  const AiReadingScreen({
    super.key,
    this.minimumDisplayDuration = const Duration(milliseconds: 900),
  });

  @override
  ConsumerState<AiReadingScreen> createState() => _AiReadingScreenState();
}

class _AiReadingScreenState extends ConsumerState<AiReadingScreen>
    with SingleTickerProviderStateMixin {
  Timer? _statusTimer;
  int _statusIndex = 0;
  late final AnimationController _sweepController;

  static const List<Bilingual> _statusLines = [
    Bilingual(
      ur: 'ڈاکٹر کی لکھائی پڑھی جا رہی ہے...',
      en: 'Reading handwriting...',
    ),
    Bilingual(
      ur: 'دوائیوں کے برانڈ اور فارمولے ملائے جا رہے ہیں...',
      en: 'Matching brand names...',
    ),
    Bilingual(
      ur: 'خوراک کی طاقت (mg) اور دنوں کی تعداد چیک ہو رہی ہے...',
      en: 'Checking strengths and daily timing...',
    ),
    Bilingual(
      ur: 'غیر واضح الفاظ پر فارماسسٹ کی تصدیق کا نشان لگایا جا رہا ہے...',
      en: 'Flagging uncertain items for pharmacist review...',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _statusTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (!mounted) return;
      setState(() {
        _statusIndex = (_statusIndex + 1) % _statusLines.length;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runReader();
    });
  }

  Future<void> _runReader() async {
    final startedAt = DateTime.now();
    final ok =
        await ref.read(journeyControllerProvider.notifier).readCurrentPhoto();
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < widget.minimumDisplayDuration) {
      await Future<void>.delayed(widget.minimumDisplayDuration - elapsed);
    }
    if (!mounted) return;
    if (ok) {
      context.pushReplacement('/review');
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(languageModeProvider);
    final journey = ref.watch(journeyControllerProvider);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Directionality(
      textDirection: mode.direction,
      child: Scaffold(
        backgroundColor: AppTokens.surfaceCream,
        appBar: AppBar(
          title: const Text('AI Reading • نسخہ پڑھا جا رہا ہے'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.space2),
            child: journey.errorMessage != null
                ? ErrorState(
                    onRetry: _runReader,
                    onManualEntry: () async {
                      ref
                          .read(journeyControllerProvider.notifier)
                          .startManualPrescription();
                      final added = await ManualEntrySheet.show(context);
                      if (added == true && context.mounted) {
                        context.pushReplacement('/review');
                      }
                    },
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const OfflineBanner(),
                      const AiTag(),
                      const SizedBox(height: AppTokens.space2),

                      // Scanning Photo Container with Sweeping Laser Line
                      Semantics(
                        liveRegion: true,
                        label:
                            '${_statusLines[_statusIndex].ur}. ${_statusLines[_statusIndex].en}',
                        child: Container(
                          height: 240,
                          decoration: BoxDecoration(
                            color: AppTokens.ink,
                            borderRadius:
                                BorderRadius.circular(AppTokens.cardRadius),
                            border: Border.all(
                              color: AppTokens.primaryTeal,
                              width: 2.5,
                            ),
                            boxShadow: AppTokens.elevatedShadow,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Stylized synthetic prescription preview lines
                              Padding(
                                padding:
                                    const EdgeInsets.all(AppTokens.space3),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.local_hospital_rounded,
                                          color: AppTokens.primaryTealTint,
                                          size: 28,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          journey.activeDemoId?.title.en ??
                                              'Synthetic Prescription Scan',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    for (int i = 0; i < 4; i++)
                                      Container(
                                        height: 16,
                                        width: i == 3 ? 180 : double.infinity,
                                        decoration: BoxDecoration(
                                          color: i == 3
                                              ? AppTokens.morningSaffron
                                                  .withValues(alpha: 0.35)
                                              : Colors.white
                                                  .withValues(alpha: 0.16),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Sweeping scanning line
                              if (!reduceMotion)
                                AnimatedBuilder(
                                  animation: _sweepController,
                                  builder: (context, _) {
                                    return Positioned(
                                      top: 16 +
                                          (_sweepController.value * (240 - 36)),
                                      left: 12,
                                      right: 12,
                                      child: Container(
                                        height: 4,
                                        decoration: const BoxDecoration(
                                          color: AppTokens.morningSaffron,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTokens.morningSaffron,
                                              blurRadius: 16,
                                              spreadRadius: 3,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTokens.space3),

                      // Rotating Friendly Status Card
                      Container(
                        padding: const EdgeInsets.all(AppTokens.space2),
                        decoration: BoxDecoration(
                          color: AppTokens.cardCream,
                          borderRadius:
                              BorderRadius.circular(AppTokens.cardRadius),
                          border: Border.all(
                            color: AppTokens.primaryTeal.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: AppTokens.cardShadow,
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 3.5,
                                color: AppTokens.primaryTeal,
                              ),
                            ),
                            const SizedBox(width: AppTokens.space2),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: AppTokens.motionFast,
                                child: BiText(
                                  _statusLines[_statusIndex],
                                  key: ValueKey<int>(_statusIndex),
                                  isHeadline: true,
                                  urduColor: AppTokens.primaryTealDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTokens.space3),

                      const SkeletonLoader(itemCount: 3, itemHeight: 96),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
