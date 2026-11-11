import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../ui/appear.dart' show AppearScope;

/// Flow motion system. DESIGN_SPEC §1, Rule 2.
///
/// Springs (not timers) for anything the user can interrupt, and every
/// retarget carries the current velocity. Presets follow Apple's measured
/// values: mass 1, stiffness = (2π / response)², damping from the ratio.
abstract final class Motion {
  static SpringDescription _spring(double response, double dampingRatio) =>
      SpringDescription.withDampingRatio(mass: 1, stiffness: math.pow(2 * math.pi / response, 2).toDouble(), ratio: dampingRatio);

  /// Catching up with something that moved in steps (wheel notches, hover).
  /// Critically damped: it must never overshoot what it follows.
  ///
  /// NOT for drags. A drag sets the value directly (`SpringValue.value = v`):
  /// restarting a spring on every pointer event makes the control lag and
  /// wobble around the hand, which reads as jitter.
  static final follow = _spring(0.12, 1.0);

  /// Detents, presses, releases, choices: quick, with a trace of overshoot.
  static final snap = _spring(0.32, 0.9);

  /// Shape/position changes and shared-element moves. No overshoot.
  static final settle = _spring(0.5, 1.0);

  /// Text swaps only (never interrupted, so a timer is fine).
  static const fade = Duration(milliseconds: 150);

  /// Stagger step, applied outward from the cause.
  static const staggerStep = Duration(milliseconds: 35);

  /// Plays a first-appearance animation once the app is visible (see
  /// [LaunchGate]); with reduced motion it jumps to the end.
  static void enter(BuildContext context, AnimationController c, bool Function() mounted) {
    if (reduced(context)) {
      c.value = 1;
      return;
    }
    LaunchGate.whenVisible(() {
      if (mounted()) c.forward();
    });
  }

  /// For initState: like [enter], but on a revisit of a page (see
  /// AppearScope) the controller starts settled in the very first frame —
  /// no one-frame blank, no replayed entrance.
  static void enterOnMount(BuildContext context, AnimationController c, bool Function() mounted) {
    if (!AppearScope.animates(context)) {
      c.value = 1;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted()) enter(context, c, mounted);
    });
  }

  static Duration stagger(int distanceFromCause) => staggerStep * distanceFromCause.abs();

  /// SETTLE as a closed form (0 → 1, critically damped) for painters that
  /// animate many things off one clock: [t] seconds since that item started.
  /// Used for every 3D block rising from its line.
  /// Velocity of [settleAt] (units per second), for ripples/stretch that
  /// should calm as the spring settles.
  static double settleVelAt(double t, {double response = 0.5}) {
    if (t <= 0) return 0;
    final w = 2 * math.pi / response;
    return w * w * t * math.exp(-w * t);
  }

  /// Peak of [settleVelAt] (reached at t = 1/w), to normalise velocities.
  static double settlePeakVel({double response = 0.5}) => (2 * math.pi / response) / math.e;

  static double settleAt(double t, {double response = 0.5}) {
    if (t <= 0) return 0;
    final w = 2 * math.pi / response;
    return (1 - (1 + w * t) * math.exp(-w * t)).clamp(0.0, 1.0);
  }

  /// OS "reduce motion": jump to end states (the CLOCK still runs).
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Drives a value with springs, carrying velocity through every retarget.
///
/// ```dart
/// late final _x = SpringValue(vsync: this, initial: 0);
/// _x.animateTo(1, spring: Motion.settle);
/// ```
class SpringValue {
  SpringValue({required TickerProvider vsync, double initial = 0}) : _c = AnimationController.unbounded(vsync: vsync, value: initial);

  final AnimationController _c;

  Animation<double> get animation => _c;
  double get value => _c.value;
  double get velocity => _c.velocity;
  bool get isAnimating => _c.isAnimating;
  double? _target;
  double get target => _target ?? _c.value;

  /// Retargets from the current position *and* velocity (Rule 2).
  TickerFuture animateTo(double target, {SpringDescription? spring, double? velocity, bool reduced = false}) {
    _target = target;
    if (reduced) {
      _c.value = target;
      return TickerFuture.complete();
    }
    return _c.animateWith(SpringSimulation(spring ?? Motion.settle, _c.value, target, velocity ?? _c.velocity));
  }

  /// Follow the pointer directly (no simulation): used during drags.
  set value(double v) {
    _target = v;
    _c.value = v;
  }

  void stop() => _c.stop();
  void dispose() => _c.dispose();
}

/// Apple's rubber band: content moves `c·x·d / (d + c·x)` for a drag `x` past
/// the edge, with ceiling `d` (the control's size on that axis).
abstract final class RubberBand {
  static double offset(double x, double d, double c) {
    if (d <= 0) return 0;
    final s = x.sign;
    final a = x.abs();
    return s * (c * a * d) / (d + c * a);
  }

  /// Inverse: the finger distance that produces content offset [o].
  static double inverse(double o, double d, double c) {
    if (d <= 0 || c <= 0) return 0;
    final s = o.sign;
    final a = math.min(o.abs(), d * 0.999);
    return s * (a * d) / (c * (d - a));
  }
}

/// First-appearance animations wait for the launch reveal: content under the
/// launch overlay is built early, and its rise/fill would otherwise finish
/// before anyone sees it. The overlay sets [revealed] false while it covers
/// the app and true the moment the reveal starts. Default true (no overlay,
/// e.g. tests), so nothing waits forever.
abstract final class LaunchGate {
  static final revealed = ValueNotifier<bool>(true);

  /// Runs [start] now if the app is visible, otherwise once the reveal begins.
  static void whenVisible(VoidCallback start) {
    if (revealed.value) return start();
    void listener() {
      if (!revealed.value) return;
      revealed.removeListener(listener);
      start();
    }

    revealed.addListener(listener);
  }
}
