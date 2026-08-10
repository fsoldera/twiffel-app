import 'package:flutter/material.dart';

/// Twiffel design tokens mirrored from `src/theme/tokens.ts`
/// (Figma Twiffel_Design_Tokens / 13:480).
abstract final class TwiffelTokens {
  // Neutral
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);
  static const Color gray950 = Color(0xFF030712);

  // Primary (amber)
  static const Color primary50 = Color(0xFFFFFBEB);
  static const Color primary100 = Color(0xFFFEF3C7);
  static const Color primary200 = Color(0xFFFDE68A);
  static const Color primary300 = Color(0xFFFCD34D);
  static const Color primary400 = Color(0xFFFBBF24);
  static const Color primary500 = Color(0xFFF59E0B);
  static const Color primary600 = Color(0xFFD97706);
  static const Color primary700 = Color(0xFFB45309);
  static const Color primary800 = Color(0xFF92400E);
  static const Color primary900 = Color(0xFF78350F);

  // Semantic
  static const Color semanticSuccess = Color(0xFF10B981);
  static const Color semanticError = Color(0xFFEF4444);

  // Surface
  static const Color pageBgLight = Color(0xFFFFFFFF);
  static const Color pageBgDark = Color(0xFF111827);
  static const Color cardSurfaceLight = Color(0xFFFFFFFF);
  static const Color cardSurfaceDark = Color(0xFF1F2937);
  static const Color elevatedLight = Color(0xFFF9FAFB);
  static const Color elevatedDark = Color(0xFF374151);
  static const Color inputBgLight = Color(0xFFF3F4F6);
  static const Color inputBgDark = Color(0xFF1F2937);

  // Text
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryLight = Color(0xFF4B5563);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color textTertiaryLight = Color(0xFF9CA3AF);
  static const Color textTertiaryDark = Color(0xFF6B7280);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Border
  static const Color borderDefaultLight = Color(0xFFE5E7EB);
  static const Color borderDefaultDark = Color(0xFF374151);
  static const Color borderStrongLight = Color(0xFFD1D5DB);
  static const Color borderStrongDark = Color(0xFF4B5563);
  static const Color borderFocus = Color(0xFFD97706);

  // Interactive
  static const Color primaryDefault = Color(0xFFD97706);
  static const Color primaryHover = Color(0xFFB45309);
  static const Color primaryPressed = Color(0xFF92400E);
  /// Disabled primary fill (solid; avoid translucent amber + white text).
  static const Color primaryDisabled = Color(0xFFE5E7EB);
  static const Color secondaryDefault = Color(0xFFFBBF24);
}

/// Theme-resolved Twiffel colors for light/dark mode.
final class TwiffelColors {
  const TwiffelColors._(this.isDark);

  factory TwiffelColors.of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return TwiffelColors._(brightness == Brightness.dark);
  }

  final bool isDark;

  Color get pageBg =>
      isDark ? TwiffelTokens.pageBgDark : TwiffelTokens.pageBgLight;
  Color get cardSurface =>
      isDark ? TwiffelTokens.cardSurfaceDark : TwiffelTokens.cardSurfaceLight;
  Color get elevated =>
      isDark ? TwiffelTokens.elevatedDark : TwiffelTokens.elevatedLight;
  Color get inputBg =>
      isDark ? TwiffelTokens.inputBgDark : TwiffelTokens.inputBgLight;

  Color get textPrimary =>
      isDark ? TwiffelTokens.textPrimaryDark : TwiffelTokens.textPrimaryLight;
  Color get textSecondary => isDark
      ? TwiffelTokens.textSecondaryDark
      : TwiffelTokens.textSecondaryLight;
  Color get textTertiary =>
      isDark ? TwiffelTokens.textTertiaryDark : TwiffelTokens.textTertiaryLight;

  Color get borderDefault => isDark
      ? TwiffelTokens.borderDefaultDark
      : TwiffelTokens.borderDefaultLight;
  Color get borderStrong =>
      isDark ? TwiffelTokens.borderStrongDark : TwiffelTokens.borderStrongLight;

  /// Soft fill for idle chips/cards.
  Color get softFill => isDark ? TwiffelTokens.gray800 : TwiffelTokens.gray50;

  /// Soft amber fill for selected chips/cards.
  Color get selectedFill =>
      isDark ? TwiffelTokens.primary900 : TwiffelTokens.primary100;
}
