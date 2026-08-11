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

List<AnalysisPoint> _points(String kind, int count) {
  return List<AnalysisPoint>.generate(
    count,
    (index) => AnalysisPoint(
      title: '$kind ${index + 1} title',
      detail:
          '$kind ${index + 1} detail with enough text to keep each row tall '
          'and force vertical overflow on a phone-sized results panel.',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '7 pros and 7 cons show title and bottom overflow cue',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final license = LicenseController(appLicenseConfig);
      await license.init();
      final session = SessionController(license: license);
    final settings = AppSettingsController();
    await settings.init();
      session.debugSetReady(
        DecisionAnalysis(
          mode: DecisionMode.single,
          target: 'Should I buy the MacBook Pro 16?',
          pros: _points('Pro', 7),
          cons: _points('Con', 7),
          verdictPoints: const [
            'A careful next step beats a rushed leap.',
            'Name the real obstacle before you commit.',
            'Keep the first move small enough to reverse.',
            'Timing matters once, not in every detail.',
            'If nothing clears the blocker, waiting is wiser.',
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

      expect(find.text(DecisionCopy.analysisTitleSingle), findsOneWidget);
      expect(find.text('Should I buy the MacBook Pro 16?'), findsNothing);
      expect(find.text(DecisionCopy.analysisPros), findsWidgets);
      expect(find.text(DecisionCopy.analysisCons), findsOneWidget);
      expect(find.text('${DecisionCopy.analysisPros} (7)'), findsNothing);
      expect(find.text('${DecisionCopy.analysisCons} (7)'), findsNothing);

      expect(find.text('Pro 1 title'), findsOneWidget);
      expect(find.text('Pro 7 title'), findsNothing);
      // Allow a frame for overflow metrics after ListView layout.
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('list-overflow-cue')), findsOneWidget);

      final prosScrollable = find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first;
      final position = tester.state<ScrollableState>(prosScrollable).position;
      // Lazy list extent can grow after a jump; settle at the true end.
      for (var i = 0; i < 6 && position.extentAfter > 1; i++) {
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
      expect(position.extentAfter, lessThanOrEqualTo(1));
      expect(find.text('Pro 7 title'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('list-overflow-cue')), findsNothing);

      await tester.tap(find.text(DecisionCopy.analysisCons));
      await tester.pumpAndSettle();
      await tester.pump();

      expect(find.text('Con 1 title'), findsOneWidget);
      expect(find.text('Con 7 title'), findsNothing);
      expect(find.byKey(const ValueKey<String>('list-overflow-cue')), findsOneWidget);
    },
  );
}
