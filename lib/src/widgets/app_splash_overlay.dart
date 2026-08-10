import 'package:flutter/material.dart';

/// Minimum time the launch splash stays up (native + Flutter handoff).
const Duration kMinSplashDuration = Duration(milliseconds: 1500);

/// Fade duration when the Flutter splash overlay yields to the app.
const Duration kSplashFadeDuration = Duration(milliseconds: 300);

/// Moment [main] began (overwritten at process start before async work).
DateTime appLaunchAt = DateTime.now();

/// Full-screen plate matching `flutter_native_splash` (logo + solid bg).
class AppSplashOverlay extends StatelessWidget {
  const AppSplashOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    final bg = dark ? const Color(0xFF1F2937) : const Color(0xFFFFFFFF);
    final logo = dark
        ? 'assets/splash/splash_logo.png'
        : 'assets/splash/splash_logo_light.png';

    return ColoredBox(
      color: bg,
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.55,
          child: Image.asset(logo, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
