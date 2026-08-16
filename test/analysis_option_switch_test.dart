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

  testWidgets('Option A/B switch updates comparison list content', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final license = LicenseController(appLicenseConfig);
    await license.init();
    final session = SessionController(license: license);
    final settings = AppSettingsController();
    await settings.init();
    session.debugSetReady(
      const DecisionAnalysis(
        mode: DecisionMode.comparison,
        optionA: 'buy a dog',
        optionB: 'buy a cat',
        optionAPros: [
          AnalysisPoint(tagline: 'Dog pro', description: 'Dog detail', weight: 80),
        ],
        optionACons: [
          AnalysisPoint(tagline: 'Dog con', description: 'Dog con detail', weight: 70),
        ],
        optionBPros: [
          AnalysisPoint(tagline: 'Cat pro', description: 'Cat detail', weight: 75),
        ],
        optionBCons: [
          AnalysisPoint(tagline: 'Cat con', description: 'Cat con detail', weight: 65),
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

    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: AnalysisPage(session: session, settings: settings),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(DecisionCopy.analysisDetailsTab), findsOneWidget);
    expect(find.text('Dog pro'), findsNothing);

    await tester.tap(find.text(DecisionCopy.analysisDetailsTab));
    await tester.pumpAndSettle();

    expect(find.text('Dog pro'), findsOneWidget);
    expect(find.text('Cat pro'), findsNothing);
    expect(
      tester.getTopLeft(find.text('buy a dog')).dy,
      lessThan(tester.getTopLeft(find.text(DecisionCopy.analysisPros).first).dy),
    );

    await tester.tap(find.text('buy a cat'));
    await tester.pumpAndSettle();

    expect(find.text('Cat pro'), findsOneWidget);
    expect(find.text('Dog pro'), findsNothing);

    await tester.tap(find.text(DecisionCopy.analysisCons));
    await tester.pumpAndSettle();
    expect(find.text('Cat con'), findsOneWidget);
    expect(find.text('Cat pro'), findsNothing);

    await tester.tap(find.text('buy a dog'));
    await tester.pumpAndSettle();

    expect(find.text('Dog con'), findsOneWidget);
    expect(find.text('Dog pro'), findsNothing);
    expect(find.text('Cat con'), findsNothing);

    await tester.tap(find.text(DecisionCopy.analysisSummaryTab));
    await tester.pumpAndSettle();
    expect(find.text(DecisionCopy.analysisSummaryTab), findsOneWidget);

    await tester.tap(find.text(DecisionCopy.analysisDetailsTab));
    await tester.pumpAndSettle();

    expect(find.text('Dog con'), findsOneWidget);
    expect(find.text('Dog pro'), findsNothing);
  });
}
