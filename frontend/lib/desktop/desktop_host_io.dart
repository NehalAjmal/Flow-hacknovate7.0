import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import 'desktop_host.dart';

bool get _desktop => (Platform.isWindows || Platform.isMacOS || Platform.isLinux) && !Platform.environment.containsKey('FLUTTER_TEST');

DesktopHost createHost() => _desktop ? NativeDesktopHost() : const NoopDesktopHost();

Future<void> prepare(List<String> args) async {
  if (!_desktop) return;
  WidgetsFlutterBinding.ensureInitialized();
  // Windows: a second launch focuses the running Flow instead (macOS does
  // this natively; on Linux the tray icon is the single entry point).
  await WindowsSingleInstance.ensureSingleInstance(args, 'flow_single_instance');
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(size: Size(1280, 820), minimumSize: Size(960, 640), center: true, title: 'Flow'),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
  try {
    await localNotifier.setup(appName: 'Flow');
  } catch (_) {}
}

/// window_manager + tray_manager + local_notifier.
class NativeDesktopHost with WindowListener, TrayListener implements DesktopHost {
  static const _miniSize = Size(320, 88);
  static const _cardSize = Size(380, 320);
  static const _nudgeSize = Size(760, 480);
  static const _margin = 16.0;

  VoidCallback? _onClose;
  void Function(String key)? _onTray;
  ValueChanged<WidgetCorner>? _onSnapped;
  WindowMode _mode = WindowMode.full;
  Rect? _fullBounds;
  bool _wasMaximized = false;
  bool _placing = false;
  Timer? _snapDebounce;
  TrayState? _trayState;

  @override
  bool get isDesktop => true;

  @override
  Future<void> init({
    required VoidCallback onCloseRequested,
    required void Function(String key) onTrayAction,
    required ValueChanged<WidgetCorner> onWidgetSnapped,
  }) async {
    _onClose = onCloseRequested;
    _onTray = onTrayAction;
    _onSnapped = onWidgetSnapped;
    windowManager.addListener(this);
    trayManager.addListener(this);
    // closing keeps Flow in the tray; Quit lives in the tray menu
    await windowManager.setPreventClose(true);
    await _setTrayMenu(paused: false);
  }

  Future<void> _setTrayMenu({required bool paused}) => trayManager.setContextMenu(
    Menu(
      items: [
        MenuItem(key: 'show', label: 'Show Flow'),
        MenuItem.separator(),
        if (paused) MenuItem(key: 'resume', label: 'Resume Flow') else MenuItem(key: 'pause_1h', label: 'Pause for 1 hour'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Quit Flow'),
      ],
    ),
  );

  Future<Rect> _workArea() async {
    final d = await screenRetriever.getPrimaryDisplay();
    final pos = d.visiblePosition ?? Offset.zero;
    final size = d.visibleSize ?? d.size;
    return pos & size;
  }

  /// The primary display's full rectangle.
  Future<Rect> _display() async {
    final d = await screenRetriever.getPrimaryDisplay();
    return Offset.zero & d.size;
  }

  Offset _cornerPos(Rect area, Size s, WidgetCorner c) => switch (c) {
    WidgetCorner.topLeft => area.topLeft + const Offset(_margin, _margin),
    WidgetCorner.topRight => Offset(area.right - s.width - _margin, area.top + _margin),
    WidgetCorner.bottomLeft => Offset(area.left + _margin, area.bottom - s.height - _margin),
    WidgetCorner.bottomRight => Offset(area.right - s.width - _margin, area.bottom - s.height - _margin),
  };

  /// Dev builds only (`--dart-define=FLOW_DEV=true`): what the window did,
  /// one line per event, prefixed so it is easy to find and paste.
  static void _log(String m) {
    if (const bool.fromEnvironment('FLOW_DEV')) debugPrint('[flow/window] $m');
  }

  /// One native step. A failure is logged (dev console) and reported, never
  /// thrown: one unsupported call must not abandon the rest of the sequence.
  Future<bool> _step(String what, Future<void> Function() run) async {
    try {
      await run();
      return true;
    } catch (e) {
      _log('$what failed: $e');
      return false;
    }
  }

  /// Windows applies a restore-from-maximized asynchronously: a resize sent
  /// before it lands is undone by it, leaving the pill's content stretched
  /// across a full-size window. So wait until the window really is normal.
  Future<void> _leaveMaximized() async {
    var maximized = false, minimized = false;
    await _step('read state', () async {
      maximized = await windowManager.isMaximized();
      minimized = await windowManager.isMinimized();
    });
    if (minimized) await _step('restore', windowManager.restore);
    if (maximized) {
      _wasMaximized = true;
      await _step('unmaximize', windowManager.unmaximize);
    }
    if (!maximized && !minimized) return;
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      var still = false;
      await _step('read state', () async => still = await windowManager.isMaximized() || await windowManager.isMinimized());
      if (!still) break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 60)); // let the restore's own resize finish
  }

  /// Sets [target] and confirms the window took it; retries once (a late
  /// restore or DPI change can undo the first). False = it would not.
  Future<bool> _place(Rect target) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (!await _step('place', () => windowManager.setBounds(target))) return false;
      await Future<void>.delayed(const Duration(milliseconds: 90));
      Size? got;
      await _step('verify', () async => got = await windowManager.getSize());
      if (got == null) return true; // cannot read it back: trust the call
      if ((got!.width - target.width).abs() <= 24 && (got!.height - target.height).abs() <= 24) return true;
      _log('asked for ${target.size}, window is $got (attempt ${attempt + 1})');
    }
    return false;
  }

  /// Flutter may not draw after a native reshape until the next input event
  /// (the window looked empty until clicked). Ask for frames explicitly, now
  /// and again once the OS has settled.
  void _wake() {
    void frame() => WidgetsBinding.instance.scheduleForcedFrame();
    frame();
    for (final ms in const [60, 180, 450]) {
      Timer(Duration(milliseconds: ms), frame);
    }
  }

  /// Reshapes the one window. It stays visible throughout: hiding it makes
  /// Flutter stop drawing (lifecycle "hidden") and it did not reliably start
  /// again when shown without focus.
  ///
  /// Floating shapes (pill, card, nudge window, nudge over the whole screen)
  /// are **frameless**: the client area is the whole window, so there are no
  /// dead strips (the "hidden title bar + not resizable" pair left 8 px of
  /// unpainted non-client area on three sides on Windows).
  @override
  Future<bool> applyMode(WindowMode mode, {WidgetCorner corner = WidgetCorner.bottomRight}) async {
    final from = _mode;
    final wasFloating = from.isFloating;
    _mode = mode;
    _placing = true;
    var ok = true;
    try {
      if (from == WindowMode.lock) await _step('leave full screen', () => windowManager.setFullScreen(false));

      if (mode.isFloating) {
        if (!wasFloating) {
          await _leaveMaximized();
          await _step('getBounds', () async => _fullBounds = await windowManager.getBounds());
        }
        final area = await _workArea();
        final Rect target;
        if (mode == WindowMode.nudgeFull) {
          // the whole display, taskbar included (not the OS "full screen"
          // state: no Space switch on macOS, and it leaves like any pop-out)
          target = await _display();
        } else if (mode == WindowMode.nudge) {
          final s = Size(_nudgeSize.width.clamp(320.0, area.width - 32), _nudgeSize.height.clamp(240.0, area.height - 32));
          target = Rect.fromCenter(center: area.center, width: s.width, height: s.height);
        } else {
          final s = mode == WindowMode.mini ? _miniSize : _cardSize;
          target = _cornerPos(area, s, corner) & s;
        }
        if (!wasFloating) {
          ok = await _step('frameless', windowManager.setAsFrameless);
          await _step('minimum size', () => windowManager.setMinimumSize(_miniSize));
          await _step('always on top', () => windowManager.setAlwaysOnTop(true));
        }
        ok = await _place(target) && ok;
        // in the tray (or behind everything) when a nudge takes over: bring it up
        var visible = true;
        await _step('visible?', () async => visible = await windowManager.isVisible());
        if (!visible || mode.isTakeover) {
          await _step('show', () async {
            await windowManager.show();
            await windowManager.focus();
          });
        }
      } else if (mode == WindowMode.full) {
        await _step('normal frame', () => windowManager.setTitleBarStyle(TitleBarStyle.normal));
        await _step('always on top off', () => windowManager.setAlwaysOnTop(false));
        await _step('minimum size', () => windowManager.setMinimumSize(const Size(960, 640)));
        final b = _fullBounds;
        ok = await _step('place', () async {
          if (b != null) {
            await windowManager.setBounds(b);
          } else {
            await windowManager.setSize(const Size(1280, 820));
            await windowManager.center();
          }
        });
        if (_wasMaximized) {
          _wasMaximized = false;
          await _step('maximize again', windowManager.maximize);
        }
        await _step('show', () async {
          await windowManager.show();
          await windowManager.focus();
        });
      } else {
        // lock: the opt-in full-screen break
        await _step('always on top', () => windowManager.setAlwaysOnTop(true));
        ok = await _step('full screen', () => windowManager.setFullScreen(true));
        await _step('show', windowManager.show);
      }
    } finally {
      _placing = false;
    }
    _wake();
    Rect? now;
    await _step('read back', () async => now = await windowManager.getBounds());
    _log(
      '${from.name} → ${mode.name}: ${ok ? 'ok' : 'FAILED'}, window is now ${now == null ? 'unknown' : '${now!.width.round()}×${now!.height.round()} at ${now!.left.round()},${now!.top.round()}'}',
    );
    return ok;
  }

  @override
  Future<void> setTray(TrayState state, {String? tooltip, double? progress, required bool paused}) async {
    if (state != _trayState) {
      _trayState = state;
      final name = state.name;
      await trayManager.setIcon(Platform.isWindows ? 'assets/tray/$name.ico' : 'assets/tray/$name.png');
      await _setTrayMenu(paused: paused);
    }
    if (tooltip != null && !Platform.isLinux) await trayManager.setToolTip(tooltip);
    // taskbar progress (Windows) mirrors the session; -1 clears it
    if (Platform.isWindows) await windowManager.setProgressBar(progress ?? -1);
  }

  @override
  Future<void> notify(String title, String body, {VoidCallback? onClick}) async {
    final n = LocalNotification(title: title, body: body);
    n.onClick = onClick;
    await n.show();
  }

  @override
  Future<bool> isFocused() => windowManager.isFocused();
  @override
  Future<void> show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> hide() => windowManager.hide();

  @override
  Future<void> quit() async {
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  Future<void> startDrag() => windowManager.startDragging();

  // ── listeners ──
  @override
  void onWindowClose() => _onClose?.call();

  /// Released after a drag: snap to the nearest corner (SNAP-like eased move).
  @override
  void onWindowMoved() {
    if (_placing || !_mode.isCompact) return;
    _snapDebounce?.cancel();
    _snapDebounce = Timer(const Duration(milliseconds: 120), () async {
      final b = await windowManager.getBounds();
      final area = await _workArea();
      final c = b.center;
      final corner = switch ((c.dx < area.center.dx, c.dy < area.center.dy)) {
        (true, true) => WidgetCorner.topLeft,
        (false, true) => WidgetCorner.topRight,
        (true, false) => WidgetCorner.bottomLeft,
        (false, false) => WidgetCorner.bottomRight,
      };
      _placing = true;
      await windowManager.setPosition(_cornerPos(area, b.size, corner), animate: true);
      _placing = false;
      _onSnapped?.call(corner);
    });
  }

  @override
  void onTrayIconMouseDown() => _onTray?.call('show');
  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();
  @override
  void onTrayMenuItemClick(MenuItem menuItem) => _onTray?.call(menuItem.key ?? '');
}
