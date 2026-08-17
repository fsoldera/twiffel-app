import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:twiffel_app/src/config/app_config.dart';
import 'package:twiffel_app/src/models/decision_models.dart';
import 'package:twiffel_app/src/pages/analysis_page.dart';
import 'package:twiffel_app/src/pages/decision_copy.dart';
import 'package:twiffel_app/src/state/app_settings_controller.dart';
import 'package:twiffel_app/src/state/session_controller.dart';
import 'package:twiffel_app/src/theme/app_theme.dart';
import 'package:twiffel_app/src/theme/tokens.dart';

const _readyAnalysis = DecisionAnalysis(
  optionA: 'Stay',
  optionB: 'Move',
  optionAPros: [
    AnalysisPoint(tagline: '1. Pro', description: 'Detail', weight: 80),
  ],
  optionACons: [
    AnalysisPoint(tagline: '1. Con', description: 'Detail', weight: 70),
  ],
  optionBPros: [
    AnalysisPoint(tagline: 'B pro', description: 'Detail', weight: 60),
  ],
  optionBCons: [
    AnalysisPoint(tagline: 'B con', description: 'Detail', weight: 50),
  ],
  verdictPoints: [
    'Lean carefully.',
    'Name the obstacle.',
    'Keep the first move small.',
    'Timing matters.',
    'Waiting can be wise.',
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Start over asks for confirmation before reset', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final license = LicenseController(appLicenseConfig);
    await license.init();
    final session = SessionController(license: license);
    final settings = AppSettingsController();
    await settings.init();
    session.debugSetReady(_readyAnalysis);

    await tester.pumpWidget(
      MaterialApp(
        home: AnalysisPage(session: session, settings: settings),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(DecisionCopy.analysisDetailsTab), findsOneWidget);
    expect(find.text(DecisionCopy.analysisSummaryTab), findsOneWidget);
    expect(find.text(DecisionCopy.analysisVerdictLabel), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, DecisionCopy.analysisShare),
      findsOneWidget,
    );

    final startOverButton = find.widgetWithText(
      OutlinedButton,
      DecisionCopy.analysisStartNewDecision,
    );

    await tester.tap(startOverButton);
    await tester.pumpAndSettle();

    expect(find.text(DecisionCopy.analysisStartOverTitle), findsOneWidget);
    expect(session.phase, SessionPhase.ready);

    await tester.tap(find.text(DecisionCopy.analysisStartOverKeep));
    await tester.pumpAndSettle();
    expect(session.phase, SessionPhase.ready);

    await tester.tap(startOverButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(
        FilledButton,
        DecisionCopy.analysisStartOverConfirm,
      ),
    );
    await tester.pumpAndSettle();

    expect(session.phase, SessionPhase.input);
  });

  testWidgets('Details tab opens details and Summary returns to verdict', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final license = LicenseController(appLicenseConfig);
    await license.init();
    final session = SessionController(license: license);
    final settings = AppSettingsController();
    await settings.init();
    session.debugSetReady(_readyAnalysis);

    await tester.pumpWidget(
      MaterialApp(
        home: AnalysisPage(session: session, settings: settings),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lean carefully.'), findsOneWidget);
    expect(find.text('1. Pro'), findsNothing);
    expect(
      find.widgetWithText(FilledButton, DecisionCopy.analysisShare),
      findsOneWidget,
    );

    await tester.tap(find.text(DecisionCopy.analysisDetailsTab));
    await tester.pumpAndSettle();

    expect(find.text('1. Pro'), findsOneWidget);
    expect(find.text(DecisionCopy.analysisDetailsTab), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, DecisionCopy.analysisShare),
      findsOneWidget,
    );

    await tester.tap(find.text(DecisionCopy.analysisSummaryTab));
    await tester.pumpAndSettle();

    expect(find.text(DecisionCopy.analysisSummaryTab), findsOneWidget);
    expect(find.text('1. Pro'), findsNothing);
  });

  testWidgets(
    'Results actions match the dialog Start over button height',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final license = LicenseController(appLicenseConfig);
      await license.init();
      final session = SessionController(license: license);
      final settings = AppSettingsController();
      await settings.init();
      session.debugSetReady(_readyAnalysis);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AnalysisPage(session: session, settings: settings),
        ),
      );
      await tester.pumpAndSettle();

      final shareHeight = tester
          .getSize(
            find.widgetWithText(FilledButton, DecisionCopy.analysisShare),
          )
          .height;
      final startNewHeight = tester
          .getSize(
            find.widgetWithText(
              OutlinedButton,
              DecisionCopy.analysisStartNewDecision,
            ),
          )
          .height;

      expect(shareHeight, TwiffelTokens.buttonHeight);
      expect(startNewHeight, TwiffelTokens.buttonHeight);

      await tester.tap(
        find.widgetWithText(
          OutlinedButton,
          DecisionCopy.analysisStartNewDecision,
        ),
      );
      await tester.pumpAndSettle();

      final dialogStartOverHeight = tester
          .getSize(
            find.widgetWithText(
              FilledButton,
              DecisionCopy.analysisStartOverConfirm,
            ),
          )
          .height;
      expect(dialogStartOverHeight, TwiffelTokens.buttonHeight);
      expect(startNewHeight, dialogStartOverHeight);
    },
  );
}
