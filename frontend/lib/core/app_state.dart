import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  // ─── GLOBAL THEME MANAGEMENT ───
  ThemeMode _themeMode = ThemeMode.dark; 
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners(); 
  }

  // ─── LIVE TELEMETRY ───
  int currentBpm = 74;
  double currentEar = 0.31;
  int focusScore = 82;
  String currentTask = "Debugging auth module";
  
  String? activeSessionId;
  bool isDrifting = false;

  // Resets the screen to Green when a new session starts
  void startSession(String? id) {
    activeSessionId = id;
    isDrifting = false;
    notifyListeners();
  }

  void setActiveSession(String? id) {
    activeSessionId = id;
    notifyListeners();
  }

  // For your FAB button
  void toggleDrift() {
    isDrifting = !isDrifting;
    notifyListeners();
  }

  // For the Python Backend later
  void updateTelemetry({required int bpm, required double ear, required bool drift}) {
    currentBpm = bpm;
    currentEar = ear;
    isDrifting = drift;
    notifyListeners();
  }
}