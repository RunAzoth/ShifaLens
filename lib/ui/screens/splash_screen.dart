import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import '../theme/language_controller.dart';
import '../widgets/widgets.dart';

/// Screen 1: Splash screen with ShifaLens pharmacist emblem + bilingual tagline,
/// fade & scale entrance animation, and automatic transition to Onboarding / Home.
class SplashScreen extends ConsumerStatefulWidget {
  final bool autoNavigate;

  const SplashScreen({
    super.key,
    this.autoNavigate = true,
  });

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoNavigate) {
      _timer = Timer(const Duration(milliseconds: 1400), _goNext);
    }
  }

  void _goNext() {
    if (!mounted) return;
    final consented = ref.read(consentAcceptedProvider);
    context.go(consented ? '/home' : '/onboarding');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget heroContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: AppTokens.primaryTeal,
            borderRadius: BorderRadius.circular(34),
            boxShadow: AppTokens.elevatedShadow,
            border: Border.all(
              color: AppTokens.primaryTealTint,
              width: 4,
            ),
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.medication_liquid_rounded,
                size: 58,
                color: Colors.white,
              ),
              Positioned(
                right: 14,
                bottom: 14,
                child: Icon(
                  Icons.wb_sunny_rounded,
                  size: 26,
                  color: AppTokens.morningSaffronTint,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space3),
        const BiText(
          Bilingual(
            ur: 'شفا لینز — آپ کا گھریلو فارماسسٹ',
            en: 'ShifaLens',
          ),
          isHeadline: true,
          urduSize: 30,
          englishSize: 24,
          urduColor: AppTokens.primaryTealDark,
          englishColor: AppTokens.primaryTealDark,
          textAlign: TextAlign.center,
          crossAxisAlignment: CrossAxisAlignment.center,
        ),
        const SizedBox(height: AppTokens.space2),
        const BiText(
          Bilingual(
            ur: 'ہر مریض کے لیے فارماسسٹ کی آسان وضاحت، اردو میں، تصویروں کے ساتھ۔',
            en: "A pharmacist's explanation for every patient, in Urdu, with pictures.",
          ),
          urduSize: 22,
          englishSize: 16,
          textAlign: TextAlign.center,
          crossAxisAlignment: CrossAxisAlignment.center,
        ),
        const SizedBox(height: AppTokens.space4),
        SafetyBanner.prototype(),
      ],
    );

    if (!reduceMotion) {
      heroContent = heroContent
          .animate()
          .fadeIn(duration: AppTokens.motionMedium, curve: Curves.easeOut)
          .scale(
            begin: const Offset(0.92, 0.92),
            end: const Offset(1.0, 1.0),
            duration: AppTokens.motionMedium,
            curve: Curves.easeOutBack,
          );
    }

    return Scaffold(
      backgroundColor: AppTokens.surfaceCream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.space3),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  heroContent,
                  const SizedBox(height: AppTokens.space3),
                  BigActionButton(
                    icon: Icons.arrow_forward_rounded,
                    label: const Bilingual(
                      ur: 'آگے بڑھیں',
                      en: 'Continue',
                    ),
                    onPressed: _goNext,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
