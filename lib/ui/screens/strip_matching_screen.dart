import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/providers.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import '../theme/language_controller.dart';
import '../widgets/widgets.dart';
import 'journey_controller.dart';

class _CapturedStripPhoto {
  final String label;
  final Uint8List bytes;

  const _CapturedStripPhoto({
    required this.label,
    required this.bytes,
  });
}

/// Part 4 Feature #5: STRIP MATCHING FLOW
/// - "Photograph your medicine strips" (up to 6, multi-capture grid with delete)
/// - Scan animation while calling `StripMatcher.match(strips, plan.scheduled)`
/// - Results list pairing each strip photo with its PillBadge OR an issue chip:
///   - `StripIssue.strengthMismatch`
///   - `StripIssue.notInPrescription`
///   - `StripIssue.unreadable`
///   in plain bilingual language.
/// - Uncertain results (`confidence < 0.75` or `issue != StripIssue.none` or
///   `matchedMedicineId == null`) NEVER show as matched!
/// - Any prescribed medicine with no matched strip is also explicitly listed.
/// - "Make stickers" CTA button navigates to `/print?mode=stickers`.
class StripMatchingScreen extends ConsumerStatefulWidget {
  const StripMatchingScreen({super.key});

  @override
  ConsumerState<StripMatchingScreen> createState() =>
      _StripMatchingScreenState();
}

class _StripMatchingScreenState extends ConsumerState<StripMatchingScreen> {
  static const int maxStrips = 6;
  final ImagePicker _picker = ImagePicker();
  final List<_CapturedStripPhoto> _strips = [];
  List<StripMatch>? _results;
  bool _isScanning = false;
  String? _error;

  void _addSyntheticSampleSet(List<MedicineLine> scheduled) {
    HapticFeedback.mediumImpact();
    setState(() {
      _strips.clear();
      _results = null;
      // Add sample strips covering matched, strength mismatch, and not-in-prescription
      for (int i = 0; i < scheduled.length && _strips.length < 2; i++) {
        final med = scheduled[i];
        _strips.add(
          _CapturedStripPhoto(
            label: '${med.brandName ?? med.rawText} ${med.strength ?? ""}',
            bytes: Uint8List.fromList(
              utf8.encode('SHIFALENS_STRIP:MATCH:${med.id}'),
            ),
          ),
        );
      }
      if (_strips.length < maxStrips) {
        _strips.add(
          _CapturedStripPhoto(
            label: 'Strip • Strength Mismatch (250 mg)',
            bytes: Uint8List.fromList(
              utf8.encode('SHIFALENS_STRIP:STRENGTH_MISMATCH'),
            ),
          ),
        );
      }
      if (_strips.length < maxStrips) {
        _strips.add(
          _CapturedStripPhoto(
            label: 'Strip • Unknown / Blister Foil',
            bytes: Uint8List.fromList(
              utf8.encode('SHIFALENS_STRIP:NOT_IN_RX'),
            ),
          ),
        );
      }
    });
  }

  Future<void> _pickStripFrom(ImageSource source) async {
    if (_strips.length >= maxStrips) return;
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1400,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _strips.add(
            _CapturedStripPhoto(
              label: 'Strip #${_strips.length + 1}',
              bytes: bytes,
            ),
          );
          _results = null;
        });
      }
    } catch (_) {
      // Fallback on desktop/test environment without native camera
      if (!mounted) return;
      setState(() {
        final idx = _strips.length + 1;
        _strips.add(
          _CapturedStripPhoto(
            label: 'Demo Strip #$idx',
            bytes: Uint8List.fromList(
              utf8.encode('SHIFALENS_STRIP:DEMO:$idx'),
            ),
          ),
        );
        _results = null;
      });
    }
  }

  void _removeStripAt(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _strips.removeAt(index);
      _results = null;
    });
  }

  Future<void> _runStripMatching(List<MedicineLine> scheduled) async {
    if (_strips.isEmpty || _isScanning) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isScanning = true;
      _error = null;
    });

    try {
      final matcher = ref.read(stripMatcherProvider);
      final rawBytes = _strips.map((s) => s.bytes).toList();
      final matches = await matcher.match(rawBytes, scheduled);
      if (!mounted) return;
      setState(() {
        _results = matches;
        _isScanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _error = e.toString();
      });
    }
  }

  /// Rule: Uncertain results NEVER show as matched.
  bool _isConfidentlyMatched(StripMatch m, List<MedicineLine> scheduled) {
    if (m.issue != StripIssue.none) return false;
    if (m.matchedMedicineId == null) return false;
    if (m.confidence < 0.75) return false;
    return scheduled.any((med) => med.id == m.matchedMedicineId);
  }

  static ({Bilingual title, Bilingual detail, Color fg, Color bg, IconData icon})
      _issueVisual(StripIssue issue) {
    switch (issue) {
      case StripIssue.strengthMismatch:
        return (
          title: const Bilingual(
            ur: 'طاقت (mg) مختلف ہے — فارماسسٹ سے پوچھیں',
            en: 'Strength mismatch — check mg with pharmacist',
          ),
          detail: const Bilingual(
            ur: 'اس پتے پر لکھی طاقت (mg) آپ کے نسخے کی طاقت سے میل نہیں کھاتی۔',
            en: 'The mg strength printed on this strip does not match your prescription.',
          ),
          fg: AppTokens.warningAmberDark,
          bg: AppTokens.warningAmberTint,
          icon: Icons.scale_rounded,
        );
      case StripIssue.notInPrescription:
        return (
          title: const Bilingual(
            ur: 'یہ دوا اس نسخے میں شامل نہیں ہے',
            en: 'Not in this prescription',
          ),
          detail: const Bilingual(
            ur: 'یہ پتہ آپ کے موجودہ تصدیق شدہ نسخے کی کسی دوا سے نہیں ملتا۔',
            en: 'This medicine strip does not belong to your current confirmed prescription.',
          ),
          fg: AppTokens.alertCoralDark,
          bg: AppTokens.alertCoralTint,
          icon: Icons.block_rounded,
        );
      case StripIssue.unreadable:
      case StripIssue.none:
        return (
          title: const Bilingual(
            ur: 'پتے کی لکھائی صاف نہیں پڑھی جا سکی',
            en: 'Unreadable / uncertain strip — ask pharmacist',
          ),
          detail: const Bilingual(
            ur: 'چمک یا دھندلے پن کی وجہ سے نام واضح نہیں ہے۔ خود سے اندازہ نہ لگائیں۔',
            en: 'Foil glare or blur prevented a confident match. Never guess—verify with your pharmacist.',
          ),
          fg: AppTokens.warningAmberDark,
          bg: AppTokens.warningAmberTint,
          icon: Icons.help_outline_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(languageModeProvider);
    final journey = ref.watch(journeyControllerProvider);
    final plan = journey.latestPlan;
    final scheduled = plan?.scheduled ?? const <MedicineLine>[];
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final matchedMedIds = <String>{};
    if (_results != null) {
      for (final r in _results!) {
        if (_isConfidentlyMatched(r, scheduled)) {
          matchedMedIds.add(r.matchedMedicineId!);
        }
      }
    }
    final unmatchedPrescribedMeds =
        scheduled.where((m) => !matchedMedIds.contains(m.id)).toList();

    return Directionality(
      textDirection: mode.direction,
      child: Scaffold(
        backgroundColor: AppTokens.surfaceCream,
        appBar: AppBar(
          title: const Text('Match Medicine Strips • دوا کے پتے ملائیں'),
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
                const AiTag(),
                const SizedBox(height: 12),

                const BiText(
                  Bilingual(
                    ur: 'اپنی دوا کے پتوں (Strips) کی تصویر لیں (زیادہ سے زیادہ ۶)',
                    en: 'Photograph your medicine strips (up to 6)',
                  ),
                  isHeadline: true,
                  urduColor: AppTokens.primaryTealDark,
                ),
                const SizedBox(height: 6),
                const BiText(
                  Bilingual(
                    ur: 'شفا لینز ہر پتے کو آپ کے نسخے کے نشان (A, B, C) سے ملائے گا اور غلط طاقت یا اجنبی پتے پر خبردار کرے گا۔',
                    en: 'ShifaLens pairs each physical strip with its PillBadge symbol and flags any wrong strength or extra medicine.',
                  ),
                ),
                const SizedBox(height: 14),

                // Multi-Capture Grid (up to 6 strips with delete button)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _strips.length < maxStrips
                      ? _strips.length + 1
                      : maxStrips,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                  ),
                  itemBuilder: (context, index) {
                    if (index == _strips.length && _strips.length < maxStrips) {
                      return Semantics(
                        button: true,
                        label:
                            'Add strip photo (${_strips.length} of $maxStrips added)',
                        child: InkWell(
                          key: const Key('strip_add_tile'),
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _pickStripFrom(ImageSource.camera),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTokens.primaryTealSurface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTokens.primaryTeal,
                                width: 1.8,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_a_photo_rounded,
                                  size: 34,
                                  color: AppTokens.primaryTealDark,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Add Strip (${_strips.length}/$maxStrips)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTokens.primaryTealDark,
                                  ),
                                ),
                                const Text(
                                  'پتے کی تصویر شامل کریں',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: AppTokens.primaryTealDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final strip = _strips[index];
                    return Container(
                      key: Key('strip_grid_tile_$index'),
                      decoration: BoxDecoration(
                        color: AppTokens.ink,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTokens.borderWarm,
                          width: 1.5,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.medication_rounded,
                                  color: AppTokens.primaryTealTint,
                                  size: 32,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  strip.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Semantics(
                              button: true,
                              label: 'Delete strip #${index + 1}',
                              child: IconButton.filled(
                                key: Key('strip_delete_$index'),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppTokens.alertCoral,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                ),
                                onPressed: () => _removeStripAt(index),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Quick Load Demo Strips + Scan Action
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('strip_load_demo_set_button'),
                        onPressed: () => _addSyntheticSampleSet(scheduled),
                        icon: const Icon(Icons.science_rounded),
                        label: const Text('Load Demo Strips • فرضی پتے'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _strips.length >= maxStrips
                            ? null
                            : () => _pickStripFrom(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text('Gallery • گیلری'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                BigActionButton(
                  key: const Key('strip_match_scan_button'),
                  icon: Icons.qr_code_scanner_rounded,
                  label: Bilingual(
                    ur: 'پتوں کو نسخے سے ملائیں (${_strips.length} پتے)',
                    en: 'Match Strips with My Prescription (${_strips.length})',
                  ),
                  onPressed: _strips.isEmpty || _isScanning
                      ? null
                      : () => _runStripMatching(scheduled),
                ),

                // Scanning Animation
                if (_isScanning) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(AppTokens.space2),
                    decoration: BoxDecoration(
                      color: AppTokens.primaryTealSurface,
                      borderRadius:
                          BorderRadius.circular(AppTokens.cardRadius),
                      border: Border.all(color: AppTokens.primaryTeal),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: BiText(
                            Bilingual(
                              ur: 'دوا کے پتوں کے نام اور طاقت (mg) چیک کی جا رہی ہے...',
                              en: 'Scanning strip text and checking mg strengths...',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SkeletonLoader(itemCount: 2, itemHeight: 100),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  ErrorState(
                    onRetry: () => _runStripMatching(scheduled),
                  ),
                ],

                // Results Section
                if (_results != null && !_isScanning) ...[
                  const SizedBox(height: AppTokens.space3),
                  const BiText(
                    Bilingual(
                      ur: 'ملانے کا نتیجہ (تصدیق شدہ بمقابلہ مشکوک پتے):',
                      en: 'Strip Matching Results:',
                    ),
                    isHeadline: true,
                  ),
                  const SizedBox(height: 12),

                  for (int i = 0; i < _results!.length; i++) ...[
                    Builder(
                      builder: (context) {
                        final match = _results![i];
                        final isMatched =
                            _isConfidentlyMatched(match, scheduled);
                        final med = isMatched
                            ? scheduled
                                .where((m) => m.id == match.matchedMedicineId)
                                .firstOrNull
                            : null;
                        final stripLabel = i < _strips.length
                            ? _strips[i].label
                            : 'Strip #${match.imageIndex + 1}';

                        if (isMatched && med != null) {
                          final card = Container(
                            key: Key('strip_result_matched_$i'),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(AppTokens.space2),
                            decoration: BoxDecoration(
                              color: AppTokens.successGreenTint,
                              borderRadius:
                                  BorderRadius.circular(AppTokens.cardRadius),
                              border: Border.all(
                                color: AppTokens.successGreen,
                                width: 1.8,
                              ),
                            ),
                            child: Row(
                              children: [
                                PillBadge(med.identityIndex, size: 54),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      BiText(
                                        Bilingual(
                                          ur: 'مکمل میل کھاتا ہے: ${med.brandName ?? med.rawText} (${med.strength ?? ""})',
                                          en: 'Matched: ${med.brandName ?? med.rawText} ${med.strength ?? ""}',
                                        ),
                                        urduColor: AppTokens.successGreenDark,
                                        englishColor:
                                            AppTokens.successGreenDark,
                                        urduWeight: FontWeight.w700,
                                        englishWeight: FontWeight.w700,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Read on strip: "${match.readText ?? stripLabel}"',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppTokens.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: AppTokens.successGreenDark,
                                  size: 30,
                                ),
                              ],
                            ),
                          );
                          return reduceMotion
                              ? card
                              : card.animate().fadeIn(
                                    duration: AppTokens.motionFast,
                                  );
                        }

                        // Uncertain or Mismatched Result (NEVER shown as matched!)
                        final issueVis = _issueVisual(match.issue);
                        return Container(
                          key: Key('strip_result_issue_$i'),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(AppTokens.space2),
                          decoration: BoxDecoration(
                            color: issueVis.bg,
                            borderRadius:
                                BorderRadius.circular(AppTokens.cardRadius),
                            border: Border.all(
                              color: issueVis.fg,
                              width: 1.8,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  issueVis.icon,
                                  color: issueVis.fg,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    BiText(
                                      issueVis.title,
                                      urduColor: issueVis.fg,
                                      englishColor: issueVis.fg,
                                      urduWeight: FontWeight.w700,
                                      englishWeight: FontWeight.w700,
                                    ),
                                    const SizedBox(height: 4),
                                    BiText(issueVis.detail),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Strip text: "${match.readText ?? stripLabel}"',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppTokens.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  // Prescribed medicines with NO strip photographed yet
                  if (unmatchedPrescribedMeds.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      key: const Key('strip_missing_prescribed_section'),
                      padding: const EdgeInsets.all(AppTokens.space2),
                      decoration: BoxDecoration(
                        color: AppTokens.surfaceWarm,
                        borderRadius:
                            BorderRadius.circular(AppTokens.cardRadius),
                        border: Border.all(
                          color: AppTokens.borderWarm,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const BiText(
                            Bilingual(
                              ur: 'نسخے کی وہ دوائیں جن کا پتہ ابھی شامل نہیں ہوا:',
                              en: 'Prescribed medicines with no matched strip yet:',
                            ),
                            isHeadline: true,
                          ),
                          const SizedBox(height: 10),
                          for (final missing in unmatchedPrescribedMeds)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  PillBadge(missing.identityIndex, size: 44),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: BiText(
                                      Bilingual(
                                        ur: '${missing.brandName ?? missing.rawText} (${missing.strength ?? ""}) — پتہ موجود نہیں',
                                        en: '${missing.brandName ?? missing.rawText} ${missing.strength ?? ""} — No strip matched yet',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppTokens.space2),
                  BigActionButton(
                    key: const Key('strip_make_stickers_button'),
                    icon: Icons.print_rounded,
                    label: const Bilingual(
                      ur: 'پتوں پر لگانے کے لیے اسٹیکرز بنائیں',
                      en: 'Make stickers for my medicine strips',
                    ),
                    onPressed: () => context.push('/print?mode=stickers'),
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
