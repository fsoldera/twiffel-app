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
import 'package:twiffel_app/src/theme/tokens.dart';

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

    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AnalysisPage(session: session, settings: settings),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(DecisionCopy.analysisVerdictLabel), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.text(DecisionCopy.analysisVerdictLabel))
          .textAlign,
      TextAlign.center,
    );
    expect(
      tester
          .widget<Text>(find.text(DecisionCopy.analysisKeyParameters))
          .textAlign,
      TextAlign.center,
    );
    expect(find.text('86%'), findsOneWidget);
    expect(find.text('14%'), findsOneWidget);
    expect(find.text('keep the bike'), findsWidgets);
    expect(find.text('Keep the bike.'), findsOneWidget);

    bool hasInsightBorder(Color color) {
      return tester.widgetList<Container>(find.byType(Container)).any((widget) {
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        final border = decoration.border;
        if (border is! Border) return false;
        return border.top.color == color && border.top.width == 1.5;
      });
    }

    expect(hasInsightBorder(TwiffelTokens.semanticSuccess), isTrue);
    expect(hasInsightBorder(TwiffelTokens.semanticError), isTrue);

    await tester.tap(find.text(DecisionCopy.analysisDetailsTab));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
    expect(find.text('Cheap to keep'), findsOneWidget);
  });
}
