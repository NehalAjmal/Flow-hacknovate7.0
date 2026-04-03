import 'package:flutter/material.dart';
import 'main_layout.dart';

/// AppShell wraps MainLayout and manages its own ThemeMode state.
/// Used by LoginScreen and SessionEndScreen to navigate back to the main app
/// without needing to pass ThemeMode callbacks through navigation.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentThemeMode: _themeMode,
      onThemeModeChanged: (ThemeMode newMode) {
        setState(() {
          _themeMode = newMode;
        });
      },
    );
  }
}