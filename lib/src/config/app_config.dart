import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Display name shown in the app shell and licensing copy.
const String kAppName = 'Twiffel';

/// Cloudflare Worker base URL (AI proxy + analytics).
///   flutter run --dart-define=TWIFFEL_API_BASE=https://twiffel-api.YOUR_SUBDOMAIN.workers.dev
const String kApiBase = String.fromEnvironment('TWIFFEL_API_BASE', defaultValue: '');

/// Privacy Policy URL surfaced in the purchase flow. App Store Review guideline
/// 3.1.2(c) requires a functional privacy policy link inside the app for apps
/// offering auto-renewable subscriptions.
const String kPrivacyPolicyUrl = 'https://u-things.com/privacy/twiffel';

/// Apple standard EULA for iOS purchase flows (App Store 3.1.2(c)).
/// Android omits a separate EULA link — Play already covers billing terms.
String _resolveTermsOfUseUrl() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return kAppleStandardEulaUrl;
    default:
      return '';
  }
}

const String _kRevenueCatKeyIos =
    String.fromEnvironment('TWIFFEL_RC_KEY_IOS', defaultValue: '');
const String _kRevenueCatKeyAndroid =
    String.fromEnvironment('TWIFFEL_RC_KEY_ANDROID', defaultValue: '');

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

/// Play Store subscriptions are imported as `productId:basePlanId`.
/// App Store / Test Store keep the bare product id.
String _resolveMonthlyProductId() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'twiffel_monthly:monthly';
    default:
      return 'twiffel_monthly';
  }
}

final LicenseConfig appLicenseConfig = LicenseConfig(
  appName: kAppName,
  revenueCatPublicKey: _resolveRevenueCatKey(),
  entitlementId: 'twiffel_pro',
  products: LicenseProductIds(
    oneTime: 'twiffel_unlock',
    monthly: _resolveMonthlyProductId(),
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
  termsOfUseUrl: _resolveTermsOfUseUrl(),
  theme: const PaywallTheme(
    primary: Color(0xFFD97706),
    primaryGradient: LinearGradient(
      colors: <Color>[Color(0xFFFBBF24), Color(0xFFD97706)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    primaryShadowColor: Color(0xFFD97706),
  ),
);
