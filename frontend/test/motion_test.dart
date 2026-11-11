import 'dart:math' as math;

import 'package:flow/theme/motion.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RubberBand (Apple: c·x·d / (d + c·x))', () {
    test('matches the published table for touch (c 0.55, d 844)', () {
      expect(RubberBand.offset(25, 844, 0.55), closeTo(13.5, 0.1));
      expect(RubberBand.offset(100, 844, 0.55), closeTo(51.6, 0.1));
      expect(RubberBand.offset(844, 844, 0.55), closeTo(299.5, 0.1));
      expect(RubberBand.offset(3000, 844, 0.55), closeTo(558.4, 0.1));
    });
    test('never exceeds the ceiling d', () {
      expect(RubberBand.offset(1e9, 400, 0.4), lessThan(400));
    });
    test('inverse round-trips', () {
      for (final x in [10.0, 200.0, 900.0]) {
        final o = RubberBand.offset(x, 600, 0.4);
        expect(RubberBand.inverse(o, 600, 0.4), closeTo(x, 1e-6));
      }
    });
    test('sign is preserved', () {
      expect(RubberBand.offset(-50, 600, 0.4), lessThan(0));
    });
  });

  test('spring presets: stiffness (2π/0.5)² ≈ 157.91, smooth critically damped', () {
    expect(Motion.settle.stiffness, closeTo(157.91, 0.01));
    expect(Motion.settle.damping, closeTo(25.13, 0.01));
    // snap: response 0.32 s, ratio 0.9 → a trace of overshoot, settled fast
    expect(Motion.snap.stiffness, closeTo(385.53, 0.01));
    expect(Motion.snap.damping, closeTo(35.34, 0.01));
  });

  test('follow never overshoots what it follows (critically damped)', () {
    final s = Motion.follow;
    expect(s.damping, closeTo(2 * math.sqrt(s.stiffness * s.mass), 1e-6));
    final sim = SpringSimulation(s, 0, 1, 0);
    for (var t = 0.0; t < 1; t += 0.004) {
      expect(sim.x(t), lessThanOrEqualTo(1.0 + 1e-9));
    }
  });
}
