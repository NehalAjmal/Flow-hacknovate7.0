import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/auth_controller.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import 'wordmark.dart';

/// Cold-start launch (DESIGN_SPEC §17):
///  1. each letter's outline draws in as slow stone dashes (the spine's "not yet" line)
///  2. the letters fill bottom → top like liquid; the surface ripples in
///     proportion to the fill spring's velocity, so it calms as it settles
///  3. the o (the one accent element) opens into a circle that grows over the
///     screen with a critically damped spring, revealing the live app beneath
/// The splash uses the opposite ground to the app (dark splash for a light app
/// and the reverse), so the reveal reads as the ground changing.
/// Any click or key skips ahead. Reduced motion: still mark, 150 ms fade.
/// The reveal waits for auth to resolve; meanwhile a dashed line runs under the mark.
class LaunchOverlay extends ConsumerStatefulWidget {
  const LaunchOverlay({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<LaunchOverlay> createState() => _LaunchOverlayState();
}

/// Critically damped spring from 0 → 1 (Rule 2: SETTLE family), closed form.
({double x, double v}) _settle(double t, double response) {
  if (t <= 0) return (x: 0, v: 0);
  final w = 2 * math.pi / response;
  final e = math.exp(-w * t);
  return (x: 1 - (1 + w * t) * e, v: w * w * t * e);
}

double _easeInOut(double t) => Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));

class _LaunchOverlayState extends ConsumerState<LaunchOverlay> with SingleTickerProviderStateMixin {
  // Timeline, milliseconds.
  // ≈3.4 s end to end (was ≈2.6 s): the outline gets time to be seen as an
  // outline, and the pour reads as liquid rather than a wipe.
  static const _dashStart = 160.0, _dashStagger = 120.0, _dashDur = 950.0;
  static const _fillStart = 1050.0, _fillStagger = 140.0, _fillResponse = 0.9;
  static const _revealResponse = 0.65, _skipResponse = 0.42; // a skip is impatient: snappier reveal
  static const _fade = 150.0;

  late final Ticker _ticker = createTicker(_tick);
  double _ms = 0;
  double _offsetMs = 0; // skip-ahead
  double? _revealAt; // ms when the reveal started
  bool _done = false;
  bool _reduced = false;
  bool _skipped = false;
  double get _response => _skipped ? _skipResponse : _revealResponse;

  @override
  void initState() {
    super.initState();
    LaunchGate.revealed.value = false;
    _ticker.start();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void dispose() {
    LaunchGate.revealed.value = true;
    HardwareKeyboard.instance.removeHandler(_onKey);
    _ticker.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (_done || e is! KeyDownEvent) return false;
    _skip();
    return false; // never swallow keys
  }

  double get _filledAt => _fillStart + 3 * _fillStagger + 820; // ≈ 97% of the last fill

  void _skip() {
    _skipped = true;
    if (_ms < _filledAt) _offsetMs += _filledAt - _ms;
  }

  bool get _authReady => ref.read(authProvider) is! AuthUnknown;

  void _tick(Duration elapsed) {
    if (_done) return;
    final ms = elapsed.inMicroseconds / 1000 + _offsetMs;
    if (_revealAt == null && _authReady && (_reduced || ms >= _filledAt)) {
      _revealAt = ms;
      LaunchGate.revealed.value = true; // let the app's own entrances play now
    }
    final r = _revealAt;
    if (r != null) {
      final finished = _reduced ? ms - r >= _fade : _settle((ms - r) / 1000, _response).x > 0.999;
      if (finished) {
        _ticker.stop();
        setState(() => _done = true);
        return;
      }
    }
    setState(() => _ms = ms);
  }

  WordmarkFrame _frame() {
    if (_reduced) return WordmarkFrame.still;
    final dash = <double>[], fill = <double>[], wave = <double>[];
    var outline = 1.0;
    for (var i = 0; i < 4; i++) {
      dash.add(_easeInOut((_ms - _dashStart - i * _dashStagger) / _dashDur));
      final s = _settle((_ms - _fillStart - i * _fillStagger) / 1000, _fillResponse);
      fill.add(s.x);
      // Peak spring velocity is w/e; ripple up to 22 font units at peak.
      final w = 2 * math.pi / _fillResponse;
      wave.add(22 * (s.v / (w / math.e)).clamp(0.0, 1.0));
    }
    final lastFill = fill.last;
    if (lastFill > 0.85) outline = (1 - (lastFill - 0.85) / 0.15).clamp(0.0, 1.0);
    return WordmarkFrame(dash: dash, fill: fill, wave: wave, outline: outline, phase: _ms / 160);
  }

  @override
  Widget build(BuildContext context) {
    // Same tree shape before and after: returning bare `widget.child` once
    // done would remount the whole app at the end of the reveal (a hitch,
    // and every screen's entrance replaying).
    if (_done) return Stack(children: [widget.child, const SizedBox.shrink()]);
    final appDark = Theme.of(context).brightness == Brightness.dark;
    // Opposite ground for the splash; the reveal turns it into the app's own.
    final splash = appDark ? FlowPalette.light : FlowPalette.dark;
    final ground = splash.bg;
    final ink = appDark ? FlowPalette.light.text1 : FlowPalette.light.raised;
    final stone = appDark ? FlowPalette.light.pastHeavy : FlowPalette.light.pastModerate;
    final accent = splash.accent;

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _skip,
            child: Semantics(
              label: 'Flow is starting',
              liveRegion: true,
              child: CustomPaint(
                painter: _LaunchPainter(
                  ms: _ms,
                  revealAt: _revealAt,
                  reduced: _reduced,
                  ground: ground,
                  ink: ink,
                  stone: stone,
                  accent: accent,
                  frame: _frame(),
                  waiting: _revealAt == null && _ms >= _filledAt,
                  response: _response,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LaunchPainter extends CustomPainter {
  _LaunchPainter({
    required this.ms,
    required this.revealAt,
    required this.reduced,
    required this.ground,
    required this.ink,
    required this.stone,
    required this.accent,
    required this.frame,
    required this.waiting,
    required this.response,
  });

  final double ms;
  final double? revealAt;
  final bool reduced;
  final Color ground, ink, stone, accent;
  final WordmarkFrame frame;
  final bool waiting;
  final double response;

  @override
  void paint(Canvas canvas, Size size) {
    final capH = (size.width * 0.12).clamp(36.0, 84.0);
    final markW = FlowWordmark.widthFor(capH);
    final markRect = Rect.fromCenter(center: size.center(Offset.zero), width: markW, height: capH);
    final o = markRect.topLeft + WordmarkLayout.oCenter(markRect.size);

    var opacity = 1.0;
    double radius = 0;
    final r = revealAt;
    if (r != null) {
      if (reduced) {
        opacity = (1 - (ms - r) / _LaunchOverlayState._fade).clamp(0.0, 1.0);
      } else {
        final far = [
          size.topLeft(Offset.zero),
          size.topRight(Offset.zero),
          size.bottomLeft(Offset.zero),
          size.bottomRight(Offset.zero),
        ].map((c) => (c - o).distance).reduce(math.max);
        radius = far * _settle((ms - r) / 1000, response).x;
      }
    }

    canvas.saveLayer(Offset.zero & size, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    if (radius > 0) canvas.clipPath(revealHole(size, o, radius));
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);

    canvas.save();
    canvas.translate(markRect.left, markRect.top);
    WordmarkPainter(ink: ink, accent: accent, stroke: stone, frame: frame, strokeWidthPx: 1.5).paint(canvas, markRect.size);
    canvas.restore();

    if (waiting) {
      // Still resolving sign-in: a dashed "not yet" line runs under the mark.
      final y = markRect.bottom + capH * 0.45;
      final paint = Paint()
        ..color = stone
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      const dash = 6.0, gap = 6.0;
      final shift = (ms / 40) % (dash + gap);
      for (var x = markRect.left - dash + shift; x < markRect.right; x += dash + gap) {
        final a = math.max(x, markRect.left), b = math.min(x + dash, markRect.right);
        if (b > a) canvas.drawLine(Offset(a, y), Offset(b, y), paint);
      }
    }
    canvas.restore();

    if (radius > 0) {
      drawRevealFront(canvas, o, radius, stone.withValues(alpha: 0.6 * (1 - radius / (size.longestSide * 1.2)).clamp(0.0, 1.0)));
    }
  }

  @override
  bool shouldRepaint(_LaunchPainter o) => true;
}

/// Hole-punch path for the reveal (even-odd: the circle is cut out of the screen).
Path revealHole(Size size, Offset center, double radius) => Path()
  ..fillType = PathFillType.evenOdd
  ..addRect(Offset.zero & size)
  ..addOval(Rect.fromCircle(center: center, radius: radius));

/// 1 px ring at the reveal front, fading as it grows.
void drawRevealFront(Canvas c, Offset center, double radius, Color color) {
  c.drawCircle(
    center,
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color,
  );
}
