import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Display name shown in the app shell and licensing copy.
/// TODO(template): replace with your app name.
const String kAppName = 'My App';

/// Cloudflare Worker base URL (AI proxy + analytics).
///   flutter run --dart-define=APP_API_BASE=https://my-app-api.YOUR_SUBDOMAIN.workers.dev
const String kApiBase = String.fromEnvironment('APP_API_BASE', defaultValue: '');

/// Privacy Policy URL surfaced in the purchase flow. App Store Review guideline
/// 3.1.2(c) requires a functional privacy policy link inside the app for apps
/// offering auto-renewable subscriptions.
/// TODO(template): point this at your app's published privacy policy page.
const String kPrivacyPolicyUrl = 'https://u-things.com/privacy/my-app';

/// Terms of Use (EULA) URL surfaced in the purchase flow. Defaults to Apple's
/// standard licensed-application EULA, which Apple accepts (guideline 3.1.2(c)).
/// Replace only if your app ships a custom EULA.
const String kTermsOfUseUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

const String _kRevenueCatKeyIos =
    String.fromEnvironment('APP_RC_KEY_IOS', defaultValue: '');
const String _kRevenueCatKeyAndroid =
    String.fromEnvironment('APP_RC_KEY_ANDROID', defaultValue: '');

String _resolveRevenueCatKey() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return _kRevenueCatKeyIos;
    case TargetPlatform.android:
      return _kRevenueCatKeyAndroid;
    default:
      return '';
  }
}

/// TODO(template): customize product IDs, nag copy, and theme for your app.
final LicenseConfig appLicenseConfig = LicenseConfig(
  appName: kAppName,
  revenueCatPublicKey: _resolveRevenueCatKey(),
  entitlementId: 'my_app_pro',
  products: const LicenseProductIds(
    oneTime: 'my_app_unlock',
    monthly: 'my_app_monthly',
  ),
  trigger: NagTrigger.afterNUses,
  nagAfterUses: 10,
  reminderDelay: const Duration(seconds: 5),
  nagTitle: 'Enjoying $kAppName?',
  nagMessage:
      'You\'ve used $kAppName 10 times, and it stays free forever. '
      'A license removes the reminder and supports development.',
  unlockButtonText: 'Buy a license',
  dismissButtonText: 'Maybe later',
  featureBullets: const <String>[
    'Removes this gentle reminder',
    'Supports ongoing development',
    'Keeps the app simple and ad-free',
  ],
  privacyPolicyUrl: kPrivacyPolicyUrl,
  termsOfUseUrl: kTermsOfUseUrl,
  theme: const PaywallTheme(
    primary: Color(0xFF2563EB),
    primaryGradient: LinearGradient(
      colors: <Color>[Color(0xFF22D3EE), Color(0xFF2563EB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    primaryShadowColor: Color(0xFF2563EB),
  ),
);
