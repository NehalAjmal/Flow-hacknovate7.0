import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import 'wordmark_glyphs.dart';

/// The Flow wordmark: "Flow" in OffBit 101 Bold, drawn from outlines so the
/// launch animation can stroke and fill each letter. One accent element only:
/// the "o" (it is also where the launch reveal opens from).
class FlowWordmark extends StatelessWidget {
  const FlowWordmark({super.key, this.capHeight = 14, this.color, this.accent});

  /// Height of the capital F in logical pixels.
  final double capHeight;
  final Color? color;
  final Color? accent;

  static double widthFor(double capHeight) => WordmarkLayout.glyphWidth * capHeight / WordmarkLayout.capUnits;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Semantics(
      label: 'Flow',
      image: true,
      child: SizedBox(
        width: widthFor(capHeight),
        height: capHeight,
        child: CustomPaint(
          painter: WordmarkPainter(ink: color ?? p.text1, accent: accent ?? p.accent, frame: WordmarkFrame.still),
        ),
      ),
    );
  }
}

/// Glyph geometry shared by the still mark and the launch animation.
abstract final class WordmarkLayout {
  static const double left = 27;
  static const double right = 2022;
  static const double glyphWidth = right - left;
  static const double capUnits = 700;
  static const int oIndex = 2;

  static final List<Path> letters = WordmarkGlyphs.letters();
  static final List<Rect> bounds = [for (final l in letters) l.getBounds()];

  /// Font units → box of [size]: wordmark fitted by cap height and centred.
  static ({double scale, Offset origin}) fit(Size size) {
    final scale = math.min(size.height / capUnits, size.width / glyphWidth);
    final dx = (size.width - glyphWidth * scale) / 2 - left * scale;
    final dy = (size.height + capUnits * scale) / 2;
    return (scale: scale, origin: Offset(dx, dy));
  }

  /// The o's centre in the painter box (the launch reveal opens from here).
  static Offset oCenter(Size size) {
    final f = fit(size);
    return f.origin + WordmarkGlyphs.oCenter * f.scale;
  }
}

/// One frame of the mark. [dash] = how much of each outline is drawn (0..1),
/// [fill] = liquid level per letter (0..1), [wave] = surface amplitude per
/// letter in font units, [outline] = outline opacity.
class WordmarkFrame {
  const WordmarkFrame({required this.dash, required this.fill, required this.wave, required this.outline, this.phase = 0});
  final List<double> dash;
  final List<double> fill;
  final List<double> wave;
  final double outline;
  final double phase;

  static const still = WordmarkFrame(dash: [0, 0, 0, 0], fill: [1, 1, 1, 1], wave: [0, 0, 0, 0], outline: 0);
}

class WordmarkPainter extends CustomPainter {
  WordmarkPainter({required this.ink, required this.accent, required this.frame, this.stroke, this.strokeWidthPx = 1.4});

  final Color ink;
  final Color accent;
  final Color? stroke;
  final double strokeWidthPx;
  final WordmarkFrame frame;

  static const _dash = 30.0;
  static const _gap = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final f = WordmarkLayout.fit(size);
    final scale = f.scale;
    canvas.save();
    canvas.translate(f.origin.dx, f.origin.dy);
    canvas.scale(scale);
    for (var i = 0; i < WordmarkLayout.letters.length; i++) {
      final path = WordmarkLayout.letters[i];
      final b = WordmarkLayout.bounds[i];
      final color = i == WordmarkLayout.oIndex ? accent : ink;

      final level = frame.fill[i];
      if (level >= 0.999 && frame.wave[i].abs() < 0.5) {
        canvas.drawPath(path, Paint()..color = color);
      } else if (level > 0) {
        canvas.save();
        canvas.clipPath(path);
        final top = b.top - 24, bottom = b.bottom + 4;
        final surface = bottom - level * (bottom - top);
        final amp = frame.wave[i];
        final liquid = Path()..moveTo(b.left - 10, surface);
        for (var x = b.left - 10; x <= b.right + 10; x += 12) {
          final y = surface + amp * math.sin((x - b.left) / 95 + frame.phase + i * 1.3);
          liquid.lineTo(x, y);
        }
        liquid
          ..lineTo(b.right + 10, bottom + 10)
          ..lineTo(b.left - 10, bottom + 10)
          ..close();
        canvas.drawPath(liquid, Paint()..color = color);
        canvas.restore();
      }

      final d = frame.dash[i];
      if (stroke != null && d > 0 && frame.outline > 0) {
        final paint = Paint()
          ..color = stroke!.withValues(alpha: stroke!.a * frame.outline)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidthPx / scale
          ..strokeCap = StrokeCap.round;
        for (final metric in path.computeMetrics()) {
          final limit = metric.length * d;
          for (var s = 0.0; s < limit; s += _dash + _gap) {
            canvas.drawPath(metric.extractPath(s, math.min(s + _dash, limit)), paint);
          }
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(WordmarkPainter o) => true;
}
