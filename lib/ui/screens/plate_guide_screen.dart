import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import '../theme/language_controller.dart';
import '../widgets/widgets.dart';

/// Part 4 Feature #4: PLATE GUIDE
/// - Calls `KnowledgeService.plateGuide()`
/// - Renders `PlateGuide.imageBytes` with `Image.memory` (with a warm visual fallback
///   if synthetic demo bytes are non-decodable in isolated widget tests)
/// - Renders qualitative tips as cards with listen buttons
/// - Displays mandatory note: "General tips, not a diet prescription."
class PlateGuideScreen extends ConsumerStatefulWidget {
  const PlateGuideScreen({super.key});

  @override
  ConsumerState<PlateGuideScreen> createState() => _PlateGuideScreenState();
}

class _PlateGuideScreenState extends ConsumerState<PlateGuideScreen> {
  PlateGuide? _guide;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlateGuide();
  }

  Future<void> _loadPlateGuide() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final knowledge = ref.read(knowledgeServiceProvider);
      final res = await knowledge.plateGuide();
      if (!mounted) return;
      setState(() {
        _guide = res;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _speakTip(Bilingual tip) async {
    HapticFeedback.selectionClick();
    try {
      final lang = ref.read(languageModeProvider).primaryLang;
      await ref.read(voiceServiceProvider).speak(tip, lang: lang);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(languageModeProvider);

    return Directionality(
      textDirection: mode.direction,
      child: Scaffold(
        backgroundColor: AppTokens.surfaceCream,
        appBar: AppBar(
          title: const Text('Plate Guide • متوازن کھانے کی تھالی'),
          actions: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: LanguageToggle(compact: true),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.space2),
            child: _isLoading
                ? const SkeletonLoader(itemCount: 3, itemHeight: 110)
                : _error != null || _guide == null
                    ? ErrorState(
                        title: const Bilingual(
                          ur: 'غذائی گائیڈ لوڈ نہیں ہو سکی',
                          en: 'Could not load Plate Guide',
                        ),
                        onRetry: _loadPlateGuide,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const OfflineBanner(),

                          // Mandatory Disclaimer Banner ("General tips, not a diet prescription.")
                          const SafetyBanner(
                            key: Key('plate_guide_disclaimer_banner'),
                            title: Bilingual(
                              ur: 'یہ عام معلومات ہیں، باقاعدہ غذائی نسخہ نہیں۔',
                              en: 'General tips, not a diet prescription.',
                            ),
                            body: Bilingual(
                              ur: 'اس میں کیلوری کا حساب یا بیماری کا علاج شامل نہیں ہے۔ خاص پرہیز کے لیے اپنے ڈاکٹر سے مشورہ کریں۔',
                              en: 'No calorie targets or medical diet prescriptions. Consult your doctor for condition-specific guidance.',
                            ),
                          ),
                          const SizedBox(height: AppTokens.space2),

                          BiText(
                            _guide!.title,
                            isHeadline: true,
                            urduColor: AppTokens.primaryTealDark,
                          ),
                          const SizedBox(height: 12),

                          // PlateGuide.imageBytes rendered with Image.memory
                          Container(
                            height: 220,
                            decoration: BoxDecoration(
                              color: AppTokens.cardCream,
                              borderRadius:
                                  BorderRadius.circular(AppTokens.cardRadius),
                              border: Border.all(
                                color: AppTokens.primaryTeal,
                                width: 1.6,
                              ),
                              boxShadow: AppTokens.cardShadow,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _guide!.imageBytes.isNotEmpty
                                ? Image.memory(
                                    _guide!.imageBytes,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) =>
                                        const _BalancedPlateFallbackIllustration(),
                                  )
                                : const _BalancedPlateFallbackIllustration(),
                          ),
                          const SizedBox(height: AppTokens.space2),

                          const ReviewBadge(reviewed: false),
                          const SizedBox(height: AppTokens.space2),

                          // Qualitative Tips as Cards
                          for (int i = 0; i < _guide!.tips.length; i++) ...[
                            Container(
                              key: Key('plate_tip_card_$i'),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(AppTokens.space2),
                              decoration: BoxDecoration(
                                color: AppTokens.cardCream,
                                borderRadius:
                                    BorderRadius.circular(AppTokens.cardRadius),
                                border: Border.all(
                                  color: AppTokens.borderWarm,
                                  width: 1.4,
                                ),
                                boxShadow: AppTokens.cardShadow,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppTokens.primaryTealTint,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppTokens.primaryTealDark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: BiText(_guide!.tips[i]),
                                  ),
                                  IconButton(
                                    tooltip: 'Listen to tip • سنیں',
                                    icon: const Icon(
                                      Icons.volume_up_rounded,
                                      color: AppTokens.primaryTeal,
                                    ),
                                    onPressed: () =>
                                        _speakTip(_guide!.tips[i]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppTokens.space2),
                          SafetyBanner.prototype(),
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}

class _BalancedPlateFallbackIllustration extends StatelessWidget {
  const _BalancedPlateFallbackIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTokens.primaryTealSurface,
      padding: const EdgeInsets.all(AppTokens.space2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _PlateSectionBadge(
            icon: Icons.eco_rounded,
            color: AppTokens.successGreenDark,
            bg: AppTokens.successGreenTint,
            labelUr: 'آدھی تھالی سبزیاں',
            labelEn: '½ Vegetables & Salad',
          ),
          _PlateSectionBadge(
            icon: Icons.egg_alt_rounded,
            color: AppTokens.morningSaffronDark,
            bg: AppTokens.morningSaffronTint,
            labelUr: 'چوتھائی دال / گوشت',
            labelEn: '¼ Daal / Protein',
          ),
          _PlateSectionBadge(
            icon: Icons.bakery_dining_rounded,
            color: AppTokens.primaryTealDark,
            bg: AppTokens.primaryTealTint,
            labelUr: 'چوتھائی روٹی / چاول',
            labelEn: '¼ Whole Wheat Roti',
          ),
        ],
      ),
    );
  }
}

class _PlateSectionBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String labelUr;
  final String labelEn;

  const _PlateSectionBadge({
    required this.icon,
    required this.color,
    required this.bg,
    required this.labelUr,
    required this.labelEn,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 8),
            Text(
              labelUr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: color,
              ),
            ),
            Text(
              labelEn,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTokens.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
