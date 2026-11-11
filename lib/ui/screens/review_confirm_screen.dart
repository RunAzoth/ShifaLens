import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import '../theme/language_controller.dart';
import '../widgets/widgets.dart';
import 'journey_controller.dart';
import 'manual_entry_sheet.dart';

/// Screen 6: Review & Confirm (the most important screen in Part 3)
/// - Pinned, zoomable photo thumbnail on top
/// - Visible AiTag ("AI-generated: verify with your pharmacist")
/// - DuplicateAlert banner shown immediately if duplicates exist in the list
/// - One card per MedicineLine showing PillBadge, brand, generic, strength, frequency,
///   duration, with a ConfidenceChip per field (name, strength, frequency, duration).
/// - Flagged lines (needsPharmacist) are amber with "Ask your pharmacist" and three
///   one-tap actions:
///     1. Fix it (inline edit sheet)
///     2. Keep as "ask pharmacist" (goes to the Not scheduled list)
///     3. Remove
/// - Confirm button stays disabled until every flagged line has been resolved, and says
///   "Confirm and make my plan (N medicines)".
class ReviewConfirmScreen extends ConsumerWidget {
  const ReviewConfirmScreen({super.key});

  List<DuplicateAlert> _computeDuplicates(
    WidgetRef ref,
    List<MedicineLine> lines,
  ) {
    try {
      final knowledge = ref.read(knowledgeServiceProvider);
      final found = knowledge.findDuplicates(lines);
      if (found.isNotEmpty) return found;
    } catch (_) {}

    // Deterministic fallback check by genericName so duplicate banner works
    // even if a mock knowledge service wasn't preloaded in a unit test
    final byGeneric = <String, List<MedicineLine>>{};
    for (final line in lines) {
      final g = line.genericName?.trim().toLowerCase();
      if (g != null && g.isNotEmpty) {
        byGeneric.putIfAbsent(g, () => []).add(line);
      }
    }

    final alerts = <DuplicateAlert>[];
    byGeneric.forEach((genericKey, matched) {
      if (matched.length > 1) {
        final names =
            matched.map((m) => m.brandName ?? m.rawText).join(' + ');
        final displayGeneric = matched.first.genericName ?? genericKey;
        alerts.add(
          DuplicateAlert(
            id: 'dup-$genericKey',
            sameGeneric: true,
            label: '$displayGeneric ($names)',
            medicineIds: matched.map((m) => m.id).toList(),
            message: Bilingual(
              ur: '$names میں ایک ہی دوا ($displayGeneric) شامل ہے۔ دونوں ایک ساتھ لینے سے پہلے فارماسسٹ سے ضرور پوچھیں۔',
              en: '$names contain the same active medicine ($displayGeneric). Confirm with your pharmacist before taking both.',
            ),
          ),
        );
      }
    });
    return alerts;
  }

  Future<void> _onConfirmPressed(BuildContext context, WidgetRef ref) async {
    HapticFeedback.heavyImpact();
    final plan = await ref
        .read(journeyControllerProvider.notifier)
        .confirmAndBuildPlan();
    if (plan != null && context.mounted) {
      context.go('/plan');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(languageModeProvider);
    final journey = ref.watch(journeyControllerProvider);
    final rx = journey.prescription;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (rx == null) {
      return Directionality(
        textDirection: mode.direction,
        child: Scaffold(
          backgroundColor: AppTokens.surfaceCream,
          appBar: AppBar(
            title: const Text('Review & Confirm • تصدیق کریں'),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.space2),
              child: EmptyState(
                icon: Icons.receipt_long_rounded,
                title: const Bilingual(
                  ur: 'ابھی کوئی نسخہ منتخب نہیں کیا گیا',
                  en: 'No prescription loaded yet',
                ),
                subtitle: const Bilingual(
                  ur: 'ہوم اسکرین سے نسخے کی تصویر لیں یا ڈیمو نسخہ منتخب کریں۔',
                  en: 'Take a photo or choose a demo prescription from Home.',
                ),
                actionLabel: const Bilingual(
                  ur: 'واپس ہوم اسکرین پر جائیں',
                  en: 'Back to Home',
                ),
                onAction: () => context.go('/home'),
              ),
            ),
          ),
        ),
      );
    }

    final lines = rx.lines;
    final duplicates = _computeDuplicates(ref, lines);
    final unresolvedCount = journey.unresolvedFlaggedCount;
    final canConfirm = journey.canConfirmPlan;
    final totalCount = journey.totalMedicinesCount;

    return Directionality(
      textDirection: mode.direction,
      child: Scaffold(
        backgroundColor: AppTokens.surfaceCream,
        appBar: AppBar(
          title: const Text('Review & Confirm • جائزہ اور تصدیق'),
          actions: [
            IconButton(
              tooltip: 'Add Medicine Manually',
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: () => ManualEntrySheet.show(context),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12, left: 4),
              child: LanguageToggle(compact: true),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pinned Zoomable Prescription Photo Thumbnail on Top
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.space2,
                  8,
                  AppTokens.space2,
                  8,
                ),
                child: _PinnedZoomablePrescriptionHeader(
                  imageBytes: journey.capturedImageBytes,
                  lines: lines,
                  unresolvedCount: unresolvedCount,
                ),
              ),

              // Scrollable List of Banners + MedicineLine Cards
              Expanded(
                child: lines.isEmpty
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(AppTokens.space2),
                        child: EmptyState(
                          icon: Icons.medication_outlined,
                          title: const Bilingual(
                            ur: 'فہرست میں کوئی دوا باقی نہیں رہی',
                            en: 'No medicines in this list',
                          ),
                          subtitle: const Bilingual(
                            ur: 'شیڈول بنانے کے لیے کم از کم ایک دوا شامل کریں۔',
                            en: 'Add at least one medicine to build your daily plan.',
                          ),
                          actionLabel: const Bilingual(
                            ur: 'ہاتھ سے دوا شامل کریں',
                            en: 'Add medicine manually',
                          ),
                          onAction: () => ManualEntrySheet.show(context),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.space2,
                          vertical: 8,
                        ),
                        children: [
                          const OfflineBanner(),
                          const AiTag(),
                          const SizedBox(height: 12),

                          // Unresolved flagged items callout
                          if (unresolvedCount > 0) ...[
                            SafetyBanner(
                              key: const Key('unresolved_flagged_banner'),
                              variant: SafetyBannerVariant.pharmacistNotice,
                              title: Bilingual(
                                ur: '$unresolvedCount غیر واضح دوا پر آپ کا فیصلہ باقی ہے',
                                en: '$unresolvedCount flagged medicine(s) need your action below',
                              ),
                              body: const Bilingual(
                                ur: 'پیلی کارڈ والی دوا کو "درست کریں"، "فارماسسٹ سے پوچھنے کے لیے رکھیں" یا "ہٹا دیں" تاکہ تصدیق کا بٹن کھل سکے۔',
                                en: 'Resolve each amber "Ask your pharmacist" card (Fix it, Keep as ask pharmacist, or Remove) to enable Confirm.',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // DuplicateAlerts banner shown here already
                          for (final dup in duplicates) ...[
                            SafetyBanner.fromDuplicate(
                              dup,
                              key: Key('duplicate_banner_${dup.id}'),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // MedicineLine Cards
                          for (int i = 0; i < lines.length; i++) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppTokens.space2),
                              child: reduceMotion
                                  ? _MedicineReviewCard(
                                      line: lines[i],
                                      isUnresolved:
                                          journey.isLineUnresolved(lines[i]),
                                      isKeptForPharmacist: journey
                                          .keptAsPharmacistIds
                                          .contains(lines[i].id),
                                    )
                                  : _MedicineReviewCard(
                                      line: lines[i],
                                      isUnresolved:
                                          journey.isLineUnresolved(lines[i]),
                                      isKeptForPharmacist: journey
                                          .keptAsPharmacistIds
                                          .contains(lines[i].id),
                                    ).animate().fadeIn(
                                        delay: Duration(milliseconds: 45 * i),
                                        duration: AppTokens.motionFast,
                                      ),
                            ),
                          ],

                          // Add another medicine manually button
                          OutlinedButton.icon(
                            key: const Key('review_add_medicine_button'),
                            onPressed: () => ManualEntrySheet.show(context),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text(
                              'Add another medicine • ایک اور دوا شامل کریں',
                            ),
                          ),
                          const SizedBox(height: AppTokens.space2),
                          SafetyBanner.prototype(),
                          const SizedBox(height: AppTokens.space2),
                        ],
                      ),
              ),

              // Bottom Pinned Confirm Bar
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.space2,
                  12,
                  AppTokens.space2,
                  12,
                ),
                decoration: BoxDecoration(
                  color: AppTokens.cardCream,
                  border: const Border(
                    top: BorderSide(color: AppTokens.borderWarm, width: 1.5),
                  ),
                  boxShadow: AppTokens.cardShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!canConfirm && lines.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: BiText(
                          Bilingual(
                            ur: 'پہلے اوپر دی گئی $unresolvedCount مشکوک دوا کا فیصلہ کریں',
                            en: 'Resolve $unresolvedCount flagged item(s) above to unlock Confirm',
                          ),
                          urduSize: 22,
                          englishSize: 16,
                          urduColor: AppTokens.warningAmberDark,
                          englishColor: AppTokens.warningAmberDark,
                          textAlign: TextAlign.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                        ),
                      ),
                    BigActionButton(
                      key: const Key('review_confirm_button'),
                      icon: Icons.verified_rounded,
                      label: Bilingual(
                        ur: 'تصدیق کریں اور میرا شیڈول بنائیں ($totalCount دوائیں)',
                        en: 'Confirm and make my plan ($totalCount medicines)',
                      ),
                      onPressed: canConfirm
                          ? () => _onConfirmPressed(context, ref)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinnedZoomablePrescriptionHeader extends StatelessWidget {
  final Uint8List? imageBytes;
  final List<MedicineLine> lines;
  final int unresolvedCount;

  const _PinnedZoomablePrescriptionHeader({
    required this.imageBytes,
    required this.lines,
    required this.unresolvedCount,
  });

  bool _isRealDecodableImage(Uint8List? bytes) {
    if (bytes == null || bytes.length < 64) return false;
    // Synthetic demo markers start with SHIFALENS_DEMO at byte 4
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Pinned prescription photo thumbnail. Pinch or double-tap to zoom in and compare handwriting.',
      child: Container(
        height: 118,
        decoration: BoxDecoration(
          color: AppTokens.ink,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: unresolvedCount > 0
                ? AppTokens.warningAmber
                : AppTokens.primaryTeal,
            width: 2,
          ),
          boxShadow: AppTokens.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              minScale: 1.0,
              maxScale: 3.5,
              child: _isRealDecodableImage(imageBytes)
                  ? Image.memory(
                      imageBytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _SyntheticPaperPreview(lines: lines),
                    )
                  : _SyntheticPaperPreview(lines: lines),
            ),
            Positioned(
              right: 10,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTokens.ink.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.zoom_in_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Pinch to zoom • زوم کریں',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyntheticPaperPreview extends StatelessWidget {
  final List<MedicineLine> lines;

  const _SyntheticPaperPreview({required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDFBF7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 18,
                color: AppTokens.primaryTealDark,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Rx Prescription Scan (Synthetic Demo)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.primaryTealDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final line in lines.take(3))
            Text(
              '• ${line.rawText}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: line.needsPharmacist
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: line.needsPharmacist
                    ? AppTokens.warningAmberDark
                    : AppTokens.ink,
              ),
            ),
        ],
      ),
    );
  }
}

class _MedicineReviewCard extends ConsumerWidget {
  final MedicineLine line;
  final bool isUnresolved;
  final bool isKeptForPharmacist;

  const _MedicineReviewCard({
    required this.line,
    required this.isUnresolved,
    required this.isKeptForPharmacist,
  });

  double _conf(String key) => line.fieldConfidence[key] ?? 0.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFlagged = line.needsPharmacist;

    final cardBg = isFlagged
        ? AppTokens.warningAmberTint.withValues(alpha: 0.55)
        : AppTokens.cardCream;
    final borderColor = isFlagged
        ? (isUnresolved ? AppTokens.warningAmber : AppTokens.warningAmberDark)
        : AppTokens.borderWarm;

    final titleBrand = (line.brandName == null || line.brandName!.isEmpty)
        ? line.rawText
        : line.brandName!;
    final subtitleGeneric =
        (line.genericName == null || line.genericName!.isEmpty)
            ? 'فارمولا غیر واضح • Generic unknown'
            : line.genericName!;

    return Container(
      key: Key('medicine_card_${line.id}'),
      padding: const EdgeInsets.all(AppTokens.space2),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        border: Border.all(
          color: borderColor,
          width: isFlagged ? 2.2 : 1.4,
        ),
        boxShadow: AppTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Status Header for Flagged ("Ask your pharmacist") or Confirmed items
          if (isFlagged) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTokens.warningAmberTint,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTokens.warningAmber, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTokens.warningAmberDark,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BiText(
                      isKeptForPharmacist
                          ? const Bilingual(
                              ur: 'فارماسسٹ سے پوچھیں (شیڈول میں شامل نہیں کیا جائے گا)',
                              en: 'Ask your pharmacist (Kept in "Not scheduled" list)',
                            )
                          : const Bilingual(
                              ur: 'فارماسسٹ سے پوچھیں — لکھائی غیر واضح ہے',
                              en: 'Ask your pharmacist — low confidence reading',
                            ),
                      urduColor: AppTokens.warningAmberDark,
                      englishColor: AppTokens.warningAmberDark,
                      urduWeight: FontWeight.w700,
                      englishWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Identity PillBadge + Brand + Generic + Edit button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'pill_badge_${line.id}',
                child: PillBadge(line.identityIndex, size: 56),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BiText(
                      Bilingual(
                        ur: titleBrand,
                        en: '${line.form ?? "Medicine"} • $titleBrand',
                      ),
                      isHeadline: true,
                    ),
                    const SizedBox(height: 2),
                    BiText(
                      Bilingual(
                        ur: 'فارمولا: $subtitleGeneric',
                        en: 'Generic: $subtitleGeneric',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Raw Rx: "${line.rawText}"',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTokens.inkSubtle,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isFlagged)
                IconButton(
                  key: Key('edit_line_${line.id}'),
                  tooltip: 'Edit medicine',
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppTokens.primaryTealDark,
                  ),
                  onPressed: () =>
                      ManualEntrySheet.show(context, existingLine: line),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Field ConfidenceChips (name, strength, frequency, duration)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ConfidenceChip(
                fieldLabel: const Bilingual(ur: 'نام', en: 'Name'),
                valueText: line.brandName,
                confidence: _conf('name'),
              ),
              ConfidenceChip(
                fieldLabel: const Bilingual(ur: 'طاقت', en: 'Strength'),
                valueText: line.strength,
                confidence: _conf('strength'),
              ),
              ConfidenceChip(
                fieldLabel: const Bilingual(ur: 'اوقات', en: 'Frequency'),
                valueText: [
                  if (line.frequencyRaw != null) line.frequencyRaw!,
                  if (line.timingNote != null) '(${line.timingNote!})',
                ].join(' '),
                confidence: _conf('frequency'),
              ),
              ConfidenceChip(
                fieldLabel: const Bilingual(ur: 'مدت', en: 'Duration'),
                valueText: line.durationDays != null
                    ? '${line.durationDays} days'
                    : null,
                confidence: _conf('duration'),
              ),
            ],
          ),

          // Three One-Tap Actions for Flagged Lines (Fix it, Keep as "ask pharmacist", Remove)
          if (isFlagged) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const BiText(
              Bilingual(
                ur: 'آگے بڑھنے کے لیے ان ۳ میں سے ایک قدم منتخب کریں:',
                en: 'Choose one action to resolve this flagged line:',
              ),
              urduWeight: FontWeight.w700,
              englishWeight: FontWeight.w700,
            ),
            const SizedBox(height: 10),
            // 1. Fix it (opens inline ManualEntrySheet)
            BigActionButton(
              key: Key('flagged_fix_${line.id}'),
              icon: Icons.build_circle_outlined,
              label: const Bilingual(
                ur: '۱۔ خود درست کریں (نام اور خوراک لکھیں)',
                en: 'Fix it (edit medicine details)',
              ),
              onPressed: () =>
                  ManualEntrySheet.show(context, existingLine: line),
            ),
            const SizedBox(height: 10),
            // 2. Keep as "ask pharmacist" (goes to the Not scheduled list)
            BigActionButton(
              key: Key('flagged_keep_pharmacist_${line.id}'),
              icon: Icons.local_pharmacy_outlined,
              isPrimary: false,
              backgroundColor: isKeptForPharmacist
                  ? AppTokens.primaryTealTint
                  : AppTokens.cardCream,
              label: const Bilingual(
                ur: '۲۔ "فارماسسٹ سے پوچھیں" کے طور پر رکھیں (شیڈول نہیں ہوگا)',
                en: 'Keep as "ask pharmacist" (Not scheduled list)',
              ),
              trailing: isKeptForPharmacist
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: AppTokens.primaryTealDark,
                      size: 28,
                    )
                  : null,
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref
                    .read(journeyControllerProvider.notifier)
                    .keepLineAsAskPharmacist(line.id);
              },
            ),
            const SizedBox(height: 10),
            // 3. Remove
            BigActionButton(
              key: Key('flagged_remove_${line.id}'),
              icon: Icons.delete_outline_rounded,
              isPrimary: false,
              foregroundColor: AppTokens.alertCoralDark,
              iconBadgeColor: AppTokens.alertCoralTint,
              label: const Bilingual(
                ur: '۳۔ اس لائن کو ہٹا دیں',
                en: 'Remove from list',
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(journeyControllerProvider.notifier).removeLine(line.id);
              },
            ),
          ],
        ],
      ),
    );
  }
}
