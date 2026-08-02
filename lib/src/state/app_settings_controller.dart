import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter/material.dart';

/// User preferences for sound, haptics, and appearance (persisted locally).
class AppSettingsController extends ChangeNotifier {
  AppSettingsController({LocalStore? store})
      : _store = store ?? LocalStore('app_settings');

  static const String _keySoundEnabled = 'sound_enabled';
  static const String _keyVibrationEnabled = 'vibration_enabled';
  static const String _keyThemeMode = 'theme_mode';

  /// Stored ints: 0 = system, 1 = light, 2 = dark.
  static const int _themeSystem = 0;
  static const int _themeLight = 1;
  static const int _themeDark = 2;

  final LocalStore _store;

  bool _initialized = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  ThemeMode _themeMode = ThemeMode.system;

  bool get initialized => _initialized;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  ThemeMode get themeMode => _themeMode;

  Future<void> init() async {
    _soundEnabled = await _store.getInt(_keySoundEnabled, fallback: 1) == 1;
    _vibrationEnabled =
        await _store.getInt(_keyVibrationEnabled, fallback: 1) == 1;
    _themeMode = _themeModeFromInt(
      await _store.getInt(_keyThemeMode, fallback: _themeSystem),
    );
    _initialized = true;
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool enabled) async {
    if (_soundEnabled == enabled) return;
    _soundEnabled = enabled;
    await _store.setInt(_keySoundEnabled, enabled ? 1 : 0);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    if (_vibrationEnabled == enabled) return;
    _vibrationEnabled = enabled;
    await _store.setInt(_keyVibrationEnabled, enabled ? 1 : 0);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _store.setInt(_keyThemeMode, _intFromThemeMode(mode));
    notifyListeners();
  }

  static ThemeMode _themeModeFromInt(int value) {
    switch (value) {
      case _themeLight:
        return ThemeMode.light;
      case _themeDark:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static int _intFromThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return _themeLight;
      case ThemeMode.dark:
        return _themeDark;
      case ThemeMode.system:
        return _themeSystem;
    }
  }
}
