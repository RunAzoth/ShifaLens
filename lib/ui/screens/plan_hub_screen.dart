import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import '../theme/language_controller.dart';
import '../widgets/widgets.dart';
import 'email_share_sheet.dart';
import 'journey_controller.dart';
import 'tabs/ask_tab.dart';
import 'tabs/medicines_tab.dart';
import 'tabs/reminders_tab.dart';
import 'tabs/today_tab.dart';

/// Part 4 PLAN HUB:
/// - Bottom navigation with 4 tabs (picture + Urdu + English labels):
///   0: Today (آج کا دن)
///   1: Medicines (دوائیں)
///   2: Ask (پوچھیں)
///   3: Reminders (یاد دہانی)
/// - "More" menu with:
///   - Match my strips
///   - Print card
///   - Print stickers
///   - Email to family
///   - Plate guide
///   - About and Responsible AI
///   - Language
///   - Ramadan
class PlanHubScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const PlanHubScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<PlanHubScreen> createState() => _PlanHubScreenState();
}

class _PlanHubScreenState extends ConsumerState<PlanHubScreen> {
  late int _selectedTab;

  static const List<({IconData icon, String ur, String en})> _tabSpecs = [
    (
      icon: Icons.wb_sunny_rounded,
      ur: 'آج کا دن',
      en: 'Today',
    ),
    (
      icon: Icons.medication_rounded,
      ur: 'دوائیں',
      en: 'Medicines',
    ),
    (
      icon: Icons.question_answer_rounded,
      ur: 'پوچھیں',
      en: 'Ask',
    ),
    (
      icon: Icons.notifications_active_rounded,
      ur: 'یاد دہانی',
      en: 'Reminders',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex.clamp(0, 3);
  }

  void _openMoreSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) {
        return Consumer(
          builder: (context, ref, _) {
            final journey = ref.watch(journeyControllerProvider);
            final mode = ref.watch(languageModeProvider);

            return Directionality(
              textDirection: mode.direction,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTokens.space3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.apps_rounded,
                          color: AppTokens.primaryTealDark,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: BiText(
                            Bilingual(
                              ur: 'مزید سہولیات (More Tools)',
                              en: 'More Pharmacist Tools & Settings',
                            ),
                            isHeadline: true,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                        ),
                      ],
                    ),
                    const Divider(),

                    // 1. Match my strips
                    _MoreActionTile(
                      key: const Key('more_match_strips'),
                      icon: Icons.qr_code_scanner_rounded,
                      label: const Bilingual(
                        ur: 'دوا کے پتے ملائیں (Match my strips)',
                        en: 'Match my strips',
                      ),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        context.push('/strips');
                      },
                    ),

                    // 2. Print card
                    _MoreActionTile(
                      key: const Key('more_print_card'),
                      icon: Icons.print_rounded,
                      label: const Bilingual(
                        ur: 'روزانہ کارڈ پرنٹ کریں (Print card)',
                        en: 'Print card',
                      ),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        context.push('/print?mode=card');
                      },
                    ),

                    // 3. Print stickers
                    _MoreActionTile(
                      key: const Key('more_print_stickers'),
                      icon: Icons.sticky_note_2_rounded,
                      label: const Bilingual(
                        ur: 'دوا کے اسٹیکرز پرنٹ کریں (Print stickers)',
                        en: 'Print stickers',
                      ),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        context.push('/print?mode=stickers');
                      },
                    ),

                    // 4. Email to family
                    _MoreActionTile(
                      key: const Key('more_email_family'),
                      icon: Icons.forward_to_inbox_rounded,
                      label: const Bilingual(
                        ur: 'تیماردار کو ای میل بھیجیں (Email to family)',
                        en: 'Email to family',
                      ),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        EmailShareSheet.show(context);
                      },
                    ),

                    // 5. Plate guide
                    _MoreActionTile(
                      key: const Key('more_plate_guide'),
                      icon: Icons.restaurant_menu_rounded,
                      label: const Bilingual(
                        ur: 'متوازن کھانے کی تھالی (Plate guide)',
                        en: 'Plate guide',
                      ),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        context.push('/plate-guide');
                      },
                    ),

                    // 6. Ramadan Toggle
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTokens.eveningIndigoTint,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTokens.eveningIndigo),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.mosque_rounded,
                            color: AppTokens.eveningIndigo,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: BiText(
                              Bilingual(
                                ur: 'رمضان کا شیڈول (Ramadan)',
                                en: 'Ramadan',
                              ),
                              urduWeight: FontWeight.w700,
                              englishWeight: FontWeight.w700,
                            ),
                          ),
                          Switch.adaptive(
                            value: journey.ramadanMode,
                            activeThumbColor: AppTokens.eveningIndigo,
                            onChanged: (val) {
                              ref
                                  .read(journeyControllerProvider.notifier)
                                  .setRamadanMode(ramadan: val);
                            },
                          ),
                        ],
                      ),
                    ),

                    // 7. Language
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: LanguageToggle()),
                    ),

                    // 8. About and Responsible AI
                    _MoreActionTile(
                      key: const Key('more_about_ai'),
                      icon: Icons.verified_user_rounded,
                      label: const Bilingual(
                        ur: 'تعارف اور ذمہ دارانہ AI (About & Responsible AI)',
                        en: 'About and Responsible AI',
                      ),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        context.push('/about');
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(languageModeProvider);

    final pages = const <Widget>[
      TodayTab(),
      MedicinesTab(),
      AskTab(),
      RemindersTab(),
    ];

    return Directionality(
      textDirection: mode.direction,
      child: Scaffold(
        backgroundColor: AppTokens.surfaceCream,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Home • ہوم اسکرین',
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/home'),
          ),
          title: Text(
            '${_tabSpecs[_selectedTab].en} • ${_tabSpecs[_selectedTab].ur}',
          ),
          actions: [
            Semantics(
              button: true,
              label:
                  'More menu: Match strips, Print card, Print stickers, Email to family, Plate guide, About and Responsible AI, Language, Ramadan',
              child: TextButton.icon(
                key: const Key('plan_hub_more_button'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTokens.primaryTealDark,
                  backgroundColor: AppTokens.primaryTealTint,
                  minimumSize: const Size(88, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _openMoreSheet(context),
                icon: const Icon(Icons.more_horiz_rounded),
                label: const Text(
                  'More • مزید',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: SafeArea(
          child: pages[_selectedTab],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppTokens.cardCream,
            border: const Border(
              top: BorderSide(color: AppTokens.borderWarm, width: 1.5),
            ),
            boxShadow: AppTokens.cardShadow,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: List.generate(_tabSpecs.length, (idx) {
                  final spec = _tabSpecs[idx];
                  final selected = idx == _selectedTab;
                  return Expanded(
                    child: Semantics(
                      button: true,
                      selected: selected,
                      label: '${spec.ur}. ${spec.en}',
                      child: InkWell(
                        key: Key('plan_tab_$idx'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTab = idx);
                        },
                        child: AnimatedContainer(
                          duration: AppTokens.motionFast,
                          constraints: const BoxConstraints(
                            minHeight: AppTokens.heroTapTarget,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTokens.primaryTealTint
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                spec.icon,
                                size: 26,
                                color: selected
                                    ? AppTokens.primaryTealDark
                                    : AppTokens.inkMuted,
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  spec.ur,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: selected
                                        ? AppTokens.primaryTealDark
                                        : AppTokens.ink,
                                  ),
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  spec.en,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? AppTokens.primaryTealDark
                                        : AppTokens.inkMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreActionTile extends StatelessWidget {
  final IconData icon;
  final Bilingual label;
  final VoidCallback onTap;

  const _MoreActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppTokens.minTapTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTokens.cardCream,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTokens.borderWarm, width: 1.4),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTokens.primaryTealTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: AppTokens.primaryTealDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BiText(
                  label,
                  urduWeight: FontWeight.w700,
                  englishWeight: FontWeight.w600,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTokens.primaryTeal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
