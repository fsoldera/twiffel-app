import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/analytics.dart';
import '../state/app_settings_controller.dart';
import 'android_onboarding_page.dart';
import 'ios_onboarding_page.dart';

/// Picks the platform onboarding flow. Android and iOS stay separate.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.settings,
    this.analytics,
  });

  final AppSettingsController settings;
  final Analytics? analytics;

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return IosOnboardingPage(
          settings: settings,
          analytics: analytics,
        );
      case TargetPlatform.android:
        return AndroidOnboardingPage(
          settings: settings,
          analytics: analytics,
        );
      default:
        return AndroidOnboardingPage(
          settings: settings,
          analytics: analytics,
        );
    }
  }
}
