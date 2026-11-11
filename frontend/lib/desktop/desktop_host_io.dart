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

  /// One native step. A failure is logged (dev console) and reported, never
  /// thrown: one unsupported call must not abandon the rest of the sequence.
  Future<bool> _step(String what, Future<void> Function() run) async {
    try {
      await run();
      return true;
    } catch (e) {
      debugPrint('[flow/window] $what failed: $e');
      return false;
    }
  }

  /// The pop: the window is hidden, reshaped while invisible, and shown again
  /// in its new form. Nothing half-styled is ever on screen, and Flutter gets
  /// a clean first frame at the new size.
  ///
  /// Compact modes are **frameless** (client area = the whole window). The
  /// earlier "hidden title bar + not resizable" pair left 8 px of dead,
  /// unpainted non-client area on three sides on Windows; frameless has none,
  /// and the Flutter view covers every edge, so the pill can't be resized by
  /// hand without touching the resizable flag at all.
  @override
  Future<bool> applyMode(WindowMode mode, {WidgetCorner corner = WidgetCorner.bottomRight}) async {
    final from = _mode;
    final wasCompact = from.isFloating;
    final compact = mode.isFloating;
    _mode = mode;
    _placing = true;
    var ok = true;
    try {
      if (from == WindowMode.full && mode != WindowMode.full) {
        await _step('getBounds', () async => _fullBounds = await windowManager.getBounds());
      }
      if (from == WindowMode.lock) await _step('leave full screen', () => windowManager.setFullScreen(false));

      if (compact) {
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
        final size = target.size;
        if (wasCompact) {
          // pill ↔ card: same frameless window, it just grows from its corner
          ok = await _step('resize', () => windowManager.setBounds(target));
        } else {
          await _step('hide', windowManager.hide);
          ok = await _step('frameless', windowManager.setAsFrameless);
          await _step('minimum size', () => windowManager.setMinimumSize(_miniSize));
          await _step('always on top', () => windowManager.setAlwaysOnTop(true));
          ok = await _step('place', () => windowManager.setBounds(target)) && ok;
          await _step('show', () => windowManager.show(inactive: true));
        }
        // one extra size round-trip: makes the Flutter view re-read its size
        // (some Windows setups keep the old surface after a style change)
        await _step('refresh', () async {
          await windowManager.setSize(Size(size.width + 1, size.height));
          await windowManager.setSize(size);
        });
        // did the window really take the shape? If not, say so: the
        // controller falls back to the full app instead of a broken pill.
        await _step('verify', () async {
          final got = await windowManager.getSize();
          if ((got.width - size.width).abs() > 24 || (got.height - size.height).abs() > 24) {
            debugPrint('[flow/window] asked for $size, window is $got');
            ok = false;
          }
        });
      } else if (mode == WindowMode.full) {
        if (wasCompact) await _step('hide', windowManager.hide);
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
    if (!ok) debugPrint('[flow/window] could not apply ${mode.name}');
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
