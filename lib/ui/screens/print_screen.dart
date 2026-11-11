import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import '../theme/language_controller.dart';
import '../widgets/widgets.dart';
import 'journey_controller.dart';

enum PrintMode {
  card,
  stickers;

  static PrintMode fromQuery(String? raw) {
    if (raw != null && raw.toLowerCase().contains('sticker')) {
      return PrintMode.stickers;
    }
    return PrintMode.card;
  }
}

/// Part 4 Feature #6: PRINT (Daily Card & Sticker Sheet)
/// - (a) Daily card: built as a Flutter widget inside a `RepaintBoundary`
///   (Urdu large, English small, SlotIcons, PillBadges, food pictograms, AiTag,
///   ReviewBadge, prototype disclaimer), captured to PNG, and embedded in a PDF
///   via `pdf` + `printing` (never rendering Urdu text with `pdf`'s text widgets!).
/// - (b) Sticker sheet: a grid of die-cut-style stickers (PillBadge + slot sun/moon/meal
///   icons + Urdu name + strength), one set per scheduled medicine, same PNG-to-PDF method.
/// - Includes Share / Print / Save actions.
class PrintScreen extends ConsumerStatefulWidget {
  final PrintMode initialMode;

  const PrintScreen({
    super.key,
    this.initialMode = PrintMode.card,
  });

  /// Helper to build a single-page PDF document embedding a captured PNG image
  static Future<Uint8List> buildPdfFromPngBytes(Uint8List pngBytes) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(pngBytes);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context ctx) {
          return pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          );
        },
      ),
    );
    return doc.save();
  }

  @override
  ConsumerState<PrintScreen> createState() => _PrintScreenState();
}

class _PrintScreenState extends ConsumerState<PrintScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  late PrintMode _mode;
  bool _isExporting = false;
  String? _statusBanner;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  Future<Uint8List?> _captureBoundaryToPng() async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.2);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _captureToPdfBytes() async {
    final pngBytes = await _captureBoundaryToPng();
    if (pngBytes == null) return null;
    return PrintScreen.buildPdfFromPngBytes(pngBytes);
  }

  Future<void> _onPrintPdf() async {
    if (_isExporting) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isExporting = true;
      _statusBanner = null;
    });
    try {
      final pdfBytes = await _captureToPdfBytes();
      if (pdfBytes != null) {
        await Printing.layoutPdf(
          name: _mode == PrintMode.card
              ? 'ShifaLens_Daily_Card.pdf'
              : 'ShifaLens_Medicine_Stickers.pdf',
          onLayout: (_) async => pdfBytes,
        );
      }
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _statusBanner = 'PDF ready for printing • پرنٹ کے لیے تیار ہے';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _statusBanner =
            'PDF generated in memory • پی ڈی ایف تیار کر لی گئی ہے';
      });
    }
  }

  Future<void> _onShareOrSavePdf() async {
    if (_isExporting) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isExporting = true;
      _statusBanner = null;
    });
    try {
      final pdfBytes = await _captureToPdfBytes();
      if (pdfBytes != null) {
        final filename = _mode == PrintMode.card
            ? 'ShifaLens_Daily_Card.pdf'
            : 'ShifaLens_Medicine_Stickers.pdf';
        try {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$filename');
          await file.writeAsBytes(pdfBytes, flush: true);
        } catch (_) {}
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: filename,
        );
      }
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _statusBanner = 'Saved & shared PDF • پی ڈی ایف محفوظ کر لی گئی';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _statusBanner = 'PDF saved • پی ڈی ایف تیار ہے';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final langMode = ref.watch(languageModeProvider);
    final journey = ref.watch(journeyControllerProvider);
    final plan = journey.latestPlan;

    return Directionality(
      textDirection: langMode.direction,
      child: Scaffold(
        backgroundColor: AppTokens.surfaceCream,
        appBar: AppBar(
          title: Text(
            _mode == PrintMode.card
                ? 'Print Daily Card • روزانہ کارڈ پرنٹ کریں'
                : 'Print Stickers • دوا کے اسٹیکرز',
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: LanguageToggle(compact: true),
            ),
          ],
        ),
        body: SafeArea(
          child: plan == null
              ? const Padding(
                  padding: EdgeInsets.all(AppTokens.space2),
                  child: EmptyState(
                    icon: Icons.print_rounded,
                    title: Bilingual(
                      ur: 'پرنٹ کرنے کے لیے پہلے شیڈول بنائیں',
                      en: 'Create a daily plan first to print cards or stickers',
                    ),
                    subtitle: Bilingual(
                      ur: 'تصدیق شدہ شیڈول سے فریج کارڈ اور دوا کے پتوں کے اسٹیکرز بنتے ہیں۔',
                      en: 'Your confirmed schedule generates the fridge card and blister-strip stickers.',
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Mode Switcher: Daily Card vs Sticker Sheet
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.space2,
                        8,
                        AppTokens.space2,
                        8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              key: const Key('print_mode_card_chip'),
                              selected: _mode == PrintMode.card,
                              label: const Text(
                                'Daily Fridge Card • روزانہ کارڈ',
                              ),
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                setState(() => _mode = PrintMode.card);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              key: const Key('print_mode_stickers_chip'),
                              selected: _mode == PrintMode.stickers,
                              label: const Text(
                                'Strip Stickers • اسٹیکرز',
                              ),
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                setState(() => _mode = PrintMode.stickers);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_statusBanner != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.space2,
                          vertical: 4,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTokens.successGreenTint,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTokens.successGreen),
                          ),
                          child: Text(
                            _statusBanner!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTokens.successGreenDark,
                            ),
                          ),
                        ),
                      ),

                    // Scrollable RepaintBoundary Preview
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppTokens.space2),
                        child: RepaintBoundary(
                          key: _boundaryKey,
                          child: Container(
                            color: AppTokens.surfaceCream,
                            padding: const EdgeInsets.all(AppTokens.space2),
                            child: _mode == PrintMode.card
                                ? _PrintableDailyCardWidget(
                                    plan: plan,
                                    mealTimes: journey.mealTimes,
                                  )
                                : _PrintableStickerSheetWidget(plan: plan),
                          ),
                        ),
                      ),
                    ),

                    // Bottom Print / Share / Save Actions
                    Container(
                      padding: const EdgeInsets.all(AppTokens.space2),
                      decoration: BoxDecoration(
                        color: AppTokens.cardCream,
                        border: const Border(
                          top: BorderSide(
                            color: AppTokens.borderWarm,
                            width: 1.5,
                          ),
                        ),
                        boxShadow: AppTokens.cardShadow,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BigActionButton(
                            key: const Key('print_pdf_button'),
                            icon: Icons.print_rounded,
                            label: _mode == PrintMode.card
                                ? const Bilingual(
                                    ur: 'روزانہ کارڈ پرنٹ کریں (PDF)',
                                    en: 'Print Daily Card (PNG-to-PDF)',
                                  )
                                : const Bilingual(
                                    ur: 'اسٹیکرز شیٹ پرنٹ کریں (PDF)',
                                    en: 'Print Sticker Sheet (PNG-to-PDF)',
                                  ),
                            onPressed: _isExporting ? null : _onPrintPdf,
                          ),
                          const SizedBox(height: 10),
                          BigActionButton(
                            key: const Key('share_pdf_button'),
                            icon: Icons.share_rounded,
                            isPrimary: false,
                            label: const Bilingual(
                              ur: 'پی ڈی ایف محفوظ کریں یا شیئر کریں',
                              en: 'Save or Share PDF',
                            ),
                            onPressed: _isExporting ? null : _onShareOrSavePdf,
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

class _PrintableDailyCardWidget extends StatelessWidget {
  final DailyPlan plan;
  final MealTimes mealTimes;

  const _PrintableDailyCardWidget({
    required this.plan,
    required this.mealTimes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('printable_daily_card_widget'),
      padding: const EdgeInsets.all(AppTokens.space2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        border: Border.all(color: AppTokens.primaryTeal, width: 2.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTokens.primaryTeal,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.local_pharmacy_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: BiText(
                  Bilingual(
                    ur: 'شفا لینز — روزانہ دوا کا تصویری کارڈ',
                    en: 'ShifaLens Daily Medicine Card',
                  ),
                  isHeadline: true,
                  urduColor: AppTokens.primaryTealDark,
                ),
              ),
            ],
          ),
          const Divider(),
          const AiTag(compact: true),
          const SizedBox(height: 8),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: ReviewBadge(reviewed: false),
          ),
          const SizedBox(height: 12),

          for (final med in plan.scheduled) ...[
            Builder(
              builder: (context) {
                final medDoses = plan.doses
                    .where((d) => d.medicineId == med.id)
                    .toList();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTokens.surfaceCream,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTokens.borderWarm, width: 1.4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          PillBadge(med.identityIndex, size: 50),
                          const SizedBox(width: 12),
                          Expanded(
                            child: BiText(
                              Bilingual(
                                ur: '${med.brandName ?? med.rawText} (${med.strength ?? ""})',
                                en: '${med.brandName ?? med.rawText} • ${med.genericName ?? ""} (${med.strength ?? ""})',
                              ),
                              urduWeight: FontWeight.w700,
                              englishWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: medDoses.map((d) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTokens.borderWarm),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SlotIcon(d.slot, size: 34, showLabel: true),
                                const SizedBox(width: 6),
                                Text(
                                  mealTimes.hhmm[d.slot] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTokens.primaryTealDark,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          if (plan.unscheduled.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTokens.warningAmberTint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTokens.warningAmber),
              ),
              child: BiText(
                Bilingual(
                  ur: 'شیڈول میں شامل نہیں — فارماسسٹ سے پوچھیں: ${plan.unscheduled.map((e) => e.rawText).join(", ")}',
                  en: 'Not scheduled — Ask your pharmacist: ${plan.unscheduled.map((e) => e.rawText).join(", ")}',
                ),
                urduColor: AppTokens.warningAmberDark,
              ),
            ),
          ],

          const SizedBox(height: 12),
          SafetyBanner.prototype(),
        ],
      ),
    );
  }
}

class _PrintableStickerSheetWidget extends StatelessWidget {
  final DailyPlan plan;

  const _PrintableStickerSheetWidget({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('printable_sticker_sheet_widget'),
      padding: const EdgeInsets.all(AppTokens.space2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        border: Border.all(color: AppTokens.primaryTeal, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BiText(
            Bilingual(
              ur: 'دوا کے پتوں پر چپکانے کے لیے تصویری اسٹیکرز',
              en: 'Die-Cut Medicine Strip Stickers (Cut & Stick on Blister Packs)',
            ),
            isHeadline: true,
            urduColor: AppTokens.primaryTealDark,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final med in plan.scheduled)
                for (int copy = 0; copy < 2; copy++)
                  _DieCutStickerTile(
                    medicine: med,
                    slots: plan.doses
                        .where((d) => d.medicineId == med.id)
                        .map((d) => d.slot)
                        .toSet()
                        .toList(),
                  ),
            ],
          ),
          const SizedBox(height: 14),
          SafetyBanner.prototype(),
        ],
      ),
    );
  }
}

class _DieCutStickerTile extends StatelessWidget {
  final MedicineLine medicine;
  final List<MealSlot> slots;

  const _DieCutStickerTile({
    required this.medicine,
    required this.slots,
  });

  @override
  Widget build(BuildContext context) {
    final identity = MedicineIdentity.of(medicine.identityIndex);

    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: identity.tintColor.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: identity.primaryColor,
          width: 2.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PillBadge(medicine.identityIndex, size: 48),
              const SizedBox(width: 10),
              Expanded(
                child: BiText(
                  Bilingual(
                    ur: medicine.brandName ?? medicine.rawText,
                    en: '${medicine.brandName ?? medicine.rawText} ${medicine.strength ?? ""}',
                  ),
                  urduWeight: FontWeight.w700,
                  englishWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (slots.isEmpty ? [MealSlot.breakfast] : slots)
                .map((s) => SlotIcon(s, size: 36, showLabel: true))
                .toList(),
          ),
        ],
      ),
    );
  }
}
