import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifalens/core/models/models.dart';
import 'package:shifalens/ui/screens/journey_controller.dart';
import 'package:shifalens/ui/screens/review_confirm_screen.dart';
import 'package:shifalens/ui/theme/app_theme.dart';
import 'package:shifalens/ui/theme/language_controller.dart';
import 'package:shifalens/ui/widgets/widgets.dart';

Prescription _buildFlaggedRx1() {
  return Prescription(
    id: 'test-rx1',
    createdAt: DateTime(2026, 11, 11),
    synthetic: true,
    lines: const [
      MedicineLine(
        id: 'line-augmentin',
        rawText: 'Tab. Augmentin 625 mg 1+0+1 x5d',
        brandName: 'Augmentin',
        genericName: 'Amoxicillin + Clavulanic Acid',
        strength: '625 mg',
        form: 'Tablet',
        frequencyRaw: '1+0+1',
        timingNote: 'after food',
        durationDays: 5,
        fieldConfidence: {
          'name': 0.96,
          'strength': 0.95,
          'frequency': 0.94,
          'duration': 0.92,
        },
        needsPharmacist: false,
        confirmed: true,
        isManual: false,
        identityIndex: 0,
      ),
      MedicineLine(
        id: 'line-flagged',
        rawText: 'Tab. ????? 1+0+1',
        brandName: 'Tab. ?????',
        genericName: null,
        strength: null,
        form: 'Tablet',
        frequencyRaw: '1+0+1',
        timingNote: null,
        durationDays: null,
        fieldConfidence: {
          'name': 0.22,
          'strength': 0.15,
          'frequency': 0.75,
          'duration': 0.20,
        },
        needsPharmacist: true,
        confirmed: false,
        isManual: false,
        identityIndex: 3,
      ),
    ],
  );
}

void main() {
  group('Person B Part 3 Widget Smoke Tests', () {
    testWidgets(
      '1. Review screen renders flagged state, AiTag, and 3 one-tap actions with no overflow at 1.6x textScale',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container
            .read(journeyControllerProvider.notifier)
            .setPrescription(_buildFlaggedRx1());

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(412, 915),
                textScaler: TextScaler.linear(1.6),
                disableAnimations: true,
              ),
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const ReviewConfirmScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // AiTag is always visible (Non-Negotiable Rule #5)
        expect(
          find.textContaining('AI-generated: verify with your pharmacist'),
          findsOneWidget,
        );

        // Scroll down to the flagged card
        final flaggedCardFinder =
            find.byKey(const Key('medicine_card_line-flagged'));
        await tester.scrollUntilVisible(
          flaggedCardFinder,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(flaggedCardFinder, findsOneWidget);
        expect(
          find.textContaining('Ask your pharmacist'),
          findsWidgets,
        );

        // Verify all 3 one-tap resolution buttons exist on the flagged card
        expect(
          find.byKey(const Key('flagged_fix_line-flagged')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('flagged_keep_pharmacist_line-flagged')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('flagged_remove_line-flagged')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '2. LanguageToggle switches between Both, Urdu-only (RTL), and English-only (LTR)',
      (WidgetTester tester) async {
        const sample = Bilingual(
          ur: 'خوش آمدید شفا لینز',
          en: 'Welcome to ShifaLens',
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: Column(
                  children: [
                    LanguageToggle(),
                    BiText(sample),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Default mode is Both -> shows both Urdu and English
        expect(find.text('خوش آمدید شفا لینز'), findsOneWidget);
        expect(find.text('Welcome to ShifaLens'), findsOneWidget);

        // Tap Urdu-only option
        await tester.tap(find.text('Urdu'));
        await tester.pumpAndSettle();
        expect(find.text('خوش آمدید شفا لینز'), findsOneWidget);
        expect(find.text('Welcome to ShifaLens'), findsNothing);

        // Tap English-only option
        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();
        expect(find.text('خوش آمدید شفا لینز'), findsNothing);
        expect(find.text('Welcome to ShifaLens'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Confirm button stays disabled while flagged line is unresolved and enables once resolved',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container
            .read(journeyControllerProvider.notifier)
            .setPrescription(_buildFlaggedRx1());

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(412, 915),
                disableAnimations: true,
              ),
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const ReviewConfirmScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially: 1 flagged line is unresolved -> canConfirmPlan is false
        expect(container.read(journeyControllerProvider).canConfirmPlan, isFalse);

        final confirmBtnFinder =
            find.byKey(const Key('review_confirm_button'));
        expect(confirmBtnFinder, findsOneWidget);
        expect(
          find.text('Confirm and make my plan (2 medicines)'),
          findsOneWidget,
        );

        final BigActionButton initialButton =
            tester.widget<BigActionButton>(confirmBtnFinder);
        expect(initialButton.onPressed, isNull);

        // Resolve the flagged line by tapping "Keep as 'ask pharmacist'"
        final keepButtonFinder =
            find.byKey(const Key('flagged_keep_pharmacist_line-flagged'));
        await tester.scrollUntilVisible(
          keepButtonFinder,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        await tester.tap(keepButtonFinder);
        await tester.pumpAndSettle();

        // Now all flagged lines are resolved -> Confirm button is enabled!
        expect(container.read(journeyControllerProvider).canConfirmPlan, isTrue);
        final BigActionButton enabledButton =
            tester.widget<BigActionButton>(confirmBtnFinder);
        expect(enabledButton.onPressed, isNotNull);
      },
    );
  });
}
