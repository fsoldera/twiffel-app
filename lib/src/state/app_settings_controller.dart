import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter/material.dart';

/// App-wide text size preference.
///
/// [small] matches the designed baseline sizes. [medium] is the default
/// (slightly larger). [large] is the biggest option.
enum AppTextSize {
  small(1.0),
  medium(1.15),
  large(1.3);

  const AppTextSize(this.scale);

  /// Multiplier applied on top of the platform text scaler.
  final double scale;
}

/// User preferences for appearance and text size (persisted locally).
///
/// Sound and vibration stay off until those features are implemented.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController({LocalStore? store})
      : _store = store ?? LocalStore('app_settings');

  static const String _keySoundEnabled = 'sound_enabled';
  static const String _keyVibrationEnabled = 'vibration_enabled';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyTextSize = 'text_size';

  /// Stored ints: 0 = system, 1 = light, 2 = dark.
  static const int _themeSystem = 0;
  static const int _themeLight = 1;
  static const int _themeDark = 2;

  /// Stored ints: 0 = small, 1 = medium (default), 2 = large.
  static const int _textSmall = 0;
  static const int _textMedium = 1;
  static const int _textLarge = 2;

  final LocalStore _store;

  bool _initialized = false;
  bool _soundEnabled = false;
  bool _vibrationEnabled = false;
  ThemeMode _themeMode = ThemeMode.system;
  AppTextSize _textSize = AppTextSize.medium;

  bool get initialized => _initialized;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  ThemeMode get themeMode => _themeMode;
  AppTextSize get textSize => _textSize;

  Future<void> init() async {
    // Force sound/vibration off until the features ship (ignore prior prefs).
    _soundEnabled = false;
    _vibrationEnabled = false;
    await _store.setInt(_keySoundEnabled, 0);
    await _store.setInt(_keyVibrationEnabled, 0);
    _themeMode = _themeModeFromInt(
      await _store.getInt(_keyThemeMode, fallback: _themeSystem),
    );
    _textSize = _textSizeFromInt(
      await _store.getInt(_keyTextSize, fallback: _textMedium),
    );
    _initialized = true;
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool enabled) async {
    // Not implemented in the UI yet; keep off.
    if (!_soundEnabled && !enabled) return;
    _soundEnabled = false;
    await _store.setInt(_keySoundEnabled, 0);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    // Not implemented in the UI yet; keep off.
    if (!_vibrationEnabled && !enabled) return;
    _vibrationEnabled = false;
    await _store.setInt(_keyVibrationEnabled, 0);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _store.setInt(_keyThemeMode, _intFromThemeMode(mode));
    notifyListeners();
  }

  Future<void> setTextSize(AppTextSize size) async {
    if (_textSize == size) return;
    _textSize = size;
    await _store.setInt(_keyTextSize, _intFromTextSize(size));
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

  static AppTextSize _textSizeFromInt(int value) {
    switch (value) {
      case _textSmall:
        return AppTextSize.small;
      case _textLarge:
        return AppTextSize.large;
      default:
        return AppTextSize.medium;
    }
  }

  static int _intFromTextSize(AppTextSize size) {
    switch (size) {
      case AppTextSize.small:
        return _textSmall;
      case AppTextSize.medium:
        return _textMedium;
      case AppTextSize.large:
        return _textLarge;
    }
  }
}
