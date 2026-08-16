import 'package:flutter/foundation.dart';

/// First-launch onboarding is platform-specific.
///
/// Android uses the current Figma flow (`onboarding-1` through `onboarding-5`).
/// iOS stays off until those screens are added, then flip [TargetPlatform.iOS]
/// to `true` here and fill [IosOnboardingPage].
bool isOnboardingEnabledFor(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.android:
      return true;
    case TargetPlatform.iOS:
      return false;
    default:
      return false;
  }
}

bool get isOnboardingEnabled =>
    isOnboardingEnabledFor(defaultTargetPlatform);
