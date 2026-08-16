import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twiffel_app/src/pages/onboarding_platform.dart';

void main() {
  test('Android shows first-launch onboarding', () {
    expect(isOnboardingEnabledFor(TargetPlatform.android), isTrue);
  });

  test('iOS shows first-launch onboarding', () {
    expect(isOnboardingEnabledFor(TargetPlatform.iOS), isTrue);
  });

  test('desktop and other platforms skip onboarding', () {
    expect(isOnboardingEnabledFor(TargetPlatform.windows), isFalse);
    expect(isOnboardingEnabledFor(TargetPlatform.macOS), isFalse);
  });
}
