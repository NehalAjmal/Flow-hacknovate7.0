import 'package:flutter/material.dart';

class FlowTheme {
  FlowTheme._();

  // ─── LIGHT MODE PALETTE (Olive Tint System) ──────────────────────────────

  // Backgrounds — three distinct tinted layers, no pure white
  static const Color bgLight = Color(0xFFEEF3EF);        // Base: page bg, subtle olive tint
  static const Color surfaceLight = Color(0xFFF4F8F5);   // Surface: cards, navbar
  static const Color elevatedLight = Color(0xFFFAFCFB);  // Elevated: modals, overlays

  // Primary identity — dusty olive
  static const Color primaryLight = Color(0xFF6B8F71);
  static const Color primaryTintLight = Color(0xFFE6EFE8); // badge bg, active pill bg
  static const Color primaryStrongLight = Color(0xFF4F6F57); // hover, pressed

  // State colors — light mode
  static const Color fatigueBgLight = Color(0xFFF6F0E8);   // Trough page bg shift
  static const Color fatigueLight = Color(0xFFA67C52);     // Faded copper — warning ring, label
  static const Color driftBgLight = Color(0xFFF2E5E7);     // Drift page bg shift
  static const Color driftLight = Color(0xFF7A2E3A);       // Wine plum — critical ring, alert

  // Text — light mode
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textTertiaryLight = Color(0xFF9CA3AF);

  // Border — light mode
  static const Color borderLight = Color(0xFFE2E6E2);

  // ─── DARK MODE PALETTE (Deep Forest System) ───────────────────────────────

  // Backgrounds
  static const Color bgDark = Color(0xFF161A18);           // Base: deep forest
  static const Color surfaceDark = Color(0xFF1E2421);      // Surface: cards, navbar
  static const Color elevatedDark = Color(0xFF252E28);     // Elevated: modals, overlays

  // Primary identity — muted sage
  static const Color primaryDark = Color(0xFF5A8060);
  static const Color primaryTintDark = Color(0xFF1E3028);   // badge bg, active pill bg
  static const Color primaryLightDark = Color(0xFF7AAD82);  // hover, text accent

  // State colors — dark mode
  static const Color fatigueBgDark = Color(0xFF1E1810);    // Trough page bg shift
  static const Color fatigueDark = Color(0xFFC4845A);      // Warning ring
  static const Color driftBgDark = Color(0xFF1E1214);      // Drift page bg shift
  static const Color driftDark = Color(0xFF9E3D4A);        // Critical ring

  // Text — dark mode
  static const Color textPrimaryDark = Color(0xFFE8F0EA);
  static const Color textSecondaryDark = Color(0xFF8A9E8D);
  static const Color textTertiaryDark = Color(0xFF566658);

  // Border — dark mode
  static const Color borderDark = Color(0xFF2A342C);

  // ─── SEMANTIC HELPERS (use these in widgets, not raw colors) ─────────────

  /// Returns the correct page background for the current session state.
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

  /// Returns the correct ring/accent color for the current session state.
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

  /// Returns the ring track (background) color for the current session state.
  static Color ringTrackColor(BuildContext context, SessionState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (state) {
      case SessionState.focus:
        return isDark ? borderDark : borderLight;
      case SessionState.trough:
        return isDark ? fatigueBgDark : fatigueBgLight;
      case SessionState.drift:
        return isDark ? driftBgDark : const Color(0xFFF2E5E7);
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

  // ─── LIGHT THEME ──────────────────────────────────────────────────────────

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgLight,
      primaryColor: primaryLight,
      cardColor: surfaceLight,
      dividerColor: borderLight,
      fontFamily: 'Inter',
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
        onSurface: textPrimaryLight,
      ),
      textTheme: const TextTheme(
        // Numbers — big + bold (data-driven feel)
        displayLarge: TextStyle(
          color: textPrimaryLight,
          fontWeight: FontWeight.w700,
          fontSize: 48,
          letterSpacing: -1.5,
        ),
        displayMedium: TextStyle(
          color: textPrimaryLight,
          fontWeight: FontWeight.w700,
          fontSize: 36,
          letterSpacing: -1.0,
        ),
        // Titles — medium weight
        headlineLarge: TextStyle(
          color: textPrimaryLight,
          fontWeight: FontWeight.w500,
          fontSize: 24,
        ),
        headlineMedium: TextStyle(
          color: textPrimaryLight,
          fontWeight: FontWeight.w500,
          fontSize: 18,
        ),
        headlineSmall: TextStyle(
          color: textPrimaryLight,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        // Body
        bodyLarge: TextStyle(color: textPrimaryLight, fontSize: 14, height: 1.6),
        bodyMedium: TextStyle(color: textSecondaryLight, fontSize: 13, height: 1.5),
        bodySmall: TextStyle(color: textTertiaryLight, fontSize: 12, height: 1.4),
        // Labels — light + uppercase (use with .toUpperCase() in widget)
        labelLarge: TextStyle(
          color: textSecondaryLight,
          fontSize: 11,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.4,
        ),
        labelMedium: TextStyle(
          color: textSecondaryLight,
          fontSize: 10,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.2,
        ),
        labelSmall: TextStyle(
          color: textTertiaryLight,
          fontSize: 9,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.0,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryLight, width: 1),
        ),
        labelStyle: const TextStyle(color: textSecondaryLight, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryLight,
          side: const BorderSide(color: primaryLight, width: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderLight,
        thickness: 0.5,
        space: 0,
      ),
    );
  }

  // ─── DARK THEME ───────────────────────────────────────────────────────────

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: primaryDark,
      cardColor: surfaceDark,
      dividerColor: borderDark,
      fontFamily: 'Inter',
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
        onSurface: textPrimaryDark,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimaryDark,
          fontWeight: FontWeight.w700,
          fontSize: 48,
          letterSpacing: -1.5,
        ),
        displayMedium: TextStyle(
          color: textPrimaryDark,
          fontWeight: FontWeight.w700,
          fontSize: 36,
          letterSpacing: -1.0,
        ),
        headlineLarge: TextStyle(
          color: textPrimaryDark,
          fontWeight: FontWeight.w500,
          fontSize: 24,
        ),
        headlineMedium: TextStyle(
          color: textPrimaryDark,
          fontWeight: FontWeight.w500,
          fontSize: 18,
        ),
        headlineSmall: TextStyle(
          color: textPrimaryDark,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        bodyLarge: TextStyle(color: textPrimaryDark, fontSize: 14, height: 1.6),
        bodyMedium: TextStyle(color: textSecondaryDark, fontSize: 13, height: 1.5),
        bodySmall: TextStyle(color: textTertiaryDark, fontSize: 12, height: 1.4),
        labelLarge: TextStyle(
          color: textSecondaryDark,
          fontSize: 11,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.4,
        ),
        labelMedium: TextStyle(
          color: textSecondaryDark,
          fontSize: 10,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.2,
        ),
        labelSmall: TextStyle(
          color: textTertiaryDark,
          fontSize: 9,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.0,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderDark, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderDark, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryDark, width: 1),
        ),
        labelStyle: const TextStyle(color: textSecondaryDark, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          side: const BorderSide(color: primaryDark, width: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderDark,
        thickness: 0.5,
        space: 0,
      ),
    );
  }
}

// ─── SESSION STATE ENUM ───────────────────────────────────────────────────────
// Use this everywhere instead of raw booleans like isDrifting / isFatigued.
// It makes state-based color logic clean and consistent across all screens.

enum SessionState {
  focus,   // Normal: olive ring, cool bg
  trough,  // Fatigue warning: copper ring, warm bg shift
  drift,   // Critical: wine ring, red-tinted bg shift
}