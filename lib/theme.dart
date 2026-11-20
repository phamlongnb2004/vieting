import 'package:flutter/material.dart';

class Brand {
  static const red = Color(0xFFC1272C);
  static const yellow = Color(0xFFFFCD00);
  static const bamboo = Color(0xFF3E8E41);
  static const bambooLight = Color(0xFF8BC34A);
  static const navy = Color(0xFF152758);
  static const cream = Color(0xFFFFF8EC);
  static const income = Color(0xFF2E7D32);
  static const expense = Color(0xFFC1272C);
}

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.red,
    brightness: b,
    primary: b == Brightness.light ? Brand.red : const Color(0xFFFF8A80),
    secondary: Brand.bamboo,
    tertiary: Brand.yellow,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFFBF8F3) : const Color(0xFF15130F),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: b == Brightness.light ? const Color(0xFFFBF8F3) : const Color(0xFF15130F),
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: b == Brightness.light ? Colors.white : const Color(0xFF221F1A),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      filled: true,
      fillColor: b == Brightness.light ? Colors.white : const Color(0xFF221F1A),
    ),
  );
}
