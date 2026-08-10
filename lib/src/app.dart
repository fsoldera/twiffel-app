import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';

import 'config/app_config.dart';
import 'router.dart';
import 'services/ai_client.dart';
import 'services/analytics.dart';
import 'state/app_settings_controller.dart';
import 'state/session_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/app_splash_overlay.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final LicenseController _license;
  late final SessionController _session;
  late final Analytics _analytics;
  late final AiClient _ai;
  late final AppSettingsController _settings;
  late final GoRouter _router;

  /// Flutter splash plate on top of the app (native splash cannot fade).
  bool _splashVisible = true;
  bool _splashMounted = true;

  @override
  void initState() {
    super.initState();
    _license = LicenseController(appLicenseConfig);
    _license.init();
    _settings = AppSettingsController();
    _settings.init();
    _ai = AiClient();
    _analytics = Analytics();
    _session = SessionController(
      license: _license,
      ai: _ai,
      analytics: _analytics,
    );
    _router = buildRouter(
      session: _session,
      license: _license,
      analytics: _analytics,
      settings: _settings,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _finishSplash());
  }

  Future<void> _finishSplash() async {
    final elapsed = DateTime.now().difference(appLaunchAt);
    final remaining = kMinSplashDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
    if (!mounted) return;

    // Native plate has no cross-fade API; hand off to the matching Flutter plate.
    FlutterNativeSplash.remove();
    setState(() => _splashVisible = false);
  }

  void _onSplashFadeEnd() {
    if (_splashVisible || !_splashMounted) return;
    setState(() => _splashMounted = false);
  }

  @override
  void dispose() {
    _session.dispose();
    _license.dispose();
    _settings.dispose();
    _ai.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        return MaterialApp.router(
          title: kAppName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _settings.themeMode,
          routerConfig: _router,
          builder: (context, child) {
            return Stack(
              fit: StackFit.expand,
              children: [
                AnimatedOpacity(
                  opacity: _splashVisible ? 0 : 1,
                  duration: kSplashFadeDuration,
                  curve: Curves.easeOut,
                  child: child ?? const SizedBox.shrink(),
                ),
                if (_splashMounted)
                  IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _splashVisible ? 1 : 0,
                      duration: kSplashFadeDuration,
                      curve: Curves.easeOut,
                      onEnd: _onSplashFadeEnd,
                      child: const AppSplashOverlay(),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
