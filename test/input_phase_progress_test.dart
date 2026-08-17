import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:twiffel_app/src/pages/decision_copy.dart';
import 'package:twiffel_app/src/theme/app_theme.dart';
import 'package:twiffel_app/src/widgets/input_phase_progress.dart';

void main() {
  testWidgets('shows only three input steps', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: InputPhaseProgress(stepIndex: 0),
        ),
      ),
    );

    expect(find.byKey(InputPhaseProgress.slotKey), findsOneWidget);
    expect(find.text(DecisionCopy.inputPhaseStepLabel(0)), findsOneWidget);
    expect(find.text(DecisionCopy.generateAnalysis), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: InputPhaseProgress(stepIndex: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(DecisionCopy.inputPhaseStepLabel(2)), findsOneWidget);
  });
}
