import 'package:flutter/widgets.dart';

import 'desktop_host_stub.dart' if (dart.library.io) 'desktop_host_io.dart' as impl;

/// The one window's modes (DESIGN_SPEC §3).
/// full: the app · mini: the 320×88 widget, only during a session ·
/// card: the widget grown into a nudge or detail · lock: opt-in full-screen break ·
/// nudge: a break suggestion as a centred floating window ·
/// nudgeFull: a break suggestion over the whole screen.
enum WindowMode {
  full,
  mini,
  card,
  lock,
  nudge,
  nudgeFull;

  /// The small session widget and its card.
  bool get isCompact => this == mini || this == card;

  /// A break suggestion that has taken over (floating window or whole screen).
  bool get isTakeover => this == nudge || this == nudgeFull;

  /// Frameless, always-on-top shapes: everything that pops out of the app.
  bool get isFloating => isCompact || isTakeover;
}

/// How a break suggestion reaches you. A choice per computer (it is about
/// this screen), kept with the other window preferences.
enum NudgeStyle {
  /// The suggestion takes the whole screen. The default.
  fullScreen,

  /// The same suggestion in a centred window that floats over your work.
  windowed,

  /// A small card in Flow (or the widget's card), and an OS notification
  /// when Flow is not in front.
  notification,
}

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

  /// Reshapes the window for [mode] as a pop: hidden, reshaped, shown.
  /// Returns false when the window did not take the shape (the caller then
  /// falls back to the full app rather than leave a broken widget on screen).
  Future<bool> applyMode(WindowMode mode, {WidgetCorner corner = WidgetCorner.bottomRight});

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
  Future<bool> applyMode(WindowMode mode, {WidgetCorner corner = WidgetCorner.bottomRight}) async => true;
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
