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

/// Minimum time the native launch splash stays up.
const Duration kMinSplashDuration = Duration(milliseconds: 1500);

/// Moment [main] began (overwritten at process start before async work).
DateTime appLaunchAt = DateTime.now();

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
    FlutterNativeSplash.remove();
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
            final media = MediaQuery.of(context);
            final systemFactor = media.textScaler.scale(14) / 14;
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(
                  systemFactor * _settings.textSize.scale,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
