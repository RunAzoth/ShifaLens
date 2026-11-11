import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import 'bi_text.dart';

/// Consistent pictorial icon widget for every [MealSlot] (sun, moon, chai/breakfast,
/// lunch plate, dinner, bedtime, Ramadan suhoor/iftar, when needed).
/// Never uses stock clip-art; merges high-contrast Material Symbols with warm clinic tints.
class SlotIcon extends StatelessWidget {
  final MealSlot slot;
  final double size;
  final bool showLabel;

  const SlotIcon(
    this.slot, {
    super.key,
    this.size = 48.0,
    this.showLabel = false,
  });

  static Bilingual labelFor(MealSlot slot) {
    switch (slot) {
      case MealSlot.wakeUp:
        return const Bilingual(ur: 'صبح اٹھتے ہی', en: 'Wake Up');
      case MealSlot.suhoor:
        return const Bilingual(ur: 'سحری', en: 'Suhoor');
      case MealSlot.breakfast:
        return const Bilingual(ur: 'ناشتہ', en: 'Breakfast');
      case MealSlot.midMorning:
        return const Bilingual(ur: 'چاشت / دوپہر سے پہلے', en: 'Mid-Morning');
      case MealSlot.lunch:
        return const Bilingual(ur: 'دوپہر کا کھانا', en: 'Lunch');
      case MealSlot.afternoon:
        return const Bilingual(ur: 'سہ پہر کی چائے', en: 'Afternoon');
      case MealSlot.iftar:
        return const Bilingual(ur: 'افطار', en: 'Iftar');
      case MealSlot.dinner:
        return const Bilingual(ur: 'رات کا کھانا', en: 'Dinner');
      case MealSlot.bedtime:
        return const Bilingual(ur: 'سونے سے پہلے', en: 'Bedtime');
      case MealSlot.whenNeeded:
        return const Bilingual(ur: 'ضرورت کے وقت', en: 'When Needed');
    }
  }

  static IconData iconFor(MealSlot slot) {
    switch (slot) {
      case MealSlot.wakeUp:
        return Icons.wb_twilight_rounded;
      case MealSlot.suhoor:
        return Icons.mosque_rounded;
      case MealSlot.breakfast:
        return Icons.free_breakfast_rounded;
      case MealSlot.midMorning:
        return Icons.wb_sunny_outlined;
      case MealSlot.lunch:
        return Icons.wb_sunny_rounded;
      case MealSlot.afternoon:
        return Icons.emoji_food_beverage_rounded;
      case MealSlot.iftar:
        return Icons.nights_stay_rounded;
      case MealSlot.dinner:
        return Icons.dinner_dining_rounded;
      case MealSlot.bedtime:
        return Icons.bedtime_rounded;
      case MealSlot.whenNeeded:
        return Icons.medical_services_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTokens.slotColors(slot);
    final label = labelFor(slot);
    final iconData = iconFor(slot);

    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(size * 0.34),
        border: Border.all(
          color: palette.accent.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Icon(
        iconData,
        size: size * 0.56,
        color: palette.fg,
      ),
    );

    if (!showLabel) {
      return Semantics(
        label: '${label.ur}, ${label.en}',
        child: badge,
      );
    }

    return Semantics(
      label: '${label.ur}, ${label.en}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          badge,
          const SizedBox(width: 12),
          Flexible(
            child: BiText(
              label,
              urduSize: 22,
              englishSize: 16,
              urduColor: palette.fg,
            ),
          ),
        ],
      ),
    );
  }
}
