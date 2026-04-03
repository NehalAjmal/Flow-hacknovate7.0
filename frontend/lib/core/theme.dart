import 'package:flutter/material.dart';

class FlowTheme {
  static const Color flowGreen = Color(0xFF1D9E75);
  static const Color textCritical = Color(0xFF9E3D4A); 
  static const Color warningAmber = Color(0xFFEF9F27);

  // --- DARK MODE (Deep Forest) ---
  static const Color bgDark = Color(0xFF161A18);
  static const Color surfaceDark = Color(0xFF1E2421);
  static const Color borderDark = Colors.white10;
  static const Color textPrimaryDark = Color(0xFFE8F0EA);
  static const Color textSecondaryDark = Color(0xFF8A9E8D);

  // --- LIGHT MODE (Sage / Warm Paper) ---
  static const Color bgLight = Color(0xFFF6F5F2); 
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE5E5E5);
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF757575);

  // Custom Fluid Page Transitions for Desktop
  static const PageTransitionsTheme _fluidTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
    },
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: flowGreen,
      cardColor: surfaceDark,
      dividerColor: borderDark,
      fontFamily: 'Inter', 
      pageTransitionsTheme: _fluidTransitions, // <--- Added Fluidity
      colorScheme: const ColorScheme.dark(
        primary: flowGreen,
        surface: surfaceDark,
        error: textCritical,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.bold, fontSize: 36), 
        headlineMedium: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.w600, fontSize: 18), 
        bodyLarge: TextStyle(color: textPrimaryDark, fontSize: 14), 
        bodyMedium: TextStyle(color: textSecondaryDark, fontSize: 13), 
        labelSmall: TextStyle(color: textSecondaryDark, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgLight,
      primaryColor: flowGreen,
      cardColor: surfaceLight,
      dividerColor: borderLight,
      fontFamily: 'Inter',
      pageTransitionsTheme: _fluidTransitions, // <--- Added Fluidity
      colorScheme: const ColorScheme.light(
        primary: flowGreen,
        surface: surfaceLight,
        error: textCritical,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.bold, fontSize: 36),
        headlineMedium: TextStyle(color: textPrimaryLight, fontWeight: FontWeight.w600, fontSize: 18),
        bodyLarge: TextStyle(color: textPrimaryLight, fontSize: 14),
        bodyMedium: TextStyle(color: textSecondaryLight, fontSize: 13),
        labelSmall: TextStyle(color: textSecondaryLight, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600),
      ),
    );
  }
}