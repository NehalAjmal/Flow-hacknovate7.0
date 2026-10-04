import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import 'dashboard_screen.dart';
import 'intent_screen.dart';
import 'active_session_screen.dart';
import 'patterns_screen.dart';
import 'admin_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  void _switchScreen(int index) => setState(() => _currentIndex = index);

  Future<void> _confirmLogout() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign out?', style: theme.textTheme.headlineSmall),
        content: Text('Your active session tracking will stop.',
            style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign out',
                style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AppState>().logout();
      // Drop any stray pushed routes so the app lands on its root, where the
      // auth-driven home swap shows the login screen.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isAdmin = appState.isAdmin;

    // SCREENS ARRAY: No 'const' on the array itself to prevent compiler crashes
    final List<Widget> screens = [
      DashboardScreen(
        key: const ValueKey('dash'),
        onViewActive: () => _switchScreen(2),
      ),
      IntentScreen(
        key: const ValueKey('intent'),
        onStartSession: () => _switchScreen(2), // session itself is started by IntentScreen
      ),
      ActiveSessionScreen(
        key: const ValueKey('active'),
        onSessionEnded: () => _switchScreen(0),
        onStartSession: () => _switchScreen(1),
      ),
      const PatternsScreen(key: ValueKey('patterns')),
      if (isAdmin) const AdminScreen(key: ValueKey('admin')),
    ];

    // ─── BULLETPROOF COLOR EXTRACTION ───
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final surfaceColor = theme.cardColor;
    final borderColor = theme.dividerColor;
    final primaryColor = theme.primaryColor;
    final primaryTint = primaryColor.withValues(alpha: isDark ? 0.1 : 0.15);
    final text3Color = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final driftColor = theme.colorScheme.error;

    // Clamp the index so it stays valid when the admin tab appears/disappears
    if (_currentIndex >= screens.length) _currentIndex = 0;

    return Scaffold(
      body: Row(
        children: [
          // ─── SIDEBAR NAVIGATION ───
          Container(
            width: 72,
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(right: BorderSide(color: borderColor, width: 1)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Logo / Home Button
                GestureDetector(
                  onTap: () => _switchScreen(0),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.blur_circular_rounded, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(height: 16),

                // Navigation Icons
                _buildNavItem(Icons.grid_view_rounded, 0, primaryColor, primaryTint, text3Color),
                _buildNavItem(Icons.adjust_rounded, 1, primaryColor, primaryTint, text3Color),
                _buildNavItem(Icons.access_time_rounded, 2, primaryColor, primaryTint, text3Color, isNotif: true, notifColor: driftColor),
                _buildNavItem(Icons.show_chart_rounded, 3, primaryColor, primaryTint, text3Color),
                if (isAdmin)
                  _buildNavItem(Icons.people_alt_rounded, 4, primaryColor, primaryTint, text3Color),

                const Spacer(),

                // Theme Toggle (Wired to AppState Provider)
                GestureDetector(
                  onTap: () => context.read<AppState>().toggleTheme(),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: primaryTint, borderRadius: BorderRadius.circular(13)),
                    child: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: primaryColor, size: 20),
                  ),
                ),
                const SizedBox(height: 8),

                // User Avatar (tap = sign out)
                GestureDetector(
                  onTap: _confirmLogout,
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
                    child: Center(
                      child: Text(
                        appState.displayName.isNotEmpty ? appState.displayName[0].toUpperCase() : 'F',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // ─── MAIN CONTENT AREA (INDEXED STACK) ───
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
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

  // ─── NAV ITEM BUILDER ───
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
            // Active Indicator Line
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
            // Notification Dot (e.g., for Active Session drift)
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
