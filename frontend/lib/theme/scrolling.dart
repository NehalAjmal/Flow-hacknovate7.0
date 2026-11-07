import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'input_kind.dart';
import 'motion.dart';
import 'palette.dart';

/// macOS-style scrolling everywhere, on both OSes (D19).
///
/// Overscroll follows Apple's rubber band `c·x·d / (d + c·x)` with `c` chosen
/// from the device in use; releasing springs back with the SNAP spring.
///
/// Note: Flutter applies notched mouse-wheel events directly to the scroll
/// position (clamped), so the wheel does not rubber-band; trackpads and drags do.
class RubberBandScrollPhysics extends BouncingScrollPhysics {
  const RubberBandScrollPhysics({super.parent});

  @override
  RubberBandScrollPhysics applyTo(ScrollPhysics? ancestor) => RubberBandScrollPhysics(parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (!position.outOfRange) return offset;
    final pastStart = math.max(position.minScrollExtent - position.pixels, 0.0);
    final pastEnd = math.max(position.pixels - position.maxScrollExtent, 0.0);
    final over = math.max(pastStart, pastEnd);
    // Dragging back toward the content is never resisted beyond the curve.
    final easing = (pastStart > 0 && offset < 0) || (pastEnd > 0 && offset > 0);
    final d = position.viewportDimension;
    final c = InputKindTracker.instance.value.rubberBand;
    final finger = RubberBand.inverse(over, d, c);
    final nextFinger = easing ? finger - offset.abs() : finger + offset.abs();
    if (nextFinger <= 0) {
      // Back inside the content: the rest of the drag applies 1:1.
      return offset.sign * (over - nextFinger);
    }
    return offset.sign * (RubberBand.offset(nextFinger, d, c) - over).abs();
  }

  @override
  SpringDescription get spring => Motion.snap;
}

/// Slim, auto-hiding overlay scrollbars + rubber-band physics, app-wide.
class FlowScrollBehavior extends MaterialScrollBehavior {
  const FlowScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const RubberBandScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    final p = FlowPalette.of(context);
    return RawScrollbar(
      controller: details.controller,
      thickness: 4,
      radius: const Radius.circular(2),
      thumbColor: p.text3.withValues(alpha: 0.55),
      fadeDuration: Motion.fade,
      timeToFade: const Duration(milliseconds: 700),
      mainAxisMargin: 6,
      crossAxisMargin: 3,
      child: child,
    );
  }
}
