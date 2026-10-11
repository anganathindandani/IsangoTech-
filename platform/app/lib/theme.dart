import 'package:flutter/material.dart';

/// Brand Board v1 colours.
class Brand {
  static const indigo = Color(0xFF1B2A4A);
  static const ochre = Color(0xFFE07A1F);
  static const turquoise = Color(0xFF2BA8A0);
  static const turquoiseText = Color(0xFF1D7A74);
  static const terracotta = Color(0xFFB5523B);
  static const sand = Color(0xFFF5EBDD);
  static const white = Color(0xFFFFFFFF);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.indigo,
    primary: Brand.indigo,
    secondary: Brand.turquoiseText,
    tertiary: Brand.ochre,
    error: Brand.terracotta,
    surface: Brand.white,
  );
  const body = 'DM Sans';
  const display = 'Outfit';
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: body);
  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFFFAF6EF),
    textTheme: base.textTheme.copyWith(
      headlineMedium: const TextStyle(fontFamily: display, fontWeight: FontWeight.w700, color: Brand.indigo),
      headlineSmall: const TextStyle(fontFamily: display, fontWeight: FontWeight.w700, color: Brand.indigo),
      titleLarge: const TextStyle(fontFamily: display, fontWeight: FontWeight.w600, color: Brand.indigo),
      titleMedium: const TextStyle(fontFamily: display, fontWeight: FontWeight.w600, color: Brand.indigo),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Brand.white,
      foregroundColor: Brand.indigo,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: TextStyle(fontFamily: display, fontWeight: FontWeight.w600, fontSize: 20, color: Brand.indigo),
    ),
    cardTheme: const CardThemeData(
      color: Brand.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: Brand.ochre, foregroundColor: Brand.white),
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), isDense: true),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Brand.indigo,
      selectedIconTheme: IconThemeData(color: Brand.indigo),
      unselectedIconTheme: IconThemeData(color: Brand.sand),
      selectedLabelTextStyle: TextStyle(color: Brand.white, fontWeight: FontWeight.w500),
      unselectedLabelTextStyle: TextStyle(color: Brand.sand),
      indicatorColor: Brand.sand,
    ),
  );
}
