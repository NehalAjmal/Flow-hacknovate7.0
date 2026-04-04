import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ✅ Added Provider
import 'core/theme.dart';
import 'core/app_state.dart';            // ✅ Added AppState Brain
import 'screens/main_layout.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(
    // ✅ 1. Wrap the entire app in the State Provider
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const FlowApp(),
    ),
  );
}

class FlowApp extends StatelessWidget {
  const FlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ 2. Listen to the global theme state from the Brain
    final appState = context.watch<AppState>();

    return MaterialApp(
      title: 'FLOW',
      debugShowCheckedModeBanner: false,
      theme: FlowTheme.lightTheme,
      darkTheme: FlowTheme.darkTheme,
      themeMode: appState.themeMode, // Controlled dynamically
     home: const LoginScreen(),      // Boot directly into your layout
    );
  }
}