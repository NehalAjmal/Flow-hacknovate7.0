import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart'; // Ensure this path matches where you saved the file

void main() {
  runApp(const FlowApp());
}

class FlowApp extends StatelessWidget {
  const FlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FLOW Cognitive Alignment',
      debugShowCheckedModeBanner: false, // Hides the debug banner
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1D9E75), // FLOW Green
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      home: const LoginScreen(), // This points to your new login page
    );
  }
}