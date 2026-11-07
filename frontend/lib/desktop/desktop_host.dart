import 'package:flutter/widgets.dart';

import 'desktop_host_stub.dart' if (dart.library.io) 'desktop_host_io.dart' as impl;

/// The one window's modes (DESIGN_SPEC §3).
/// full: the app · mini: the 320×88 widget, only during a session ·
/// card: the widget grown into a nudge or detail · lock: opt-in full-screen break.
enum WindowMode { full, mini, card, lock }

/// What the tray icon (and taskbar progress) shows.
enum TrayState { idle, steady, approaching, breakDue, paused }

/// Where the widget sits; remembered.
enum WidgetCorner { topLeft, topRight, bottomLeft, bottomRight }

/// Everything Flow asks of the operating system, behind one interface so the
/// app runs unchanged on web and in tests (where [NoopDesktopHost] is used).
abstract class DesktopHost {
  /// True on Windows / macOS / Linux desktop builds.
  bool get isDesktop;

  Future<void> init({
    required VoidCallback onCloseRequested,
    required void Function(String key) onTrayAction,
    required ValueChanged<WidgetCorner> onWidgetSnapped,
  });

  /// Resizes/places the window for [mode]. The content cross-fades in Flutter;
  /// the native window changes once (spec fallback: FADE + direct resize).
  Future<void> applyMode(WindowMode mode, {WidgetCorner corner = WidgetCorner.bottomRight});

  Future<void> setTray(TrayState state, {String? tooltip, double? progress, required bool paused});

  /// OS notification (used when the window is hidden or unfocused).
  Future<void> notify(String title, String body, {VoidCallback? onClick});

  Future<bool> isFocused();
  Future<void> show();
  Future<void> hide();
  Future<void> quit();

  /// Native drag of the frameless widget; it snaps to a corner on release.
  Future<void> startDrag();
}

/// Web and tests: every call is a no-op.
class NoopDesktopHost implements DesktopHost {
  const NoopDesktopHost();
  @override
  bool get isDesktop => false;
  @override
  Future<void> init({
    required VoidCallback onCloseRequested,
    required void Function(String key) onTrayAction,
    required ValueChanged<WidgetCorner> onWidgetSnapped,
  }) async {}
  @override
  Future<void> applyMode(WindowMode mode, {WidgetCorner corner = WidgetCorner.bottomRight}) async {}
  @override
  Future<void> setTray(TrayState state, {String? tooltip, double? progress, required bool paused}) async {}
  @override
  Future<void> notify(String title, String body, {VoidCallback? onClick}) async {}
  @override
  Future<bool> isFocused() async => true;
  @override
  Future<void> show() async {}
  @override
  Future<void> hide() async {}
  @override
  Future<void> quit() async {}
  @override
  Future<void> startDrag() async {}
}

/// The host for this platform (native on desktop, no-op elsewhere).
DesktopHost createDesktopHost() => impl.createHost();

/// Call before runApp: single instance on Windows, window setup on desktop.
Future<void> prepareDesktop(List<String> args) => impl.prepare(args);
