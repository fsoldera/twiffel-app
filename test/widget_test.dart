import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:twiffel_app/src/app.dart';
import 'package:twiffel_app/src/pages/android_onboarding_copy.dart';
import 'package:twiffel_app/src/pages/decision_copy.dart';
import 'package:twiffel_app/src/pages/ios_onboarding_copy.dart';
import 'package:twiffel_app/src/widgets/loop_play_video.dart';
import 'package:twiffel_app/src/widgets/once_play_video.dart';

Future<void> _withPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _pumpApp(
  WidgetTester tester, {
  bool onboardingCompleted = true,
}) async {
  SharedPreferences.setMockInitialValues(
    onboardingCompleted
        ? <String, Object>{'app_settings.onboarding_completed': 1}
        : <String, Object>{},
  );
  await tester.pumpWidget(const MyApp());
  // Min splash hold (1.5s) before FlutterNativeSplash.remove().
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pumpAndSettle();
}

void main() {
  test('video preloads are skipped under the widget test binding', () async {
    await HeroVideo.preload();
    await WaitingVideo.preload();
    expect(HeroVideo.isReady, isFalse);
    expect(WaitingVideo.isReady, isFalse);
  });

  testWidgets('home opens options step with Previous/Next nav', (tester) async {
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
    expect(find.text(DecisionCopy.timingAsap), findsOneWidget);
    expect(find.text(DecisionCopy.timingMonths), findsOneWidget);
    expect(find.text(DecisionCopy.timingDateRange), findsOneWidget);
    expect(find.text(DecisionCopy.generateAnalysis), findsOneWidget);
  });

  testWidgets('first launch opens Android onboarding, Skip goes to home',
      (tester) async {
    await _withPlatform(TargetPlatform.android, () async {
      await _pumpApp(tester, onboardingCompleted: false);

      expect(find.text(AndroidOnboardingCopy.step1Title), findsOneWidget);
      expect(find.text(AndroidOnboardingCopy.next), findsOneWidget);
      expect(find.text(AndroidOnboardingCopy.skip), findsOneWidget);
      expect(find.text(DecisionCopy.optionsStepTitle), findsNothing);

      await tester.tap(find.text(AndroidOnboardingCopy.next));
      await tester.pumpAndSettle();
      expect(find.text(AndroidOnboardingCopy.step2Title), findsOneWidget);

      await tester.tap(find.text(AndroidOnboardingCopy.skip));
      await tester.pumpAndSettle();
      expect(find.text(DecisionCopy.optionsStepTitle), findsOneWidget);
    });
  });

  testWidgets('last Android onboarding step uses Get Started and hides Skip',
      (tester) async {
    await _withPlatform(TargetPlatform.android, () async {
      await _pumpApp(tester, onboardingCompleted: false);

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text(AndroidOnboardingCopy.next));
        await tester.pumpAndSettle();
      }

      expect(find.text(AndroidOnboardingCopy.step5Title), findsOneWidget);
      expect(find.text(AndroidOnboardingCopy.getStarted), findsOneWidget);
      expect(find.text(AndroidOnboardingCopy.skip), findsNothing);

      await tester.tap(find.text(AndroidOnboardingCopy.getStarted));
      await tester.pumpAndSettle();
      expect(find.text(DecisionCopy.optionsStepTitle), findsOneWidget);
    });
  });

  testWidgets('first launch opens iOS onboarding, Skip goes to home',
      (tester) async {
    await _withPlatform(TargetPlatform.iOS, () async {
      await _pumpApp(tester, onboardingCompleted: false);

      expect(find.text(IosOnboardingCopy.step1Title), findsOneWidget);
      expect(find.text(IosOnboardingCopy.next), findsOneWidget);
      expect(find.text(IosOnboardingCopy.skip), findsOneWidget);
      expect(find.text(DecisionCopy.optionsStepTitle), findsNothing);

      await tester.tap(find.text(IosOnboardingCopy.next));
      await tester.pumpAndSettle();
      expect(find.text(IosOnboardingCopy.step2Title), findsOneWidget);

      await tester.tap(find.text(IosOnboardingCopy.skip));
      await tester.pumpAndSettle();
      expect(find.text(DecisionCopy.optionsStepTitle), findsOneWidget);
    });
  });

  testWidgets('last iOS onboarding step uses Get Started and hides Skip',
      (tester) async {
    await _withPlatform(TargetPlatform.iOS, () async {
      await _pumpApp(tester, onboardingCompleted: false);

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text(IosOnboardingCopy.next));
        await tester.pumpAndSettle();
      }

      expect(find.text(IosOnboardingCopy.step5Title), findsOneWidget);
      expect(find.text(IosOnboardingCopy.getStarted), findsOneWidget);
      expect(find.text(IosOnboardingCopy.skip), findsNothing);

      await tester.tap(find.text(IosOnboardingCopy.getStarted));
      await tester.pumpAndSettle();
      expect(find.text(DecisionCopy.optionsStepTitle), findsOneWidget);
    });
  });
}
