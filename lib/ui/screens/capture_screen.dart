import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import '../theme/language_controller.dart';
import '../widgets/widgets.dart';
import 'journey_controller.dart';

class _PhotoTip {
  final IconData icon;
  final Bilingual title;
  final Bilingual subtitle;

  const _PhotoTip({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

/// Screen 4: Capture Screen
/// - image_picker camera/gallery
/// - guide overlay frame
/// - 3 tips with pictures (flat surface, good light, whole page)
/// - privacy guarantee: photo processed in memory only, never uploaded to storage
class CaptureScreen extends ConsumerStatefulWidget {
  final String initialSource;

  const CaptureScreen({
    super.key,
    this.initialSource = 'camera',
  });

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isPicking = false;

  static const List<_PhotoTip> _tips = [
    _PhotoTip(
      icon: Icons.crop_original_rounded,
      title: Bilingual(
        ur: '۱۔ کاغذ کو سیدھا اور ہموار رکھیں',
        en: '1. Lay the prescription flat on a table',
      ),
      subtitle: Bilingual(
        ur: 'نسخے میں سلوٹ یا موڑ نہ ہو تاکہ ہر دوا کا نام صاف نظر آئے۔',
        en: 'Keep creases smooth so handwriting and strengths stay clear.',
      ),
    ),
    _PhotoTip(
      icon: Icons.wb_sunny_rounded,
      title: Bilingual(
        ur: '۲۔ اچھی روشنی میں تصویر لیں',
        en: '2. Use good lighting without shadows',
      ),
      subtitle: Bilingual(
        ur: 'کھڑکی یا بلب کی روشنی میں تصویر لیں اور ہاتھ کا سایہ نہ پڑنے دیں۔',
        en: 'Avoid phone shadows or glare over the medicine names.',
      ),
    ),
    _PhotoTip(
      icon: Icons.fullscreen_rounded,
      title: Bilingual(
        ur: '۳۔ پورا صفحہ فریم کے اندر رکھیں',
        en: '3. Fit the whole prescription inside the guide frame',
      ),
      subtitle: Bilingual(
        ur: 'دوا کا نام، طاقت (mg) اور دن کی تعداد کٹنے نہ دیں۔',
        en: 'Include medicine names, mg strengths, and duration days.',
      ),
    ),
  ];

  Future<void> _pickImage(ImageSource source) async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 88,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        ref.read(journeyControllerProvider.notifier).setCapturedPhoto(bytes);
        context.pushReplacement('/reading');
      }
    } catch (_) {
      // On desktop/emulator or test environment where native camera isn't attached,
      // gracefully load synthetic demo Rx1 so the prototype never dead-ends.
      if (!mounted) return;
      ref
          .read(journeyControllerProvider.notifier)
          .stageDemoPrescription(DemoPrescriptionId.rx1);
      context.pushReplacement('/reading');
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  void _useSyntheticSample(DemoPrescriptionId demo) {
    HapticFeedback.mediumImpact();
    ref.read(journeyControllerProvider.notifier).stageDemoPrescription(demo);
    context.pushReplacement('/reading');
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(languageModeProvider);

    return Directionality(
      textDirection: mode.direction,
      child: Scaffold(
        backgroundColor: AppTokens.surfaceCream,
        appBar: AppBar(
          title: const Text('Capture Prescription • نسخے کی تصویر'),
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
                const OfflineBanner(),
                // Guide Overlay Frame
                Semantics(
                  label:
                      'Prescription alignment guide frame. Place full prescription inside the corners.',
                  child: Container(
                    height: 240,
                    padding: const EdgeInsets.all(AppTokens.space2),
                    decoration: BoxDecoration(
                      color: AppTokens.ink,
                      borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                      boxShadow: AppTokens.elevatedShadow,
                    ),
                    child: CustomPaint(
                      painter: _GuideFrameOverlayPainter(),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTokens.space2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color:
                                    AppTokens.primaryTeal.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTokens.primaryTealTint,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                size: 42,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const BiText(
                              Bilingual(
                                ur: 'نسخے کو ان چاروں کونوں کے اندر رکھیں',
                                en: 'Align the prescription inside the 4 corner guides',
                              ),
                              urduColor: Colors.white,
                              englishColor: AppTokens.primaryTealTint,
                              textAlign: TextAlign.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.space3),

                // 3 Pictorial Tips (flat, good light, whole page)
                const BiText(
                  Bilingual(
                    ur: 'واضح تصویر کے لیے ۳ آسان ہدایات:',
                    en: '3 Quick Tips for a Clear Reading:',
                  ),
                  isHeadline: true,
                ),
                const SizedBox(height: 12),
                for (final tip in _tips) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(AppTokens.space2),
                    decoration: BoxDecoration(
                      color: AppTokens.cardCream,
                      borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                      border:
                          Border.all(color: AppTokens.borderWarm, width: 1.3),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppTokens.primaryTealTint,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            tip.icon,
                            color: AppTokens.primaryTealDark,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              BiText(
                                tip.title,
                                urduWeight: FontWeight.w700,
                                englishWeight: FontWeight.w700,
                              ),
                              const SizedBox(height: 4),
                              BiText(tip.subtitle),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),

                // Action Buttons: Camera, Gallery, or Synthetic Demo Fallback
                BigActionButton(
                  key: const Key('capture_camera_button'),
                  icon: Icons.camera_alt_rounded,
                  label: const Bilingual(
                    ur: 'کیمرہ سے تصویر کھینچیں',
                    en: 'Open Camera & Snap Photo',
                  ),
                  onPressed: _isPicking
                      ? null
                      : () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(height: 12),
                BigActionButton(
                  key: const Key('capture_gallery_button'),
                  icon: Icons.photo_library_rounded,
                  isPrimary: false,
                  label: const Bilingual(
                    ur: 'گیلری سے تصویر منتخب کریں',
                    en: 'Pick Prescription from Gallery',
                  ),
                  onPressed: _isPicking
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                ),
                const SizedBox(height: 12),
                BigActionButton(
                  key: const Key('capture_use_demo_rx1_button'),
                  icon: Icons.science_rounded,
                  isPrimary: false,
                  backgroundColor: AppTokens.morningSaffronTint,
                  iconBadgeColor: AppTokens.morningSaffron,
                  label: const Bilingual(
                    ur: 'فرضی نسخہ ۱ استعمال کریں (ڈیمو)',
                    en: 'Use Sample Demo Prescription (Rx 1)',
                  ),
                  onPressed: () => _useSyntheticSample(DemoPrescriptionId.rx1),
                ),
                const SizedBox(height: AppTokens.space2),
                // Privacy assurance (Rule #6)
                const SafetyBanner(
                  title: Bilingual(
                    ur: 'آپ کی رازداری محفوظ ہے',
                    en: 'Privacy first: processed in memory only',
                  ),
                  body: Bilingual(
                    ur: 'نسخے کی تصویر کسی سرور پر محفوظ نہیں کی جاتی۔',
                    en: 'Prescription photos are never saved to cloud storage.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideFrameOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dashedPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final frameRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
      const Radius.circular(18),
    );
    canvas.drawRRect(frameRect, dashedPaint);

    final cornerPaint = Paint()
      ..color = AppTokens.morningSaffron
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.5;

    const c = 28.0;
    const m = 8.0;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(const Offset(m, m + c), const Offset(m, m), cornerPaint);
    canvas.drawLine(const Offset(m, m), const Offset(m + c, m), cornerPaint);

    // Top-right
    canvas.drawLine(Offset(w - m - c, m), Offset(w - m, m), cornerPaint);
    canvas.drawLine(Offset(w - m, m), Offset(w - m, m + c), cornerPaint);

    // Bottom-left
    canvas.drawLine(Offset(m, h - m - c), Offset(m, h - m), cornerPaint);
    canvas.drawLine(Offset(m, h - m), Offset(m + c, h - m), cornerPaint);

    // Bottom-right
    canvas.drawLine(
      Offset(w - m - c, h - m),
      Offset(w - m, h - m),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(w - m, h - m - c),
      Offset(w - m, h - m),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
