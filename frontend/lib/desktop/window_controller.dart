import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/models/session.dart';
import '../state/account_controllers.dart';
import '../state/break_controller.dart';
import '../state/session_controller.dart';
import 'desktop_host.dart';

final desktopHostProvider = Provider<DesktopHost>((ref) => createDesktopHost());

/// Window preferences (Settings › Window). Local to this computer.
class DesktopPrefs {
  const DesktopPrefs({this.autoMini = true, this.closeToTray = true, this.corner = WidgetCorner.bottomRight});
  final bool autoMini;
  final bool closeToTray;
  final WidgetCorner corner;

  DesktopPrefs copyWith({bool? autoMini, bool? closeToTray, WidgetCorner? corner}) =>
      DesktopPrefs(autoMini: autoMini ?? this.autoMini, closeToTray: closeToTray ?? this.closeToTray, corner: corner ?? this.corner);
}

class DesktopPrefsController extends Notifier<DesktopPrefs> {
  static const _k = 'flow.desktop.';

  @override
  DesktopPrefs build() {
    unawaited(_load());
    return const DesktopPrefs();
  }

  Future<void> _load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      state = DesktopPrefs(
        autoMini: sp.getBool('${_k}autoMini') ?? true,
        closeToTray: sp.getBool('${_k}closeToTray') ?? true,
        corner: WidgetCorner.values.asNameMap()[sp.getString('${_k}corner')] ?? WidgetCorner.bottomRight,
      );
    } catch (_) {
      // no storage (tests, private web): defaults are fine
    }
  }

  Future<void> set(DesktopPrefs next) async {
    state = next;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool('${_k}autoMini', next.autoMini);
      await sp.setBool('${_k}closeToTray', next.closeToTray);
      await sp.setString('${_k}corner', next.corner.name);
    } catch (_) {}
  }
}

final desktopPrefsProvider = NotifierProvider<DesktopPrefsController, DesktopPrefs>(DesktopPrefsController.new);

/// The window state model (DESIGN_SPEC §3, D6):
/// - mini exists only during a session (auto on start if enabled; Shrink
///   otherwise); no session → nothing to shrink to.
/// - a nudge while mini grows the widget into a card; it collapses back after
///   60 s (the amber dot stays) or when answered.
/// - an opt-in lock break takes the whole screen, then returns where it was.
/// - the session ending while mini grows back into the full app.
/// - closing keeps Flow in the tray; hidden or unfocused nudges become OS
///   notifications.
class WindowModeController extends Notifier<WindowMode> {
  static const cardHold = Duration(seconds: 60);

  Timer? _collapse;
  WindowMode _beforeLock = WindowMode.full;
  bool _hidden = false;

  DesktopHost get _host => ref.read(desktopHostProvider);
  bool get hidden => _hidden;

  @override
  WindowMode build() {
    final host = ref.watch(desktopHostProvider);
    ref.onDispose(() => _collapse?.cancel());
    unawaited(
      host.init(
        onCloseRequested: onCloseRequested,
        onTrayAction: onTrayAction,
        onWidgetSnapped: (c) => ref.read(desktopPrefsProvider.notifier).set(ref.read(desktopPrefsProvider).copyWith(corner: c)),
      ),
    );

    ref.listen(liveSessionProvider, (prev, next) => _onSession(prev?.value, next.value));
    ref.listen(breakProvider, (prev, next) {
      if (prev == null && next != null && next.lock) {
        _beforeLock = state;
        _go(WindowMode.lock);
      } else if (prev != null && next == null && state == WindowMode.lock) {
        final live = ref.read(liveSessionProvider).value != null;
        _go(live && _beforeLock != WindowMode.full ? WindowMode.mini : WindowMode.full);
      }
    });
    ref.listen(pauseProvider, (_, _) => _updateTray(ref.read(liveSessionProvider).value));
    return WindowMode.full;
  }

  void _onSession(LiveSession? prev, LiveSession? next) {
    // started
    if (prev == null && next != null) {
      if (ref.read(desktopPrefsProvider).autoMini && _host.isDesktop) _go(WindowMode.mini);
    }
    // ended: grow back into the full app (the summary opens there)
    if (prev != null && next == null && (state == WindowMode.mini || state == WindowMode.card)) _go(WindowMode.full);

    // a nudge arrived
    final had = prev?.pendingInterventionId;
    final has = next?.pendingInterventionId;
    if (has != null && has != had) {
      if (state == WindowMode.mini) openCard();
      unawaited(_maybeNotify(next!));
    }
    // answered while the card is open → back to the widget
    if (has == null && had != null && state == WindowMode.card) _go(WindowMode.mini);

    _updateTray(next);
  }

  Future<void> _maybeNotify(LiveSession s) async {
    if (!_host.isDesktop) return;
    // The card on top already is the nudge in widget mode; notify only when
    // the window is hidden, or the full app sits unfocused behind other work.
    if (state == WindowMode.card || state == WindowMode.mini || state == WindowMode.lock) {
      if (!_hidden) return;
    } else if (!_hidden && await _host.isFocused()) {
      return;
    }
    await _host.notify(
      'Time for a short break?',
      'Flow noticed your focus is running down. Open Flow to see why.',
      onClick: () {
        _hidden = false;
        _host.show();
        if (state == WindowMode.mini) openCard();
      },
    );
  }

  void _updateTray(LiveSession? s) {
    final paused = ref.read(pauseProvider).value?.paused ?? false;
    final TrayState t;
    if (paused || (s?.session.paused ?? false)) {
      t = TrayState.paused;
    } else if (s == null) {
      t = TrayState.idle;
    } else {
      t = switch (s.session.state) {
        FlowState.approachingBreak => TrayState.approaching,
        FlowState.breakDue => TrayState.breakDue,
        FlowState.paused => TrayState.paused,
        _ => s.pendingInterventionId != null ? TrayState.breakDue : TrayState.steady,
      };
    }
    double? progress;
    String tip = 'Flow';
    if (s != null) {
      final elapsed = s.session.elapsedAt(DateTime.now());
      progress = (elapsed.inSeconds / (s.session.plannedMinutes * 60)).clamp(0.0, 1.0);
      tip = 'Flow · ${elapsed.inMinutes} of ${s.session.plannedMinutes} min · ${t.name}';
    }
    unawaited(_host.setTray(t, tooltip: tip, progress: progress, paused: paused));
  }

  void _go(WindowMode m) {
    if (m != WindowMode.card) _collapse?.cancel();
    if (m == state) return;
    state = m;
    unawaited(_host.applyMode(m, corner: ref.read(desktopPrefsProvider).corner));
  }

  /// Shrink to the widget: only while a session runs.
  void shrink() {
    if (ref.read(liveSessionProvider).value == null) return;
    _go(WindowMode.mini);
  }

  void expand() => _go(WindowMode.full);

  /// Dev panel only: preview a compact view in a browser (no native window).
  void debugPreview(WindowMode m) => state = m;

  void openCard() {
    if (ref.read(liveSessionProvider).value == null) return;
    _go(WindowMode.card);
    _collapse?.cancel();
    _collapse = Timer(cardHold, collapseCard);
  }

  void collapseCard() {
    if (state == WindowMode.card) _go(WindowMode.mini);
  }

  void onCloseRequested() {
    if (ref.read(desktopPrefsProvider).closeToTray) {
      _hidden = true;
      unawaited(_host.hide());
    } else {
      unawaited(_host.quit());
    }
  }

  void onTrayAction(String key) {
    switch (key) {
      case 'show':
        // "Show Flow" always means the full app: it's also the way out of
        // the widget if it ever misbehaves.
        _hidden = false;
        unawaited(_host.show());
        expand();
      case 'pause_1h':
        unawaited(ref.read(pauseProvider.notifier).pauseFor(60));
      case 'resume':
        unawaited(ref.read(pauseProvider.notifier).resume());
      case 'quit':
        unawaited(_host.quit());
    }
  }
}

final windowModeProvider = NotifierProvider<WindowModeController, WindowMode>(WindowModeController.new);
