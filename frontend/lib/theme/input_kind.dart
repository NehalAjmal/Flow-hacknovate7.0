import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Which kind of device the user is scrolling/dragging with right now.
/// The rubber-band coefficient depends on it (Rule 2).
enum InputKind {
  touch(0.55),
  mouseDrag(0.4),
  notchedWheel(0.5),
  smoothWheel(0.17),
  smallTrackpad(0.715),
  largeTrackpad(0.17);

  const InputKind(this.rubberBand);
  final double rubberBand;
}

/// App-wide tracker, fed by [InputKindListener] at the root.
class InputKindTracker extends ValueNotifier<InputKind> {
  InputKindTracker._() : super(InputKind.mouseDrag);
  static final instance = InputKindTracker._();

  /// Windows/mac notched wheels report steps of ~100–120 logical px;
  /// smooth wheels and precise devices report small fractional deltas.
  void _onSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      final d = e.scrollDelta.distance;
      value = d >= 40 ? InputKind.notchedWheel : InputKind.smoothWheel;
    }
  }

  void _onDown(PointerDownEvent e) {
    value = switch (e.kind) {
      PointerDeviceKind.touch || PointerDeviceKind.stylus || PointerDeviceKind.invertedStylus => InputKind.touch,
      PointerDeviceKind.trackpad => InputKind.smallTrackpad,
      _ => InputKind.mouseDrag,
    };
  }

  void _onPanZoom(PointerPanZoomStartEvent e) => value = InputKind.smallTrackpad;
}

/// Wrap the app once. Listens passively; never consumes events.
class InputKindListener extends StatelessWidget {
  const InputKindListener({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = InputKindTracker.instance;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: t._onSignal,
      onPointerDown: t._onDown,
      onPointerPanZoomStart: t._onPanZoom,
      child: child,
    );
  }
}
