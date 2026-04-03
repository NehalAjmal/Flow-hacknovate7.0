import 'package:flutter/material.dart';
import 'theme.dart';
import 'main_layout.dart';

void main() {
  runApp(const FlowApp());
}

class FlowApp extends StatefulWidget {
  const FlowApp({Key? key}) : super(key: key);

  @override
  State<FlowApp> createState() => _FlowAppState();
}

class _FlowAppState extends State<FlowApp> {
  ThemeMode _themeMode = ThemeMode.system; // Starts with system preference

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FLOW',
      debugShowCheckedModeBanner: false,
      theme: FlowTheme.lightTheme,
      darkTheme: FlowTheme.darkTheme,
      themeMode: _themeMode,
      home: MainLayout(
        currentThemeMode: _themeMode,
        onThemeModeChanged: (ThemeMode newMode) {
          setState(() {
            _themeMode = newMode;
          });
        },
      ),
    );
  }
}