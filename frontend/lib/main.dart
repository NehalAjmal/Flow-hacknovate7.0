import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';

// Global notifier for theme mode. Defaults to Dark Mode.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() {
  runApp(const FlowApp());
}

class FlowApp extends StatelessWidget {
  const FlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'FLOW',
          debugShowCheckedModeBanner: false,
          theme: FlowTheme.lightTheme,
          darkTheme: FlowTheme.darkTheme,
          themeMode: currentMode, // Listens to the toggle!
          home: const LoginScreen(), 
        );
      },
    );
  }
}