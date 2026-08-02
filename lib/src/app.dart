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
    // Drop the native stacked-logo plate once Flutter has painted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
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
        );
      },
    );
  }
}
