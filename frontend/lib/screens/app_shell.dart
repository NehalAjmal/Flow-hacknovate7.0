import 'package:flutter/material.dart';
import 'main_layout.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    // MainLayout now manages its own state via Provider!
    return const MainLayout();
  }
}