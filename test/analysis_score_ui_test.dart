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

  testWidgets('Summary shows computed nets and a clear lean label', (
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
        optionA: 'keep the bike',
        optionB: 'buy a car',
        optionAPros: [
          AnalysisPoint(
            tagline: 'Cheap to keep',
            description: 'Costs little each month.',
            weight: 90,
          ),
        ],
        optionACons: [
          AnalysisPoint(
            tagline: 'Slower trips',
            description: 'Takes more time.',
            weight: 20,
          ),
        ],
        optionBPros: [
          AnalysisPoint(
            tagline: 'Faster trips',
            description: 'Saves time.',
            weight: 40,
          ),
        ],
        optionBCons: [
          AnalysisPoint(
            tagline: 'Higher cost',
            description: 'Costs more each month.',
            weight: 80,
          ),
        ],
        verdictPoints: [
          'Keep the bike.',
          'It fits the budget.',
          'The car costs more.',
          'Time is not the main point.',
          'Start with what you already have.',
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnalysisPage(session: session, settings: settings),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(DecisionCopy.analysisVerdictLabel), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('keep the bike'), findsWidgets);
    expect(find.text('Keep the bike.'), findsOneWidget);

    await tester.tap(find.text(DecisionCopy.analysisDetailsTab));
    await tester.pumpAndSettle();
    expect(find.text('+90'), findsOneWidget);
    expect(find.text('Cheap to keep'), findsOneWidget);
  });
}
