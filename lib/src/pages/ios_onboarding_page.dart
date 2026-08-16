import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../services/analytics.dart';
import '../state/app_settings_controller.dart';
import 'ios_onboarding_copy.dart';

/// iOS first-launch flow.
///
/// Placeholder until iOS Figma screens exist. Do not reuse the Android pager
/// or `assets/onboarding/android/` mockups. Put iOS art in
/// `assets/onboarding/ios/` when ready, then enable iOS in
/// `onboarding_platform.dart`.
class IosOnboardingPage extends StatefulWidget {
  const IosOnboardingPage({
    super.key,
    required this.settings,
    this.analytics,
  });

  final AppSettingsController settings;
  final Analytics? analytics;

  @override
  State<IosOnboardingPage> createState() => _IosOnboardingPageState();
}

class _IosOnboardingPageState extends State<IosOnboardingPage> {
  @override
  void initState() {
    super.initState();
    widget.analytics?.track('onboarding_view');
  }

  Future<void> _finish() async {
    widget.analytics?.track('onboarding_complete');
    await widget.settings.completeOnboarding();
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              Text(
                kAppName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _finish,
                  child: const Text(IosOnboardingCopy.getStarted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
