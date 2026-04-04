import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import 'dashboard_screen.dart';
import 'intent_screen.dart';
import 'active_session_screen.dart';
import 'patterns_screen.dart';
import 'team_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  void _switchScreen(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    // SCREENS ARRAY
   // SCREENS ARRAY
    final List<Widget> screens = [
      const DashboardScreen(key: ValueKey('dash')),
      
      // ─── UPDATE THIS LINE ───
      IntentScreen(
        key: const ValueKey('intent'), 
        onStartSession: () {
          context.read<AppState>().startSession(); // Forces the red screen to clear!
          _switchScreen(2);
        }
      ),
      // ───────────────────────
      const ActiveSessionScreen(key: ValueKey('active')),
      const PatternsScreen(key: ValueKey('patterns')),
      const TeamScreen(key: ValueKey('team')),
    ];

    // ─── BULLETPROOF COLOR EXTRACTION ───
    // We extract directly from the active theme to avoid "undefined" errors
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final surfaceColor = theme.cardColor;
    final borderColor = theme.dividerColor;
    final primaryColor = theme.primaryColor;
    final primaryTint = primaryColor.withValues(alpha: isDark ? 0.1 : 0.15);
    final text3Color = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final driftColor = theme.colorScheme.error;

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
                
                // WIRED TO PROVIDER FOR GLOBAL THEME TOGGLE
                GestureDetector(
                  onTap: () => context.read<AppState>().toggleTheme(),
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
          // ─── THE CRASH-PROOF INDEXED STACK ───
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              // TickerMode freezes the animations (like the pulsing ring) 
              // on screens that are currently hidden in the background!
              children: screens.asMap().entries.map((entry) {
                return TickerMode(
                  enabled: _currentIndex == entry.key,
                  child: entry.value,
                );
              }).toList(),
            ),
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