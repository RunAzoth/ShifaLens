import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import '../theme/language_controller.dart';
import '../widgets/widgets.dart';
import 'journey_controller.dart';

class _FrequencyOption {
  final String code;
  final Bilingual label;
  final List<MealSlot> slots;

  const _FrequencyOption({
    required this.code,
    required this.label,
    required this.slots,
  });
}

class _TimingOption {
  final String note;
  final Bilingual label;
  final IconData icon;

  const _TimingOption({
    required this.note,
    required this.label,
    required this.icon,
  });
}

/// Screen 7: Manual Entry & Inline Fix Sheet
/// - Brand autocomplete powered by KnowledgeService.resolveBrand
/// - Strength quick-chips + text field
/// - Big pictorial frequency choices (Morning, Noon, Night, Morning+Night, 3 times, When needed)
/// - Pictorial food relation choices (Before food, After/with food, Empty stomach, At bedtime)
/// - Duration days picker
class ManualEntrySheet extends ConsumerStatefulWidget {
  final MedicineLine? existingLine;

  const ManualEntrySheet({
    super.key,
    this.existingLine,
  });

  /// Shows the ManualEntrySheet as a modal bottom sheet.
  /// Returns `true` if a medicine was added or updated.
  static Future<bool?> show(
    BuildContext context, {
    MedicineLine? existingLine,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ManualEntrySheet(existingLine: existingLine),
    );
  }

  @override
  ConsumerState<ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends ConsumerState<ManualEntrySheet> {
  late final TextEditingController _brandController;
  late final TextEditingController _strengthController;

  String _selectedForm = 'Tablet';
  String _selectedFrequency = '1+0+1';
  String _selectedTiming = 'after food';
  int _selectedDurationDays = 5;

  static const List<String> _commonBrands = [
    'Augmentin',
    'Panadol',
    'Calpol',
    'Risek',
    'Glucophage',
    'Norvasc',
    'Lipitor',
    'Cipro',
    'Ferrous Sulfate',
    'Brufen',
    'Flagyl',
    'Azomax',
    'Concor',
    'Softin',
  ];

  static const List<String> _strengthPresets = [
    '500 mg',
    '625 mg',
    '20 mg',
    '5 mg',
    '200 mg',
    '250 mg',
    '400 mg',
    '10 mg',
  ];

  static const List<_FrequencyOption> _frequencyOptions = [
    _FrequencyOption(
      code: '1+0+0',
      label: Bilingual(ur: 'صرف صبح', en: 'Morning only (1+0+0)'),
      slots: [MealSlot.breakfast],
    ),
    _FrequencyOption(
      code: '0+1+0',
      label: Bilingual(ur: 'صرف دوپہر', en: 'Noon only (0+1+0)'),
      slots: [MealSlot.lunch],
    ),
    _FrequencyOption(
      code: '0+0+1',
      label: Bilingual(ur: 'صرف رات', en: 'Night / Bedtime (0+0+1)'),
      slots: [MealSlot.dinner],
    ),
    _FrequencyOption(
      code: '1+0+1',
      label: Bilingual(ur: 'صبح اور رات (۲ بار)', en: 'Morning & Night (1+0+1)'),
      slots: [MealSlot.breakfast, MealSlot.dinner],
    ),
    _FrequencyOption(
      code: '1+1+1',
      label: Bilingual(
        ur: 'صبح، دوپہر، رات (۳ بار)',
        en: '3 times a day (1+1+1)',
      ),
      slots: [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner],
    ),
    _FrequencyOption(
      code: 'SOS',
      label: Bilingual(ur: 'ضرورت کے وقت', en: 'When needed (SOS)'),
      slots: [MealSlot.whenNeeded],
    ),
  ];

  static const List<_TimingOption> _timingOptions = [
    _TimingOption(
      note: 'after food',
      label: Bilingual(ur: 'کھانے کے بعد', en: 'After food'),
      icon: Icons.restaurant_rounded,
    ),
    _TimingOption(
      note: 'before breakfast',
      label: Bilingual(ur: 'کھانے سے پہلے', en: 'Before meal'),
      icon: Icons.schedule_rounded,
    ),
    _TimingOption(
      note: 'with meals',
      label: Bilingual(ur: 'کھانے کے ساتھ', en: 'With meal'),
      icon: Icons.lunch_dining_rounded,
    ),
    _TimingOption(
      note: 'at bedtime',
      label: Bilingual(ur: 'سونے سے پہلے', en: 'At bedtime'),
      icon: Icons.bedtime_rounded,
    ),
  ];

  static const List<int> _durationPresets = [3, 5, 7, 14, 30];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingLine;
    final initialBrand = (existing?.brandName != null &&
            !existing!.brandName!.contains('?'))
        ? existing.brandName!
        : '';
    _brandController = TextEditingController(text: initialBrand);
    _strengthController =
        TextEditingController(text: existing?.strength ?? '500 mg');
    _selectedForm = existing?.form ?? 'Tablet';
    _selectedFrequency = existing?.frequencyRaw ?? '1+0+1';
    _selectedTiming = existing?.timingNote ?? 'after food';
    _selectedDurationDays = existing?.durationDays ?? 5;
  }

  @override
  void dispose() {
    _brandController.dispose();
    _strengthController.dispose();
    super.dispose();
  }

  void _save() {
    final brand = _brandController.text.trim();
    if (brand.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or choose a medicine name • دوا کا نام لکھیں'),
        ),
      );
      return;
    }

    final strength = _strengthController.text.trim().isEmpty
        ? '500 mg'
        : _strengthController.text.trim();

    String? resolvedGeneric;
    bool isAmbiguous = false;
    try {
      final knowledge = ref.read(knowledgeServiceProvider);
      final resolution = knowledge.resolveBrand(brand);
      resolvedGeneric = resolution.generic;
      isAmbiguous = resolution.ambiguous;
    } catch (_) {
      resolvedGeneric = widget.existingLine?.genericName;
    }

    HapticFeedback.mediumImpact();
    final controller = ref.read(journeyControllerProvider.notifier);

    if (widget.existingLine != null) {
      final existing = widget.existingLine!;
      final updated = existing.copyWith(
        rawText:
            '$_selectedForm $brand $strength $_selectedFrequency $_selectedTiming x${_selectedDurationDays}d',
        brandName: brand,
        genericName: resolvedGeneric ?? existing.genericName ?? brand,
        strength: strength,
        form: _selectedForm,
        frequencyRaw: _selectedFrequency,
        timingNote: _selectedTiming,
        durationDays: _selectedDurationDays,
        needsPharmacist: isAmbiguous,
        confirmed: !isAmbiguous,
      );
      controller.updateAndConfirmLine(existing.id, updated);
    } else {
      controller.addManualLine(
        brandName: brand,
        genericName: resolvedGeneric,
        strength: strength,
        form: _selectedForm,
        frequencyRaw: _selectedFrequency,
        timingNote: _selectedTiming,
        durationDays: _selectedDurationDays,
        needsPharmacist: isAmbiguous,
      );
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(languageModeProvider);
    final isEditing = widget.existingLine != null;

    String? previewGeneric;
    bool previewAmbiguous = false;
    final currentBrand = _brandController.text.trim();
    if (currentBrand.isNotEmpty) {
      try {
        final res = ref.read(knowledgeServiceProvider).resolveBrand(currentBrand);
        previewGeneric = res.generic;
        previewAmbiguous = res.ambiguous;
      } catch (_) {}
    }

    return Directionality(
      textDirection: mode.direction,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTokens.primaryTealTint,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: AppTokens.primaryTealDark,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BiText(
                      isEditing
                          ? const Bilingual(
                              ur: 'دوا کی تفصیل درست کریں',
                              en: 'Fix / Edit Medicine Details',
                            )
                          : const Bilingual(
                              ur: 'نئی دوا شامل کریں',
                              en: 'Add Medicine Manually',
                            ),
                      isHeadline: true,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const Divider(),

              // 1. Brand Name + Autocomplete Chips
              const BiText(
                Bilingual(
                  ur: '۱۔ دوا کا نام (برانڈ منتخب کریں یا لکھیں):',
                  en: '1. Medicine brand name:',
                ),
                urduWeight: FontWeight.w700,
                englishWeight: FontWeight.w700,
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('manual_brand_input'),
                controller: _brandController,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  hintText: 'e.g. Augmentin, Panadol, Risek, Glucophage...',
                  prefixIcon: Icon(Icons.medication_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              if (previewGeneric != null || previewAmbiguous)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: previewAmbiguous
                        ? AppTokens.warningAmberTint
                        : AppTokens.primaryTealSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: previewAmbiguous
                          ? AppTokens.warningAmber
                          : AppTokens.primaryTeal,
                    ),
                  ),
                  child: BiText(
                    previewAmbiguous
                        ? const Bilingual(
                            ur: 'مشکوک برانڈ — فارماسسٹ سے تصدیق درکار ہے',
                            en: 'Ambiguous brand — verify generic with pharmacist',
                          )
                        : Bilingual(
                            ur: 'فارمولا (Generic): $previewGeneric',
                            en: 'Matched generic ingredient: $previewGeneric',
                          ),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _commonBrands.map((brand) {
                  final selected =
                      _brandController.text.trim().toLowerCase() ==
                          brand.toLowerCase();
                  return ActionChip(
                    key: Key('brand_suggestion_${brand.toLowerCase()}'),
                    backgroundColor: selected
                        ? AppTokens.primaryTealTint
                        : AppTokens.surfaceWarm,
                    label: Text(
                      brand,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected
                            ? AppTokens.primaryTealDark
                            : AppTokens.ink,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _brandController.text = brand;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTokens.space2),

              // 2. Strength (mg)
              const BiText(
                Bilingual(
                  ur: '۲۔ دوا کی طاقت (mg):',
                  en: '2. Strength (mg):',
                ),
                urduWeight: FontWeight.w700,
                englishWeight: FontWeight.w700,
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('manual_strength_input'),
                controller: _strengthController,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  hintText: 'e.g. 500 mg, 625 mg, 20 mg',
                  prefixIcon: Icon(Icons.scale_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _strengthPresets.map((s) {
                  final selected = _strengthController.text.trim() == s;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(s),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _strengthController.text = s);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTokens.space2),

              // 3. Big Pictorial Frequency Choices
              const BiText(
                Bilingual(
                  ur: '۳۔ دن میں کتنی بار لینی ہے؟ (تصویر منتخب کریں):',
                  en: '3. When to take each day (pictorial choices):',
                ),
                urduWeight: FontWeight.w700,
                englishWeight: FontWeight.w700,
              ),
              const SizedBox(height: 10),
              for (final opt in _frequencyOptions) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    key: Key('freq_choice_${opt.code}'),
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFrequency = opt.code);
                    },
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: AppTokens.minTapTarget,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedFrequency == opt.code
                            ? AppTokens.primaryTealTint
                            : AppTokens.cardCream,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _selectedFrequency == opt.code
                              ? AppTokens.primaryTeal
                              : AppTokens.borderWarm,
                          width: _selectedFrequency == opt.code ? 2.0 : 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Wrap(
                            spacing: 4,
                            children: opt.slots
                                .map((s) => SlotIcon(s, size: 38))
                                .toList(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: BiText(
                              opt.label,
                              urduWeight: FontWeight.w700,
                              englishWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            _selectedFrequency == opt.code
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: _selectedFrequency == opt.code
                                ? AppTokens.primaryTealDark
                                : AppTokens.inkSubtle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppTokens.space1),

              // 4. Before / After Food Relation
              const BiText(
                Bilingual(
                  ur: '۴۔ کھانے سے پہلے یا بعد میں؟',
                  en: '4. Before or after food?',
                ),
                urduWeight: FontWeight.w700,
                englishWeight: FontWeight.w700,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _timingOptions.map((timing) {
                  final selected = _selectedTiming == timing.note;
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTiming = timing.note);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTokens.morningSaffronTint
                            : AppTokens.cardCream,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? AppTokens.morningSaffronDark
                              : AppTokens.borderWarm,
                          width: selected ? 2.0 : 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            timing.icon,
                            color: selected
                                ? AppTokens.morningSaffronDark
                                : AppTokens.inkMuted,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: BiText(timing.label),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTokens.space2),

              // 5. Duration Days
              const BiText(
                Bilingual(
                  ur: '۵۔ کتنے دن تک؟',
                  en: '5. How many days?',
                ),
                urduWeight: FontWeight.w700,
                englishWeight: FontWeight.w700,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _durationPresets.map((days) {
                  final selected = _selectedDurationDays == days;
                  return ChoiceChip(
                    selected: selected,
                    label: Text('$days days • $days دن'),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedDurationDays = days);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTokens.space3),

              BigActionButton(
                key: const Key('manual_save_button'),
                icon: Icons.check_circle_rounded,
                label: isEditing
                    ? const Bilingual(
                        ur: 'تبدیلی محفوظ کریں اور تصدیق کریں',
                        en: 'Save Fix & Confirm Medicine',
                      )
                    : const Bilingual(
                        ur: 'نسخے میں دوا شامل کریں',
                        en: 'Add Medicine to Prescription',
                      ),
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
