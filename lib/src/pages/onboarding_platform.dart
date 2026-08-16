import 'package:flutter/foundation.dart';

/// First-launch onboarding is platform-specific.
///
/// Android uses Figma `onboarding-1` through `onboarding-5`.
/// iOS uses Figma `ios-onboarding-1` through `ios-onboarding-5`.
bool isOnboardingEnabledFor(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.android:
      return true;
    case TargetPlatform.iOS:
      return true;
    default:
      return false;
  }
}

bool get isOnboardingEnabled =>
    isOnboardingEnabledFor(defaultTargetPlatform);
