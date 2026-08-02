import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:twiffel_app/src/app.dart';
import 'package:twiffel_app/src/pages/decision_copy.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.pump(); // FlutterNativeSplash.remove()
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('routing screen shows decision path cards', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _pumpApp(tester);

    expect(find.text('Twiffel'), findsWidgets);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.text(DecisionCopy.routingTitle), findsOneWidget);
    expect(find.text(DecisionCopy.pathATitle), findsOneWidget);
    expect(find.text(DecisionCopy.pathBTitle), findsOneWidget);
    expect(find.text(DecisionCopy.continueLabel), findsOneWidget);
  });

  testWidgets('Continue on Path A opens do-or-buy form', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _pumpApp(tester);

    await tester.tap(find.text(DecisionCopy.pathATitle));
    await tester.pump();
    await tester.tap(find.text(DecisionCopy.continueLabel));
    await tester.pumpAndSettle();

    expect(find.text(DecisionCopy.pathAFormTitle), findsOneWidget);
    expect(find.text(DecisionCopy.pathAField1Label), findsOneWidget);
    expect(find.text(DecisionCopy.timingMonths), findsOneWidget);
    expect(find.text(DecisionCopy.generateAnalysis), findsOneWidget);
  });

  testWidgets('Continue on Path B opens Option A/B fields', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _pumpApp(tester);

    await tester.tap(find.text(DecisionCopy.pathBTitle));
    await tester.pump();
    await tester.tap(find.text(DecisionCopy.continueLabel));
    await tester.pumpAndSettle();

    expect(find.text(DecisionCopy.pathBFormTitle), findsOneWidget);
    expect(find.text(DecisionCopy.pathBOptionALabel), findsOneWidget);
    expect(find.text(DecisionCopy.pathBOptionBLabel), findsOneWidget);
    expect(find.text(DecisionCopy.timingLater), findsOneWidget);
  });
}
