import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:twiffel_app/src/app.dart';
import 'package:twiffel_app/src/pages/decision_copy.dart';
import 'package:twiffel_app/src/widgets/once_play_video.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  // Min splash hold (1.5s) before FlutterNativeSplash.remove().
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pumpAndSettle();
}

void main() {
  test('hero video preload is skipped under the widget test binding', () async {
    await HeroVideo.preload();
    expect(HeroVideo.isReady, isFalse);
  });

  testWidgets('home opens options step with Previous/Next nav', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _pumpApp(tester);

    expect(find.text('Twiffel'), findsWidgets);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byKey(OncePlayVideo.slotKey), findsOneWidget);
    expect(find.text(DecisionCopy.optionsStepTitle), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(DecisionCopy.optionsStepTitle)).textAlign,
      TextAlign.center,
    );
    expect(find.text(DecisionCopy.pathBOptionALabel), findsOneWidget);
    expect(find.text(DecisionCopy.pathBOptionBLabel), findsOneWidget);
    expect(find.text(DecisionCopy.nextLabel), findsOneWidget);
    expect(find.text(DecisionCopy.previousLabel), findsNothing);
    expect(find.text(DecisionCopy.timingMonths), findsNothing);
    expect(find.text(DecisionCopy.routingTitle), findsNothing);
  });

  testWidgets('Next advances through consideration then timing', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _pumpApp(tester);

    await tester.enterText(
      find.widgetWithText(TextField, DecisionCopy.pathBOptionAPlaceholder),
      'Keep the bike',
    );
    await tester.enterText(
      find.widgetWithText(TextField, DecisionCopy.pathBOptionBPlaceholder),
      'Buy a car',
    );
    await tester.pump();
    await tester.tap(find.text(DecisionCopy.nextLabel));
    await tester.pumpAndSettle();

    expect(find.byKey(OncePlayVideo.slotKey), findsNothing);
    expect(find.text(DecisionCopy.considerationStepTitle), findsOneWidget);
    expect(find.text(DecisionCopy.pathBObstacleCost), findsOneWidget);

    await tester.tap(find.text(DecisionCopy.pathBObstacleCost));
    await tester.pump();
    await tester.tap(find.text(DecisionCopy.nextLabel));
    await tester.pumpAndSettle();

    expect(find.text(DecisionCopy.timingStepTitle), findsOneWidget);
    expect(find.text(DecisionCopy.timingMonths), findsOneWidget);
    expect(find.text(DecisionCopy.timingDateRange), findsOneWidget);
    expect(find.text(DecisionCopy.generateAnalysis), findsOneWidget);
  });
}
