import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'core/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout.dart';
import 'screens/onboarding_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const FlowApp(),
    ),
  );
}

class FlowApp extends StatefulWidget {
  const FlowApp({super.key});

  @override
  State<FlowApp> createState() => _FlowAppState();
}

class _FlowAppState extends State<FlowApp> {
  @override
  void initState() {
    super.initState();
    // Restore persisted auth (auto-login) before showing the first screen.
    context.read<AppState>().bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return MaterialApp(
      title: 'FLOW',
      debugShowCheckedModeBanner: false,
      theme: FlowTheme.lightTheme,
      darkTheme: FlowTheme.darkTheme,
      themeMode: appState.themeMode,
      home: !appState.bootstrapped
          ? const _BootSplash()
          : (!appState.isLoggedIn
              ? const LoginScreen()
              : (appState.needsOnboarding ? const OnboardingScreen() : const MainLayout())),
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Text('F',
                  style: TextStyle(
                      color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
