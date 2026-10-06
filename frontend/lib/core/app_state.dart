import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_service.dart';

/// Global app brain: theme, auth identity, and the single source of truth
/// for the active focus session.
class AppState extends ChangeNotifier {
  // ─── THEME ───
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  // ─── AUTH ───
  bool bootstrapped = false;
  String? userId;
  String? userRole;
  String? userName;
  String? userEmail;
  bool onboardingDone = true;

  bool get isLoggedIn => userId != null;
  bool get isAdmin => userRole == 'admin';
  bool get needsOnboarding => isLoggedIn && !onboardingDone;

  /// Best display name: stored name, else the part before the email.
  /// Callers should treat an empty result as "unknown user".
  String get displayName {
    if (userName != null && userName!.trim().isNotEmpty) return userName!.trim();
    if (userEmail != null && userEmail!.contains('@')) return userEmail!.split('@').first;
    return '';
  }

  // ─── ACTIVE SESSION (single source of truth) ───
  String? activeSessionId;
  String? sessionTask;
  String? sessionIntent;
  bool isDrifting = false;

  // ─── LIVE TELEMETRY ───
  int currentBpm = 0;
  double currentEar = 0;
  int focusScore = 0;

  /// Load persisted auth + active session from storage. Call once at boot.
  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      userId = prefs.getString('user_id') ?? 'stored';
      userRole = prefs.getString('user_role');
      userName = prefs.getString('user_name');
      userEmail = prefs.getString('user_email');
      activeSessionId = prefs.getString('active_session_id');

      // Drop a stale session pointer if the backend no longer knows it
      if (activeSessionId != null) {
        try {
          await ApiService.status(activeSessionId!);
        } on ApiException catch (e) {
          if (e.isNotFound) {
            activeSessionId = null;
            await prefs.remove('active_session_id');
          }
        } catch (_) {
          // Backend unreachable — keep the pointer, it may just be offline
        }
      }
    }
    onboardingDone = prefs.getBool('onboarding_complete') ?? false;

    bootstrapped = true;
    notifyListeners();
  }

  /// Marks the first-login walkthrough as seen on this device.
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    onboardingDone = true;
    notifyListeners();
  }

  Future<void> setAuth({
    required String token,
    required String id,
    required String role,
    String? name,
    String? email,
  }) async {
    await SessionStore.saveAuth(token: token, userId: id, role: role, fullName: name, email: email);
    userId = id;
    userRole = role;
    userName = name ?? userName;
    userEmail = email ?? userEmail;
    notifyListeners();
  }

  Future<void> logout() async {
    await SessionStore.clear();
    userId = null;
    userRole = null;
    userName = null;
    userEmail = null;
    activeSessionId = null;
    sessionTask = null;
    sessionIntent = null;
    isDrifting = false;
    notifyListeners();
  }

  // ─── SESSION LIFECYCLE ───

  /// Register a newly created backend session.
  void startSession(String sessionId, {String? task, String? intent}) {
    activeSessionId = sessionId;
    sessionTask = task ?? sessionTask;
    sessionIntent = intent ?? sessionIntent;
    isDrifting = false;
    focusScore = 0;
    SharedPreferences.getInstance().then((p) => p.setString('active_session_id', sessionId));
    notifyListeners();
  }

  /// Clear session state locally (after the backend confirmed the end).
  Future<void> endSession() async {
    activeSessionId = null;
    sessionTask = null;
    sessionIntent = null;
    isDrifting = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_session_id');
    notifyListeners();
  }

  void toggleDrift() {
    isDrifting = !isDrifting;
    notifyListeners();
  }

  void updateTelemetry({
    required int bpm,
    required double ear,
    required bool drift,
    int? score,
  }) {
    currentBpm = bpm;
    currentEar = ear;
    isDrifting = drift;
    if (score != null) focusScore = score;
    notifyListeners();
  }
}
