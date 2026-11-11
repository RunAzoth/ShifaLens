import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import '../theme/language_controller.dart';
import '../widgets/widgets.dart';

class _OnboardingSlideData {
  final IconData primaryIcon;
  final IconData badgeIcon;
  final Color accentColor;
  final Color tintColor;
  final Bilingual title;
  final Bilingual subtitle;
  final List<MealSlot> previewSlots;

  const _OnboardingSlideData({
    required this.primaryIcon,
    required this.badgeIcon,
    required this.accentColor,
    required this.tintColor,
    required this.title,
    required this.subtitle,
    this.previewSlots = const [],
  });
}

/// Screen 2: Onboarding (3 pictorial slides) + mandatory consent checkbox/tap gate:
/// "This is a prototype using synthetic data. AI can make mistakes.
/// Always confirm with your pharmacist or doctor." Require a tap to continue.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentSlide = 0;
  bool _consentChecked = false;

  static const List<_OnboardingSlideData> _slides = [
    _OnboardingSlideData(
      primaryIcon: Icons.document_scanner_rounded,
      badgeIcon: Icons.camera_alt_rounded,
      accentColor: AppTokens.primaryTeal,
      tintColor: AppTokens.primaryTealTint,
      title: Bilingual(
        ur: '۱۔ نسخے کی تصویر لیں اور تصدیق کریں',
        en: '1. Snap your prescription & verify every line',
      ),
      subtitle: Bilingual(
        ur: 'مصنوعی ذہانت (AI) نسخہ پڑھتی ہے، اور مشکوک یا غیر واضح الفاظ پر پیلا نشان لگا کر آپ کو فارماسسٹ سے پوچھنے کی یاد دہانی کراتی ہے۔',
        en: 'AI reads the handwriting and flags any uncertain medicine in amber so nothing unconfirmed ever becomes a schedule.',
      ),
    ),
    _OnboardingSlideData(
      primaryIcon: Icons.wb_sunny_rounded,
      badgeIcon: Icons.nights_stay_rounded,
      accentColor: AppTokens.morningSaffronDark,
      tintColor: AppTokens.morningSaffronTint,
      title: Bilingual(
        ur: '۲۔ سورج، چاند اور کھانے کے اوقات کے ساتھ آسان شیڈول',
        en: '2. Picture-first daily timeline around your meals',
      ),
      subtitle: Bilingual(
        ur: 'ہر دوا کو ایک منفرد رنگ، شکل اور حرف (A, B, C) ملتا ہے تاکہ کم پڑھے لکھے افراد اور بزرگ آسانی سے پہچان سکیں۔',
        en: 'Every medicine gets its own shape, color, and letter badge paired with breakfast, lunch, dinner, and bedtime icons.',
      ),
      previewSlots: [
        MealSlot.breakfast,
        MealSlot.lunch,
        MealSlot.dinner,
        MealSlot.bedtime,
      ],
    ),
    _OnboardingSlideData(
      primaryIcon: Icons.verified_user_rounded,
      badgeIcon: Icons.local_pharmacy_rounded,
      accentColor: AppTokens.eveningIndigo,
      tintColor: AppTokens.eveningIndigoTint,
      title: Bilingual(
        ur: '۳۔ محفوظ اصول، اردو آواز اور فارماسسٹ کی رہنمائی',
        en: '3. Verified safety cards, Urdu voice & caregiver sharing',
      ),
      subtitle: Bilingual(
        ur: 'پرہیز، خوراک کے اصول اور مضر اثرات صرف تصدیق شدہ جدول سے آتے ہیں۔ مصنوعی ذہانت خود سے کوئی خوراک تجویز نہیں کرتی۔',
        en: 'Food rules, duplicate alerts, and side effects come strictly from curated tables—never invented by AI.',
      ),
    ),
  ];

  static const Bilingual consentStatement = Bilingual(
    ur: 'یہ ایک تجرباتی نمونہ (Prototype) ہے جو فرضی ڈیٹا استعمال کرتا ہے۔ مصنوعی ذہانت (AI) سے غلطی ہو سکتی ہے۔ ہمیشہ اپنے فارماسسٹ یا ڈاکٹر سے تصدیق کریں۔',
    en: 'This is a prototype using synthetic data. AI can make mistakes. Always confirm with your pharmacist or doctor.',
  );

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(languageModeProvider);
    final slide = _slides[_currentSlide];
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget slideCard = Container(
      key: ValueKey<int>(_currentSlide),
      padding: const EdgeInsets.all(AppTokens.space3),
      decoration: BoxDecoration(
        color: AppTokens.cardCream,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        border: Border.all(color: AppTokens.borderWarm, width: 1.5),
        boxShadow: AppTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: slide.tintColor,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: slide.accentColor.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    slide.primaryIcon,
                    size: 48,
                    color: slide.accentColor,
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: slide.accentColor),
                      ),
                      child: Icon(
                        slide.badgeIcon,
                        size: 16,
                        color: slide.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTokens.space2),
          if (slide.previewSlots.isNotEmpty) ...[
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (int i = 0; i < slide.previewSlots.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SlotIcon(slide.previewSlots[i], size: 44),
                      const SizedBox(width: 6),
                      PillBadge(i, size: 40),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.space2),
          ],
          BiText(
            slide.title,
            isHeadline: true,
            urduColor: slide.accentColor,
          ),
          const SizedBox(height: AppTokens.space1),
          BiText(slide.subtitle),
          const SizedBox(height: AppTokens.space2),
          // Slide selector pills (1, 2, 3)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            children: List.generate(_slides.length, (index) {
              final active = index == _currentSlide;
              return Semantics(
                button: true,
                selected: active,
                label: 'Slide ${index + 1} of ${_slides.length}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _currentSlide = index);
                  },
                  child: AnimatedContainer(
                    duration: AppTokens.motionFast,
                    constraints: const BoxConstraints(
                      minWidth: 56,
                      minHeight: 44,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? AppTokens.primaryTeal
                          : AppTokens.surfaceWarm,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active
                            ? AppTokens.primaryTealDark
                            : AppTokens.borderWarm,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1} / ${_slides.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: active ? Colors.white : AppTokens.ink,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );

    if (!reduceMotion) {
      slideCard = slideCard
          .animate(key: ValueKey<int>(_currentSlide))
          .fadeIn(duration: AppTokens.motionFast)
          .slideY(begin: 0.04, end: 0, duration: AppTokens.motionFast);
    }

    return Directionality(
      textDirection: mode.direction,
      child: Scaffold(
        backgroundColor: AppTokens.surfaceCream,
        appBar: AppBar(
          title: const Text('ShifaLens • شفا لینز'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                slideCard,
                const SizedBox(height: AppTokens.space2),
                Row(
                  children: [
                    if (_currentSlide > 0) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() => _currentSlide--);
                          },
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Previous • پچھلا'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (_currentSlide < _slides.length - 1)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() => _currentSlide++);
                          },
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Next Slide • اگلا'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTokens.space2),
                // Mandatory interactive consent box
                Semantics(
                  checkbox: true,
                  checked: _consentChecked,
                  label: '${consentStatement.ur}. ${consentStatement.en}',
                  child: Material(
                    color: _consentChecked
                        ? AppTokens.primaryTealSurface
                        : AppTokens.warningAmberTint,
                    borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                    child: InkWell(
                      key: const Key('onboarding_consent_tile'),
                      borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        setState(() => _consentChecked = !_consentChecked);
                      },
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: AppTokens.heroTapTarget,
                        ),
                        padding: const EdgeInsets.all(AppTokens.space2),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppTokens.cardRadius),
                          border: Border.all(
                            color: _consentChecked
                                ? AppTokens.primaryTeal
                                : AppTokens.warningAmber,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: _consentChecked
                                    ? AppTokens.primaryTeal
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _consentChecked
                                      ? AppTokens.primaryTealDark
                                      : AppTokens.warningAmberDark,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                _consentChecked
                                    ? Icons.check_rounded
                                    : Icons.touch_app_rounded,
                                color: _consentChecked
                                    ? Colors.white
                                    : AppTokens.warningAmberDark,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const BiText(
                                    Bilingual(
                                      ur: 'میں سمجھتا/سمجھتی ہوں (آگے بڑھنے کے لیے یہاں ٹیپ کریں):',
                                      en: 'Tap here to confirm you understand:',
                                    ),
                                    urduWeight: FontWeight.w700,
                                    englishWeight: FontWeight.w700,
                                  ),
                                  const SizedBox(height: 6),
                                  const BiText(consentStatement),
                                  const SizedBox(height: 6),
                                  const BiText(
                                    Bilingual(
                                      ur: 'یہ ایک تجرباتی نمونہ ہے، طبی آلہ نہیں۔',
                                      en: 'Prototype. Not a medical device.',
                                    ),
                                    urduColor: AppTokens.primaryTealDark,
                                    englishColor: AppTokens.primaryTealDark,
                                    urduWeight: FontWeight.w700,
                                    englishWeight: FontWeight.w700,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.space2),
                BigActionButton(
                  key: const Key('onboarding_continue_button'),
                  icon: Icons.check_circle_outline_rounded,
                  label: const Bilingual(
                    ur: 'میں متفق ہوں — شروع کریں',
                    en: 'I understand — Continue to ShifaLens',
                  ),
                  onPressed: _consentChecked
                      ? () {
                          HapticFeedback.mediumImpact();
                          ref
                              .read(consentAcceptedProvider.notifier)
                              .setAccepted(true);
                          context.go('/home');
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
