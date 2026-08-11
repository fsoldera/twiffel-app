import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twiffel_app/src/state/app_settings_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('defaults to sound/vibration off, system theme, and medium text',
      () async {
    final store = LocalStore('app_settings_test_defaults');
    final settings = AppSettingsController(store: store);
    await settings.init();

    expect(settings.soundEnabled, isFalse);
    expect(settings.vibrationEnabled, isFalse);
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.textSize, AppTextSize.medium);
  });

  test('keeps sound/vibration off and persists theme mode and text size',
      () async {
    final store = LocalStore('app_settings_test_persist');
    final settings = AppSettingsController(store: store);
    await settings.init();

    await settings.setSoundEnabled(true);
    await settings.setVibrationEnabled(true);
    await settings.setThemeMode(ThemeMode.dark);
    await settings.setTextSize(AppTextSize.large);

    final reloaded = AppSettingsController(store: store);
    await reloaded.init();
    expect(reloaded.soundEnabled, isFalse);
    expect(reloaded.vibrationEnabled, isFalse);
    expect(reloaded.themeMode, ThemeMode.dark);
    expect(reloaded.textSize, AppTextSize.large);
  });
}
