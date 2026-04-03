import 'package:flutter/material.dart';

// ─── SESSION STATE ENUM ───────────────────────────────────────────────────────
// Use this everywhere instead of raw booleans.
// It maps directly to your Focus, Trough, and Drift UI states.
enum SessionState {
  focus,   // Normal: green ring, cool bg
  trough,  // Fatigue warning: orange/copper ring, warm bg shift
  drift,   // Critical: rose/wine ring, red-tinted bg shift
}

class FlowTheme {
  FlowTheme._();

  // ─── LIGHT MODE PALETTE (Redesign Specs) ──────────────────────────────
  static const Color bgLight = Color(0xFFEEF3EF);
  static const Color surfaceLight = Color(0xFFF4F8F5);
  static const Color elevatedLight = Color(0xFFFAFCFB);

  static const Color primaryLight = Color(0xFF6B8F71);
  static const Color primaryTintLight = Color(0xFFE6EFE8);
  static const Color primaryStrongLight = Color(0xFF4F6F57);

  static const Color fatigueBgLight = Color(0xFFF6F0E8);
  static const Color fatigueLight = Color(0xFFA67C52);

  static const Color driftBgLight = Color(0xFFF2E5E7);
  static const Color driftLight = Color(0xFF7A2E3A);

  static const Color text1Light = Color(0xFF1A2E1F);
  static const Color text2Light = Color(0xFF4A6350);
  static const Color text3Light = Color(0xFF8A9E8D);

  static const Color borderLight = Color(0xFFD8E4DA);

  // ─── DARK MODE PALETTE (Redesign Specs) ───────────────────────────────
  static const Color bgDark = Color(0xFF161A18);
  static const Color surfaceDark = Color(0xFF1E2421);
  static const Color elevatedDark = Color(0xFF252E28);

  static const Color primaryDark = Color(0xFF5A8060);
  static const Color primaryTintDark = Color(0xFF1E3028);
  static const Color primaryStrongDark = Color(0xFF7AAD82);

  static const Color fatigueBgDark = Color(0xFF2A1E10);
  static const Color fatigueDark = Color(0xFFC4845A);

  static const Color driftBgDark = Color(0xFF2A1218);
  static const Color driftDark = Color(0xFF9E3D4A);

  static const Color text1Dark = Color(0xFFE8F0EA);
  static const Color text2Dark = Color(0xFF8A9E8D);
  static const Color text3Dark = Color(0xFF566658);

  static const Color borderDark = Color(0xFF2A342C);

  // ─── SEMANTIC HELPERS ─────────────────────────────────────────────────────

  static Color pageBackground(BuildContext context, SessionState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (state) {
      case SessionState.focus:
        return isDark ? bgDark : bgLight;
      case SessionState.trough:
        return isDark ? fatigueBgDark : fatigueBgLight;
      case SessionState.drift:
        return isDark ? driftBgDark : driftBgLight;
    }
  }

  static Color stateColor(BuildContext context, SessionState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (state) {
      case SessionState.focus:
        return isDark ? primaryDark : primaryLight;
      case SessionState.trough:
        return isDark ? fatigueDark : fatigueLight;
      case SessionState.drift:
        return isDark ? driftDark : driftLight;
    }
  }

  static Color ringTrackColor(BuildContext context, SessionState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (state) {
      case SessionState.focus:
        return isDark ? borderDark : borderLight;
      case SessionState.trough:
        return isDark ? fatigueBgDark : fatigueBgLight;
      case SessionState.drift:
        return isDark ? driftBgDark : driftBgLight; // Using standard tint
    }
  }

  // ─── PAGE TRANSITIONS ─────────────────────────────────────────────────────
  static const PageTransitionsTheme _fluidTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
    },
  );

  // ─── LIGHT THEME BUILDER ──────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgLight,
      primaryColor: primaryLight,
      cardColor: surfaceLight,
      dividerColor: borderLight,
      fontFamily: 'Sora', // Main font
      pageTransitionsTheme: _fluidTransitions,
      colorScheme: const ColorScheme.light(
        primary: primaryLight,
        primaryContainer: primaryTintLight,
        secondary: fatigueLight,
        secondaryContainer: fatigueBgLight,
        error: driftLight,
        errorContainer: driftBgLight,
        surface: surfaceLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
        onSurface: text1Light,
      ),
      textTheme: const TextTheme(
        // Big numbers
        displayLarge: TextStyle(color: text1Light, fontWeight: FontWeight.w800, fontSize: 56, letterSpacing: -2.0),
        displayMedium: TextStyle(color: text1Light, fontWeight: FontWeight.w800, fontSize: 40, letterSpacing: -2.0),
        
        // Titles
        headlineLarge: TextStyle(color: text1Light, fontWeight: FontWeight.w700, fontSize: 24, letterSpacing: -0.5),
        headlineMedium: TextStyle(color: text1Light, fontWeight: FontWeight.w700, fontSize: 18),
        headlineSmall: TextStyle(color: text1Light, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: -0.2), // Section titles
        
        // Body text
        bodyLarge: TextStyle(color: text1Light, fontSize: 15, fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(color: text2Light, fontSize: 13, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(color: text3Light, fontSize: 11, fontWeight: FontWeight.w400),
        
        // Labels & Monospace (DM Mono)
        labelLarge: TextStyle(fontFamily: 'DM Mono', color: text2Light, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.02), // Badges
        labelMedium: TextStyle(fontFamily: 'DM Mono', color: text3Light, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.0), // Card Labels
        labelSmall: TextStyle(fontFamily: 'DM Mono', color: text3Light, fontSize: 9, fontWeight: FontWeight.w500, letterSpacing: 0.8),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28), // --radius-lg from redesign
          side: const BorderSide(color: borderLight, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevatedLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: borderLight, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: borderLight, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        hintStyle: const TextStyle(color: text3Light, fontSize: 15, fontFamily: 'Sora'),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)), // Pill shape
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontFamily: 'Sora', fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: borderLight, thickness: 1, space: 8),
    );
  }

  // ─── DARK THEME BUILDER ───────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: primaryDark,
      cardColor: surfaceDark,
      dividerColor: borderDark,
      fontFamily: 'Sora',
      pageTransitionsTheme: _fluidTransitions,
      colorScheme: const ColorScheme.dark(
        primary: primaryDark,
        primaryContainer: primaryTintDark,
        secondary: fatigueDark,
        secondaryContainer: fatigueBgDark,
        error: driftDark,
        errorContainer: driftBgDark,
        surface: surfaceDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
        onSurface: text1Dark,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: text1Dark, fontWeight: FontWeight.w800, fontSize: 56, letterSpacing: -2.0),
        displayMedium: TextStyle(color: text1Dark, fontWeight: FontWeight.w800, fontSize: 40, letterSpacing: -2.0),
        headlineLarge: TextStyle(color: text1Dark, fontWeight: FontWeight.w700, fontSize: 24, letterSpacing: -0.5),
        headlineMedium: TextStyle(color: text1Dark, fontWeight: FontWeight.w700, fontSize: 18),
        headlineSmall: TextStyle(color: text1Dark, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: -0.2),
        bodyLarge: TextStyle(color: text1Dark, fontSize: 15, fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(color: text2Dark, fontSize: 13, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(color: text3Dark, fontSize: 11, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontFamily: 'DM Mono', color: text2Dark, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.02),
        labelMedium: TextStyle(fontFamily: 'DM Mono', color: text3Dark, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.0),
        labelSmall: TextStyle(fontFamily: 'DM Mono', color: text3Dark, fontSize: 9, fontWeight: FontWeight.w500, letterSpacing: 0.8),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: borderDark, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevatedDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: borderDark, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: borderDark, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: primaryDark, width: 2),
        ),
        hintStyle: const TextStyle(color: text3Dark, fontSize: 15, fontFamily: 'Sora'),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontFamily: 'Sora', fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: borderDark, thickness: 1, space: 8),
    );
  }
}