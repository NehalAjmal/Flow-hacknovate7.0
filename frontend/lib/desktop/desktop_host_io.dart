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

  Offset _cornerPos(Rect area, Size s, WidgetCorner c) => switch (c) {
    WidgetCorner.topLeft => area.topLeft + const Offset(_margin, _margin),
    WidgetCorner.topRight => Offset(area.right - s.width - _margin, area.top + _margin),
    WidgetCorner.bottomLeft => Offset(area.left + _margin, area.bottom - s.height - _margin),
    WidgetCorner.bottomRight => Offset(area.right - s.width - _margin, area.bottom - s.height - _margin),
  };

  @override
  Future<void> applyMode(WindowMode mode, {WidgetCorner corner = WidgetCorner.bottomRight}) async {
    final from = _mode;
    _mode = mode;
    _placing = true;
    try {
      if (from == WindowMode.full && mode != WindowMode.full) _fullBounds = await windowManager.getBounds();
      if (from == WindowMode.lock) await windowManager.setFullScreen(false);
      switch (mode) {
        case WindowMode.full:
          await windowManager.setAlwaysOnTop(false);
          await windowManager.setTitleBarStyle(TitleBarStyle.normal);
          await windowManager.setResizable(true);
          await windowManager.setMinimumSize(const Size(960, 640));
          final b = _fullBounds;
          if (b != null) {
            await windowManager.setBounds(b, animate: true);
          } else {
            await windowManager.setSize(const Size(1280, 820), animate: true);
            await windowManager.center();
          }
        case WindowMode.mini:
        case WindowMode.card:
          final size = mode == WindowMode.mini ? _miniSize : _cardSize;
          await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
          await windowManager.setMinimumSize(size);
          await windowManager.setResizable(false);
          await windowManager.setAlwaysOnTop(true);
          final area = await _workArea();
          await windowManager.setBounds(_cornerPos(area, size, corner) & size, animate: true);
        case WindowMode.lock:
          await windowManager.setAlwaysOnTop(true);
          await windowManager.setFullScreen(true);
      }
      if (!await windowManager.isVisible()) await windowManager.show(inactive: mode != WindowMode.full);
    } finally {
      _placing = false;
    }
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
    if (_placing || (_mode != WindowMode.mini && _mode != WindowMode.card)) return;
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
