import 'package:flutter/material.dart';
import 'theme.dart'; // Make sure this points to your new theme.dart file

// Placeholder imports - we will build these next!
// import 'dashboard_screen.dart';
// import 'intent_screen.dart';
// import 'active_session_screen.dart';
// import 'patterns_screen.dart';
// import 'team_screen.dart';

class MainLayout extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final Function(ThemeMode) onThemeModeChanged;

  const MainLayout({
    Key? key,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
  }) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  // The IndexedStack preserves the state of these screens. 
  // If a session timer is running in the ActiveSessionScreen, 
  // it won't reset when you click over to the Dashboard.
  final List<Widget> _screens = [
    const Center(child: Text("Dashboard Screen", style: TextStyle(fontSize: 24))), // Index 0
    const Center(child: Text("Intent Screen", style: TextStyle(fontSize: 24))),    // Index 1
    const Center(child: Text("Active Session", style: TextStyle(fontSize: 24))),   // Index 2
    const Center(child: Text("Patterns Screen", style: TextStyle(fontSize: 24))),  // Index 3
    const Center(child: Text("Team Screen", style: TextStyle(fontSize: 24))),      // Index 4
  ];

  void _switchScreen(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _toggleTheme() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    widget.onThemeModeChanged(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Pulling exact colors from your new FlowTheme
    final surfaceColor = isDark ? FlowTheme.surfaceDark : FlowTheme.surfaceLight;
    final borderColor = isDark ? FlowTheme.borderDark : FlowTheme.borderLight;
    final primaryColor = isDark ? FlowTheme.primaryDark : FlowTheme.primaryLight;
    final primaryTint = isDark ? FlowTheme.primaryTintDark : FlowTheme.primaryTintLight;
    final text3Color = isDark ? FlowTheme.text3Dark : FlowTheme.text3Light;
    final driftColor = isDark ? FlowTheme.driftDark : FlowTheme.driftLight;

    return Scaffold(
      body: Row(
        children: [
          // ─── SIDEBAR ───────────────────────────────────
          Container(
            width: 72,
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(right: BorderSide(color: borderColor, width: 1)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Top Logo (Routes to Dashboard)
                GestureDetector(
                  onTap: () => _switchScreen(0),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    // Using a native icon close to the HTML SVG design
                    child: const Icon(Icons.blur_circular_rounded, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Navigation Items
                _buildNavItem(Icons.grid_view_rounded, 0, primaryColor, primaryTint, text3Color),
                _buildNavItem(Icons.adjust_rounded, 1, primaryColor, primaryTint, text3Color),
                _buildNavItem(Icons.access_time_rounded, 2, primaryColor, primaryTint, text3Color, 
                  isNotif: true, notifColor: driftColor), // Session has the red dot!
                _buildNavItem(Icons.show_chart_rounded, 3, primaryColor, primaryTint, text3Color),
                _buildNavItem(Icons.people_alt_rounded, 4, primaryColor, primaryTint, text3Color),
                
                const Spacer(),
                
                // Theme Toggle
                GestureDetector(
                  onTap: _toggleTheme,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primaryTint,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // User Avatar (Nehal)
                GestureDetector(
                  onTap: () {
                    // Could route to a settings modal or profile screen
                  },
                  child: Container(
                    width: 36,
                    height: 36,
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
                      child: Text(
                        "N",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // ─── MAIN CONTENT ───────────────────────────────
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }

  // ─── NAV ITEM BUILDER ─────────────────────────────────
  Widget _buildNavItem(IconData icon, int index, Color primaryColor, Color primaryTint, Color text3Color, {bool isNotif = false, Color? notifColor}) {
    final isActive = _currentIndex == index;
    
    return GestureDetector(
      onTap: () => _switchScreen(index),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive ? primaryTint : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? primaryColor : text3Color,
              size: 20,
            ),
            
            // The active state vertical indicator line
            if (isActive)
              Positioned(
                left: 0,
                child: Container(
                  width: 3,
                  height: 24,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(3),
                      bottomRight: Radius.circular(3),
                    ),
                  ),
                ),
              ),
              
            // The notification badge (used for active session indicator)
            if (isNotif)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 7,
                  height: 7,
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