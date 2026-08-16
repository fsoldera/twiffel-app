import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_config.dart';
import '../services/analytics.dart';
import '../state/app_settings_controller.dart';
import 'android_onboarding_copy.dart';

/// Android first-launch pager matching Figma `onboarding-1` through `onboarding-5`.
class AndroidOnboardingPage extends StatefulWidget {
  const AndroidOnboardingPage({
    super.key,
    required this.settings,
    this.analytics,
  });

  final AppSettingsController settings;
  final Analytics? analytics;

  static const int stepCount = 5;

  @override
  State<AndroidOnboardingPage> createState() => _AndroidOnboardingPageState();
}

class _AndroidOnboardingPageState extends State<AndroidOnboardingPage> {
  static const _bg = Color(0xFF1A1F2E);
  static const _muted = Color(0xFF94A3B8);
  static const _accent = Color(0xFFE8991C);
  static const _ctaInk = Color(0xFF0D111C);
  static const _dotIdle = Color(0xFF475569);
  static const _mockFrame = Color(0xFF334155);

  static const _steps = <({
    String title,
    String body,
    String image,
  })>[
    (
      title: AndroidOnboardingCopy.step1Title,
      body: AndroidOnboardingCopy.step1Body,
      image: 'assets/onboarding/android/onboarding-1.png',
    ),
    (
      title: AndroidOnboardingCopy.step2Title,
      body: AndroidOnboardingCopy.step2Body,
      image: 'assets/onboarding/android/onboarding-2.png',
    ),
    (
      title: AndroidOnboardingCopy.step3Title,
      body: AndroidOnboardingCopy.step3Body,
      image: 'assets/onboarding/android/onboarding-3.png',
    ),
    (
      title: AndroidOnboardingCopy.step4Title,
      body: AndroidOnboardingCopy.step4Body,
      image: 'assets/onboarding/android/onboarding-4.png',
    ),
    (
      title: AndroidOnboardingCopy.step5Title,
      body: AndroidOnboardingCopy.step5Body,
      image: 'assets/onboarding/android/onboarding-5.png',
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
                  return _AndroidOnboardingStep(
                    title: step.title,
                    body: step.body,
                    imageAsset: step.image,
                    mockFrame: _mockFrame,
                    muted: _muted,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  _dots(),
                  const SizedBox(height: 32),
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
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            kAppName.toUpperCase(),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              height: 1,
            ),
          ),
          const Spacer(),
          if (!_isLast)
            Material(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(100),
              child: InkWell(
                onTap: _finish,
                borderRadius: BorderRadius.circular(100),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    AndroidOnboardingCopy.skip,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
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
            width: i == _index ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == _index ? _accent : _dotIdle,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ],
    );
  }

  Widget _cta() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33E8991C),
            blurRadius: 8,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: _accent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _next,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: Center(
              child: Text(
                _isLast
                    ? AndroidOnboardingCopy.getStarted
                    : AndroidOnboardingCopy.next,
                style: const TextStyle(
                  color: _ctaInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AndroidOnboardingStep extends StatelessWidget {
  const _AndroidOnboardingStep({
    required this.title,
    required this.body,
    required this.imageAsset,
    required this.mockFrame,
    required this.muted,
  });

  final String title;
  final String body;
  final String imageAsset;
  final Color mockFrame;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280, maxHeight: 320),
                child: AspectRatio(
                  aspectRatio: 280 / 320,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: mockFrame,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
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
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 32 / 24,
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
              height: 22 / 15,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
