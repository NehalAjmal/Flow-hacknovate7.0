import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart'; 
import 'core/theme.dart';
import 'screens/login_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await windowManager.ensureInitialized();

  // Changed to Normal title bar so you can minimize/close, but we will maximize it
  WindowOptions windowOptions = const WindowOptions(
    titleBarStyle: TitleBarStyle.normal, 
    center: true,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.maximize(); // Maximizes the window instead of locking it!
  });

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
          themeMode: currentMode,
          home: const LoginScreen(), 
        );
      },
    );
  }
}