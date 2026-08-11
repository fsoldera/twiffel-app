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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Start over asks for confirmation before reset', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final license = LicenseController(appLicenseConfig);
    await license.init();
    final session = SessionController(license: license);
    final settings = AppSettingsController();
    await settings.init();
    session.debugSetReady(
      const DecisionAnalysis(
        mode: DecisionMode.single,
        target: 'Should I move?',
        pros: [
          AnalysisPoint(title: '1. Pro', detail: 'Detail'),
        ],
        cons: [
          AnalysisPoint(title: '1. Con', detail: 'Detail'),
        ],
        verdictPoints: [
          'Lean carefully.',
          'Name the obstacle.',
          'Keep the first move small.',
          'Timing matters.',
          'Waiting can be wise.',
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnalysisPage(session: session, settings: settings),
      ),
    );
    await tester.pumpAndSettle();

    final startOverButton = find.widgetWithText(
      OutlinedButton,
      DecisionCopy.analysisStartOver,
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
}
