import 'package:flutter/material.dart';
import '../main.dart'; // To access themeNotifier
import 'dashboard_screen.dart';
import 'intent_screen.dart';
import 'patterns_screen.dart';
import 'team_screen.dart';
import 'admin_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0; 

  // We assign explicit keys so the AnimatedSwitcher knows when a screen changes
  final List<Widget> _screens = [
    const DashboardScreen(key: ValueKey('dashboard')),
    const IntentScreen(key: ValueKey('intent')),
    const PatternsScreen(key: ValueKey('patterns')),
    const TeamScreen(key: ValueKey('team')),
    const AdminScreen(key: ValueKey('admin')),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          // THE SIDEBAR
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 80,
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(right: BorderSide(color: theme.dividerColor, width: 1)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 32),
                Text("F", style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor)),
                const SizedBox(height: 48),
                
                // Navigation Icons
                _buildNavItem(Icons.grid_view_rounded, 0, "Dashboard", theme),
                const SizedBox(height: 16),
                _buildNavItem(Icons.add_rounded, 1, "New Session", theme),
                const SizedBox(height: 16),
                _buildNavItem(Icons.data_usage_rounded, 2, "Patterns", theme),
                const SizedBox(height: 16),
                _buildNavItem(Icons.people_alt_rounded, 3, "Team", theme),
                
                const Spacer(),
                
                // THEME TOGGLE BUTTON
                Tooltip(
                  message: "Toggle Theme",
                  child: IconButton(
                    icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                    color: theme.textTheme.labelSmall?.color,
                    onPressed: () {
                      themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                _buildNavItem(Icons.settings_rounded, 4, "Admin", theme),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // THE MAIN CONTENT AREA (Now completely fluid)
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.02, 0.0), // Tiny horizontal slide
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _screens[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, String tooltip, ThemeData theme) {
    final isSelected = _selectedIndex == index;

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isSelected ? Border.all(color: theme.primaryColor.withValues(alpha:0.5)) : null,
          ),
          child: Icon(
            icon,
            color: isSelected ? theme.primaryColor : theme.textTheme.labelSmall?.color,
            size: 24,
          ),
        ),
      ),
    );
  }
}