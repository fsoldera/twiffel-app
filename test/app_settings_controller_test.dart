import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twiffel_app/src/state/app_settings_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('defaults to sound/vibration on and system theme', () async {
    final store = LocalStore('app_settings_test_defaults');
    final settings = AppSettingsController(store: store);
    await settings.init();

    expect(settings.soundEnabled, isTrue);
    expect(settings.vibrationEnabled, isTrue);
    expect(settings.themeMode, ThemeMode.system);
  });

  test('persists sound, vibration, and theme mode', () async {
    final store = LocalStore('app_settings_test_persist');
    final settings = AppSettingsController(store: store);
    await settings.init();

    await settings.setSoundEnabled(false);
    await settings.setVibrationEnabled(false);
    await settings.setThemeMode(ThemeMode.dark);

    final reloaded = AppSettingsController(store: store);
    await reloaded.init();
    expect(reloaded.soundEnabled, isFalse);
    expect(reloaded.vibrationEnabled, isFalse);
    expect(reloaded.themeMode, ThemeMode.dark);
  });
}
