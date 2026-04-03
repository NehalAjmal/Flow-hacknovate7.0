import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'dashboard_screen.dart';
import 'intent_screen.dart';
import 'active_session_screen.dart';
import 'patterns_screen.dart';
import 'team_screen.dart';

class MainLayout extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final Function(ThemeMode) onThemeModeChanged;

  const MainLayout({
    super.key,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  // ✅ FIX: replaced placeholder Text widgets with actual screen classes
  late final List<Widget> _screens = [
    const DashboardScreen(),
    IntentScreen(onStartSession: () => _switchScreen(2)),
    const ActiveSessionScreen(),
    const PatternsScreen(),
    const TeamScreen(),
  ];

  void _switchScreen(int index) => setState(() => _currentIndex = index);

  void _toggleTheme() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    widget.onThemeModeChanged(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? FlowTheme.surfaceDark : FlowTheme.surfaceLight;
    final borderColor = isDark ? FlowTheme.borderDark : FlowTheme.borderLight;
    final primaryColor = isDark ? FlowTheme.primaryDark : FlowTheme.primaryLight;
    final primaryTint = isDark ? FlowTheme.primaryTintDark : FlowTheme.primaryTintLight;
    final text3Color = isDark ? FlowTheme.text3Dark : FlowTheme.text3Light;
    final driftColor = isDark ? FlowTheme.driftDark : FlowTheme.driftLight;

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 72,
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(right: BorderSide(color: borderColor, width: 1)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _switchScreen(0),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.blur_circular_rounded, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(height: 16),
                _buildNavItem(Icons.grid_view_rounded, 0, primaryColor, primaryTint, text3Color),
                _buildNavItem(Icons.adjust_rounded, 1, primaryColor, primaryTint, text3Color),
                _buildNavItem(Icons.access_time_rounded, 2, primaryColor, primaryTint, text3Color, isNotif: true, notifColor: driftColor),
                _buildNavItem(Icons.show_chart_rounded, 3, primaryColor, primaryTint, text3Color),
                _buildNavItem(Icons.people_alt_rounded, 4, primaryColor, primaryTint, text3Color),
                const Spacer(),
                GestureDetector(
                  onTap: _toggleTheme,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: primaryTint, borderRadius: BorderRadius.circular(13)),
                    child: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: primaryColor, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, isDark ? const Color(0xFF3A6B64) : const Color(0xFF3D7A72)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor, width: 2),
                    ),
                    child: const Center(
                      child: Text("N", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, Color primaryColor, Color primaryTint, Color text3Color,
      {bool isNotif = false, Color? notifColor}) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _switchScreen(index),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: isActive ? primaryTint : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: isActive ? primaryColor : text3Color, size: 20),
            if (isActive)
              Positioned(
                left: 0,
                child: Container(
                  width: 3, height: 24,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(3), bottomRight: Radius.circular(3)),
                  ),
                ),
              ),
            if (isNotif)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: notifColor ?? Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).cardColor, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}