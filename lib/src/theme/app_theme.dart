import 'package:flutter/material.dart';

import 'tokens.dart';

class AppTheme {
  static ThemeData light() => _build(
        brightness: Brightness.light,
        pageBg: TwiffelTokens.pageBgLight,
        onSurface: TwiffelTokens.textPrimaryLight,
        onSurfaceVariant: TwiffelTokens.textSecondaryLight,
        inputBg: TwiffelTokens.inputBgLight,
        border: TwiffelTokens.borderDefaultLight,
        hint: TwiffelTokens.textTertiaryLight,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        pageBg: TwiffelTokens.pageBgDark,
        onSurface: TwiffelTokens.textPrimaryDark,
        onSurfaceVariant: TwiffelTokens.textSecondaryDark,
        inputBg: TwiffelTokens.inputBgDark,
        border: TwiffelTokens.borderDefaultDark,
        hint: TwiffelTokens.textTertiaryDark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color pageBg,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color inputBg,
    required Color border,
    required Color hint,
  }) {
    final isLight = brightness == Brightness.light;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: TwiffelTokens.primary600,
      brightness: brightness,
      primary: TwiffelTokens.primaryDefault,
      onPrimary: TwiffelTokens.textOnPrimary,
      surface: pageBg,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: pageBg,
      appBarTheme: AppBarTheme(
        backgroundColor: pageBg,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: TwiffelTokens.borderFocus, width: 2),
        ),
        hintStyle: TextStyle(
          color: hint,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TwiffelTokens.primaryDefault,
          foregroundColor: TwiffelTokens.textOnPrimary,
          // Light: pale amber + white text failed contrast. Use solid muted
          // neutrals so the label stays readable when disabled.
          disabledBackgroundColor:
              isLight ? TwiffelTokens.gray200 : TwiffelTokens.gray700,
          disabledForegroundColor:
              isLight ? TwiffelTokens.gray600 : TwiffelTokens.gray400,
          minimumSize: const Size.fromHeight(TwiffelTokens.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TwiffelTokens.buttonHeight / 2),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(TwiffelTokens.buttonHeight),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: TextTheme(
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: onSurface,
          height: 1.25,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: onSurface,
          height: 1.3,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariant,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariant,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
      ),
    );
  }
}
