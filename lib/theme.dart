import 'package:flutter/material.dart';

class HrcTheme {
  static const gold = Color(0xFFB99045);
  static const goldLight = Color(0xFFD8B875);
  static const ink = Color(0xFF111827);
  static const cream = Color(0xFFF7F4EE);
  static const dark = Color(0xFF0B0F14);
  static const darkSurface = Color(0xFF121923);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.light).copyWith(
      primary: const Color(0xFF9A7434),
      onPrimary: Colors.white,
      secondary: const Color(0xFF6B552E),
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: cream,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE6E0D5))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: gold, width: 1.5)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: const BorderSide(color: Color(0xFFD8D0C2)), textStyle: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        backgroundColor: Colors.white,
        indicatorColor: gold.withOpacity(.16),
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
      ),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -.4),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        bodyLarge: TextStyle(fontSize: 15),
        bodyMedium: TextStyle(fontSize: 13),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    );
  }

  static ThemeData darkTheme() {
    final scheme = ColorScheme.fromSeed(seedColor: goldLight, brightness: Brightness.dark).copyWith(
      primary: goldLight,
      onPrimary: const Color(0xFF17120A),
      secondary: const Color(0xFFC9AA6B),
      surface: darkSurface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(backgroundColor: dark, foregroundColor: Colors.white, elevation: 0, scrolledUnderElevation: 0),
      cardTheme: CardThemeData(elevation: 0, margin: EdgeInsets.zero, color: darkSurface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: darkSurface, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF273241))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: goldLight, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: const TextStyle(fontWeight: FontWeight.w800))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: const BorderSide(color: Color(0xFF354052)), textStyle: const TextStyle(fontWeight: FontWeight.w800))),
      navigationBarTheme: NavigationBarThemeData(height: 74, backgroundColor: darkSurface, indicatorColor: goldLight.withOpacity(.16), labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      textTheme: const TextTheme(headlineSmall: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -.4), titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w900), titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w800), bodyLarge: TextStyle(fontSize: 15), bodyMedium: TextStyle(fontSize: 13), labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
    );
  }
}
