import 'package:flutter/material.dart';

class AppTheme {
  static const Color _brand = Color(0xFF2563EB);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _brand, brightness: Brightness.light),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _brand, brightness: Brightness.dark),
      );
}
