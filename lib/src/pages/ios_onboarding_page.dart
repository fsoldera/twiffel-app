import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_config.dart';
import '../services/analytics.dart';
import '../state/app_settings_controller.dart';
import 'ios_onboarding_copy.dart';

/// iOS first-launch pager matching Figma `ios-onboarding-1` through `ios-onboarding-5`.
class IosOnboardingPage extends StatefulWidget {
  const IosOnboardingPage({
    super.key,
    required this.settings,
    this.analytics,
  });

  final AppSettingsController settings;
  final Analytics? analytics;

  static const int stepCount = 5;

  @override
  State<IosOnboardingPage> createState() => _IosOnboardingPageState();
}

class _IosOnboardingPageState extends State<IosOnboardingPage> {
  static const _bg = Colors.white;
  static const _ink = Color(0xFF1F2937);
  static const _muted = Color(0xFF4B5563);
  static const _skip = Color(0xFF9CA3AF);
  static const _accent = Color(0xFFE8991C);
  static const _dotIdle = Color(0xFFE5E7EB);
  static const _frameBorder = Color(0xFFE5E7EB);

  static const _steps = <({
    String title,
    String body,
    String image,
  })>[
    (
      title: IosOnboardingCopy.step1Title,
      body: IosOnboardingCopy.step1Body,
      image: 'assets/onboarding/ios/ios-onboarding-1.png',
    ),
    (
      title: IosOnboardingCopy.step2Title,
      body: IosOnboardingCopy.step2Body,
      image: 'assets/onboarding/ios/ios-onboarding-2.png',
    ),
    (
      title: IosOnboardingCopy.step3Title,
      body: IosOnboardingCopy.step3Body,
      image: 'assets/onboarding/ios/ios-onboarding-3.png',
    ),
    (
      title: IosOnboardingCopy.step4Title,
      body: IosOnboardingCopy.step4Body,
      image: 'assets/onboarding/ios/ios-onboarding-4.png',
    ),
    (
      title: IosOnboardingCopy.step5Title,
      body: IosOnboardingCopy.step5Body,
      image: 'assets/onboarding/ios/ios-onboarding-5.png',
    ),
  ];

  final _pageController = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    widget.analytics?.track('onboarding_view');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLast => _index >= _steps.length - 1;

  Future<void> _finish() async {
    widget.analytics?.track('onboarding_complete');
    await widget.settings.completeOnboarding();
    if (!mounted) return;
    context.go('/');
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return _IosOnboardingStep(
                    title: step.title,
                    body: step.body,
                    imageAsset: step.image,
                    ink: _ink,
                    muted: _muted,
                    frameBorder: _frameBorder,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  _dots(),
                  const SizedBox(height: 20),
                  _cta(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Row(
        children: [
          Text(
            kAppName,
            style: GoogleFonts.inter(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const Spacer(),
          if (!_isLast)
            GestureDetector(
              onTap: _finish,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  IosOnboardingCopy.skip,
                  style: TextStyle(
                    color: _skip,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 32, height: 20),
        ],
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == _index ? _accent : _dotIdle,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }

  Widget _cta() {
    return Material(
      color: _accent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: _next,
        borderRadius: BorderRadius.circular(26),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: Center(
            child: Text(
              _isLast ? IosOnboardingCopy.getStarted : IosOnboardingCopy.next,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IosOnboardingStep extends StatelessWidget {
  const _IosOnboardingStep({
    required this.title,
    required this.body,
    required this.imageAsset,
    required this.ink,
    required this.muted,
    required this.frameBorder,
  });

  final String title;
  final String body;
  final String imageAsset;
  final Color ink;
  final Color muted;
  final Color frameBorder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280, maxHeight: 380),
                child: AspectRatio(
                  aspectRatio: 280 / 380,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: frameBorder, width: 4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        imageAsset,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ink,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
