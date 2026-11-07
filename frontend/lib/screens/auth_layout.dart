import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../ui/brand/wordmark.dart';
import '../ui/pressable.dart';

/// What the stage on the left is telling the person (DESIGN_SPEC §4).
/// rest: the next block is an outline (not yet) · busy: it fills while the
/// request runs · error: it drains back and stays an outline (no shake) ·
/// success: it fills completely.
enum StageState { rest, busy, error, success }

/// Signed-out frame: left ~42% is the stage (wordmark, a line, blocks rising
/// from it); right is the slim form, max 360 px, vertically centred.
/// Under 820 px wide the stage collapses to the wordmark above the form.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    this.subtitle,
    required this.form,
    this.stage = StageState.rest,
    this.footer = const [],
    this.showcase,
  });

  /// Replaces the blocks on the brand field (Welcome shows a sample nudge).
  final Widget? showcase;

  final String title;
  final String? subtitle;
  final List<Widget> form;
  final StageState stage;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final column = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: FlowType.headline(p, size: 30)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: TextStyle(color: p.text2, fontSize: 13, height: 1.45)),
          ],
          const SizedBox(height: 24),
          for (final (i, c) in form.indexed) ...[if (i > 0) const SizedBox(height: 10), c],
          if (footer.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(spacing: 4, runSpacing: 2, alignment: WrapAlignment.start, children: footer),
          ],
        ],
      ),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 820;
          final scrollForm = Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: wide
                  ? column
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [const FlowWordmark(capHeight: 22), const SizedBox(height: 28), column],
                    ),
            ),
          );
          if (!wide) return scrollForm;
          return Row(
            children: [
              // the brand field: a deeper warm stone with the day's blocks on it
              Container(
                width: c.maxWidth * 0.42,
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.fromLTRB(34, 30, 28, 30),
                decoration: BoxDecoration(
                  color: p.ultraDeep,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: p.hairline),
                ),
                child: showcase == null
                    ? BlocksStage(state: stage)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FlowWordmark(capHeight: 34),
                          const SizedBox(height: 22),
                          Expanded(child: SingleChildScrollView(child: showcase)),
                        ],
                      ),
              ),
              Expanded(child: scrollForm),
            ],
          );
        },
      ),
    );
  }
}

/// The line with the day's blocks rising from it, plus the "next" block that
/// reacts to [state]. Shared by the signed-out screens and the welcome guide.
class BlocksStage extends StatefulWidget {
  const BlocksStage({super.key, required this.state, this.showBrand = true, this.onField = false});
  final StageState state;
  final bool showBrand;

  /// Drawn on the ultramarine field: paper line-work, bright accent.
  final bool onField;

  @override
  State<BlocksStage> createState() => _StageState();
}

class _StageState extends State<BlocksStage> with TickerProviderStateMixin {
  late final _fill = SpringValue(vsync: this, initial: _target(widget.state));
  // the blocks rise from the line once, when the screen first appears
  late final _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Motion.enter(context, _rise, () => mounted);
    });
  }

  static double _target(StageState s) => switch (s) {
    StageState.rest || StageState.error => 0,
    StageState.busy => 0.72,
    StageState.success => 1,
  };

  @override
  void didUpdateWidget(BlocksStage old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      _fill.animateTo(_target(widget.state), reduced: MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    }
  }

  @override
  void dispose() {
    _fill.dispose();
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showBrand) ...[
          FlowWordmark(capHeight: 34, color: widget.onField ? p.onField : null, accent: widget.onField ? FlowPalette.dark.accent : null),
          const SizedBox(height: 16),
          Text(
            'Breaks that fit your work,\nand the reason for each one.',
            style: FlowType.note(p, size: 17, color: widget.onField ? p.onField.withValues(alpha: 0.86) : null),
          ),
        ],
        Expanded(
          child: AnimatedBuilder(
            animation: Listenable.merge([_fill.animation, _rise]),
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _StagePainter(
                p: p,
                fill: _fill.value.clamp(0.0, 1.0),
                error: widget.state == StageState.error,
                rise: _rise.isCompleted ? 1e9 : _rise.value * 1.8,
                onField: widget.onField,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A line with the day's blocks resting on it, front-on with a top and side
/// face (the Score's block language). The last block is the next one: an
/// outline until something happens.
class _StagePainter extends CustomPainter {
  _StagePainter({required this.p, required this.fill, required this.error, required this.rise, this.onField = false});
  final bool onField;
  final FlowPalette p;
  final double fill;
  final bool error;
  final double rise; // seconds since the rise started

  // (start, width, height) as fractions of the stage width / block max
  static const _blocks = [(0.02, 0.13, 0.55), (0.18, 0.17, 1.0), (0.38, 0.10, 0.72), (0.53, 0.15, 0.86)];
  static const _next = (0.72, 0.14, 0.68);

  @override
  void paint(Canvas c, Size s) {
    // the line sits level with the form's centre; blocks rise above it
    final maxH = math.min(190.0, s.height * 0.42);
    final base = math.min(s.height - 6, s.height * 0.5 + maxH * 0.42);
    final depth = (maxH * 0.07).clamp(4.0, 8.0);

    final ink = onField ? p.onField.withValues(alpha: 0.6) : p.text3;
    c.drawLine(
      Offset(0, base),
      Offset(s.width, base),
      Paint()
        ..color = ink
        ..strokeWidth = 1,
    );
    // hour ticks under the line
    for (var i = 0; i <= 8; i++) {
      final x = s.width * i / 8;
      c.drawLine(
        Offset(x, base),
        Offset(x, base + 4),
        Paint()
          ..color = ink.withValues(alpha: 0.6)
          ..strokeWidth = 0.8,
      );
    }

    final stones = [p.pastModerate, p.pastHeavy, p.pastLight, p.pastModerate];
    for (final (i, b) in _blocks.indexed) {
      final tt = rise >= 1e8 ? 1e9 : rise - i * 0.09;
      final x0 = s.width * b.$1, w = s.width * b.$2;
      final r = tt >= 1e8 ? 1.0 : Motion.settleAt(tt);
      if (r > 0.004) _solid(c, x0, w, base, maxH * b.$3 * r, depth, stones[i]);
    }

    final (nx, nw, nh) = _next;
    final x0 = s.width * nx, w = s.width * nw, h = maxH * nh * Motion.settleAt(rise - 4 * 0.09);
    if (h < 0.5) return;
    if (fill > 0.001) {
      c.save();
      c.clipRect(Rect.fromLTRB(x0 - 1, base - h * fill - depth - 1, x0 + w + depth + 1, base + 1));
      _solid(c, x0, w, base, h, depth, onField ? FlowPalette.dark.accent : p.accent);
      c.restore();
    }
    _outline(c, x0, w, base, h, depth, error ? p.amber : (onField ? p.onField : p.future));
  }

  Path _faces(double x0, double w, double base, double h, double d) {
    final top = base - h;
    return Path()
      ..moveTo(x0, base)
      ..lineTo(x0, top)
      ..lineTo(x0 + d, top - d)
      ..lineTo(x0 + w + d, top - d)
      ..lineTo(x0 + w + d, base - d)
      ..lineTo(x0 + w, base)
      ..close();
  }

  void _solid(Canvas c, double x0, double w, double base, double h, double d, Color col) {
    final top = base - h;
    c.drawRect(Rect.fromLTRB(x0, top, x0 + w, base), Paint()..color = col);
    c.drawPath(
      Path()
        ..moveTo(x0, top)
        ..lineTo(x0 + d, top - d)
        ..lineTo(x0 + w + d, top - d)
        ..lineTo(x0 + w, top)
        ..close(),
      Paint()..color = Faces.top(col),
    );
    c.drawPath(
      Path()
        ..moveTo(x0 + w, top)
        ..lineTo(x0 + w + d, top - d)
        ..lineTo(x0 + w + d, base - d)
        ..lineTo(x0 + w, base)
        ..close(),
      Paint()..color = Faces.side(col),
    );
  }

  void _outline(Canvas c, double x0, double w, double base, double h, double d, Color col) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = col;
    final path = _faces(x0, w, base, h, d)
      ..moveTo(x0, base - h)
      ..lineTo(x0 + w, base - h)
      ..lineTo(x0 + w + d, base - h - d)
      ..moveTo(x0 + w, base - h)
      ..lineTo(x0 + w, base);
    for (final m in path.computeMetrics()) {
      for (var t = 0.0; t < m.length; t += 6) {
        c.drawPath(m.extractPath(t, math.min(t + 3.5, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_StagePainter o) => o.fill != fill || o.error != error || o.rise != rise || o.onField != onField || o.p != p;
}

/// Primary action, full width, inside the slim form.
class AuthPrimary extends StatelessWidget {
  const AuthPrimary({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    tone: PressableTone.primary,
    onPressed: onPressed,
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: SizedBox(
      width: double.infinity,
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}

/// Quiet text link (footer actions).
class AuthLink extends StatelessWidget {
  const AuthLink(this.label, {super.key, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: p.text2,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: const Size(0, 32),
        textStyle: const TextStyle(fontFamily: FlowFonts.ui, fontSize: 12.5, decoration: TextDecoration.underline),
      ),
      child: Text(label),
    );
  }
}

/// Inline error: one line, problem colour, no modal (spec §13).
class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Semantics(
      liveRegion: true,
      child: Text(message, style: TextStyle(color: p.problem, fontSize: 12.5)),
    );
  }
}

/// Flow speaking (Cutive): notices like "you were signed out because…".
class AuthNote extends StatelessWidget {
  const AuthNote(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    // A uniform box with an inset bar (a one-sided border + radius asserts).
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: p.raised,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 2, color: p.text3),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                  child: Text(message, style: FlowType.note(p, size: 13.5, color: p.text1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
