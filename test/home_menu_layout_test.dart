import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twiffel_app/src/config/app_config.dart';
import 'package:twiffel_app/src/state/app_settings_controller.dart';
import 'package:twiffel_app/src/theme/app_theme.dart';
import 'package:twiffel_app/src/widgets/home_menu_button.dart';

void main() {
  Future<void> pumpMenu(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = AppSettingsController();
    await settings.init();

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: HomeMenuButton(settings: settings),
            ),
          ),
        ),
        GoRoute(
          path: '/shop',
          name: 'shop',
          builder: (context, state) => const Scaffold(
            body: Text('shop'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.dark(),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
  }

  testWidgets('menu exposes Sound, Vibration, Appearance, and Buy a license',
      (tester) async {
    await pumpMenu(tester);
    expect(find.text('Sound'), findsOneWidget);
    expect(find.text('Vibration'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text(appLicenseConfig.unlockButtonText), findsOneWidget);
  });

  testWidgets('theme Auto selection updates settings', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = AppSettingsController();
    await settings.init();
    await settings.setThemeMode(ThemeMode.dark);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: HomeMenuButton(settings: settings),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auto'));
    await tester.pumpAndSettle();

    expect(settings.themeMode, ThemeMode.system);
  });
}
