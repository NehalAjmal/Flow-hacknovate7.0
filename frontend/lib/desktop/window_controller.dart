import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
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
  const DesktopPrefs({
    this.autoMini = false,
    this.closeToTray = true,
    this.corner = WidgetCorner.bottomRight,
    this.nudgeStyle = NudgeStyle.fullScreen,
    this.appearance = Appearance.system,
    this.lightFrom = 7 * 60,
    this.lightTo = 19 * 60,
  });

  /// Light, dark, this computer's setting, or by time of day.
  final Appearance appearance;

  /// [Appearance.schedule]: Flow is light from [lightFrom] to [lightTo]
  /// (minutes after midnight, local time) and dark for the rest of the day.
  final int lightFrom;
  final int lightTo;

  /// How a break suggestion reaches you on this computer.
  final NudgeStyle nudgeStyle;
  final bool autoMini;
  final bool closeToTray;
  final WidgetCorner corner;

  DesktopPrefs copyWith({
    bool? autoMini,
    bool? closeToTray,
    WidgetCorner? corner,
    NudgeStyle? nudgeStyle,
    Appearance? appearance,
    int? lightFrom,
    int? lightTo,
  }) => DesktopPrefs(
    autoMini: autoMini ?? this.autoMini,
    closeToTray: closeToTray ?? this.closeToTray,
    corner: corner ?? this.corner,
    nudgeStyle: nudgeStyle ?? this.nudgeStyle,
    appearance: appearance ?? this.appearance,
    lightFrom: lightFrom ?? this.lightFrom,
    lightTo: lightTo ?? this.lightTo,
  );

  /// Is Flow light at [minuteOfDay] under the time-of-day schedule? The light
  /// span may cross midnight (e.g. 22:00 → 06:00 for a night shift).
  bool lightAt(int minuteOfDay) =>
      lightFrom <= lightTo ? minuteOfDay >= lightFrom && minuteOfDay < lightTo : minuteOfDay >= lightFrom || minuteOfDay < lightTo;
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
      // a choice made while the stored ones were still loading wins
      if (!ref.mounted || _changed) return;
      state = DesktopPrefs(
        autoMini: sp.getBool('${_k}autoMini') ?? false,
        closeToTray: sp.getBool('${_k}closeToTray') ?? true,
        corner: WidgetCorner.values.asNameMap()[sp.getString('${_k}corner')] ?? WidgetCorner.bottomRight,
        nudgeStyle: NudgeStyle.values.asNameMap()[sp.getString('${_k}nudgeStyle')] ?? NudgeStyle.fullScreen,
        appearance: Appearance.values.asNameMap()[sp.getString('${_k}appearance')] ?? Appearance.system,
        lightFrom: (sp.getInt('${_k}lightFrom') ?? 7 * 60).clamp(0, 24 * 60 - 1),
        lightTo: (sp.getInt('${_k}lightTo') ?? 19 * 60).clamp(0, 24 * 60),
      );
    } catch (_) {
      // no storage (tests, private web): defaults are fine
    }
  }

  bool _changed = false;

  Future<void> set(DesktopPrefs next) async {
    _changed = true;
    state = next;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool('${_k}autoMini', next.autoMini);
      await sp.setBool('${_k}closeToTray', next.closeToTray);
      await sp.setString('${_k}corner', next.corner.name);
      await sp.setString('${_k}nudgeStyle', next.nudgeStyle.name);
      await sp.setString('${_k}appearance', next.appearance.name);
      await sp.setInt('${_k}lightFrom', next.lightFrom);
      await sp.setInt('${_k}lightTo', next.lightTo);
    } catch (_) {}
  }
}

final desktopPrefsProvider = NotifierProvider<DesktopPrefsController, DesktopPrefs>(DesktopPrefsController.new);

/// The minute of the day, refreshed twice a minute. Only alive while the
/// time-of-day appearance is in use.
final _minuteOfDayProvider = StreamProvider.autoDispose<int>((ref) async* {
  int now() {
    final t = DateTime.now();
    return t.hour * 60 + t.minute;
  }

  yield now();
  yield* Stream<int>.periodic(const Duration(seconds: 30), (_) => now()).distinct();
});

/// The theme Flow uses right now (Settings › Appearance).
final themeModeProvider = Provider<ThemeMode>((ref) {
  final p = ref.watch(desktopPrefsProvider);
  switch (p.appearance) {
    case Appearance.system:
      return ThemeMode.system;
    case Appearance.light:
      return ThemeMode.light;
    case Appearance.dark:
      return ThemeMode.dark;
    case Appearance.schedule:
      final t = DateTime.now();
      final minute = ref.watch(_minuteOfDayProvider).value ?? t.hour * 60 + t.minute;
      return p.lightAt(minute) ? ThemeMode.light : ThemeMode.dark;
  }
});

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

  /// A takeover nobody answers steps back after this long: the suggestion
  /// stays waiting (card, amber dot, notification), the screen is yours again.
  static const takeoverHold = Duration(seconds: 60);

  Timer? _collapse;
  Timer? _retreat;
  WindowMode _beforeLock = WindowMode.full;
  WindowMode _beforeNudge = WindowMode.full;
  bool _hidden = false;
  Future<void> _native = Future.value(); // native changes run one at a time, in order

  /// Bumps each time the native window has finished popping into a compact
  /// shape: the compact view plays its pop-in from this, not from the state
  /// change (which happens while the window is still hidden).
  final popped = ValueNotifier<int>(0);

  /// True once the widget failed to open on this computer: Flow then stays in
  /// its window for the rest of the run instead of trying again.
  final widgetUnavailable = ValueNotifier<bool>(false);

  DesktopHost get _host => ref.read(desktopHostProvider);
  bool get hidden => _hidden;

  @override
  WindowMode build() {
    final host = ref.watch(desktopHostProvider);
    ref.onDispose(() {
      _collapse?.cancel();
      _retreat?.cancel();
      popped.dispose();
      widgetUnavailable.dispose();
    });
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
        // a break taken from a takeover returns to where the takeover came from
        _beforeLock = state.isTakeover ? _beforeNudge : state;
        _retreat?.cancel();
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
      if (ref.read(desktopPrefsProvider).autoMini && _host.isDesktop && !widgetUnavailable.value) _go(WindowMode.mini);
    }
    // ended: grow back into the full app (the summary opens there)
    if (prev != null && next == null && state.isFloating) {
      _retreat?.cancel();
      _go(WindowMode.full);
    }

    // a nudge arrived
    final had = prev?.pendingInterventionId;
    final has = next?.pendingInterventionId;
    if (has != null && has != had) {
      final style = ref.read(desktopPrefsProvider).nudgeStyle;
      if (style == NudgeStyle.notification || state == WindowMode.lock) {
        if (state == WindowMode.mini) openCard();
        unawaited(_maybeNotify(next!));
      } else {
        _takeOver(style == NudgeStyle.fullScreen ? WindowMode.nudgeFull : WindowMode.nudge);
      }
    }
    // answered
    if (has == null && had != null) {
      if (state == WindowMode.card) _go(WindowMode.mini);
      if (state.isTakeover) _leaveTakeover();
    }

    _updateTray(next);
  }

  Future<void> _maybeNotify(LiveSession s) async {
    if (!_host.isDesktop) return;
    // The card on top already is the nudge in widget mode; notify only when
    // the window is hidden, or the full app sits unfocused behind other work.
    if (state.isFloating || state == WindowMode.lock) {
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
    final corner = ref.read(desktopPrefsProvider).corner;
    _native = _native.then((_) => _apply(m, corner));
  }

  Future<void> _apply(WindowMode m, WidgetCorner corner) async {
    var ok = false;
    try {
      ok = await _host.applyMode(m, corner: corner);
    } catch (_) {}
    if (!ref.mounted) return;
    if (ok) {
      if (m.isFloating) popped.value++;
      return;
    }
    // The window did not take the shape. Never leave a broken window on
    // screen: go back to the full app. A takeover still shows there, inside
    // Flow's own window; the small widget is not offered again this run.
    if (m.isFloating) {
      if (m.isCompact) widgetUnavailable.value = true;
      _collapse?.cancel();
      if (state.isCompact) state = WindowMode.full;
      try {
        await _host.applyMode(WindowMode.full, corner: corner);
      } catch (_) {}
    }
  }

  /// The suggestion takes the screen (or a floating window). It remembers
  /// where it came from and goes back there when answered or after
  /// [takeoverHold] without an answer.
  void _takeOver(WindowMode m) {
    if (!state.isTakeover) _beforeNudge = state == WindowMode.card ? WindowMode.mini : state;
    _hidden = false; // the pop shows the window
    _go(m);
    _retreat?.cancel();
    _retreat = Timer(takeoverHold, retreat);
  }

  void _leaveTakeover() {
    _retreat?.cancel();
    final live = ref.read(liveSessionProvider).value != null;
    _go(live && _beforeNudge == WindowMode.mini && !widgetUnavailable.value ? WindowMode.mini : WindowMode.full);
  }

  /// Step back from a takeover without answering (60 s passed, or "Not now").
  /// The suggestion keeps waiting where a notification-style nudge would be.
  void retreat() {
    if (!state.isTakeover) return;
    _leaveTakeover();
    final s = ref.read(liveSessionProvider).value;
    if (s?.pendingInterventionId != null) unawaited(_maybeNotify(s!));
  }

  /// Shrink to the widget: only while a session runs.
  void shrink() {
    if (ref.read(liveSessionProvider).value == null || widgetUnavailable.value) return;
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
