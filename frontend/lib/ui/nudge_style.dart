import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../desktop/desktop_host.dart';
import '../desktop/window_controller.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'kit.dart';

String nudgeStyleTitle(NudgeStyle s) => switch (s) {
  NudgeStyle.fullScreen => 'Full screen',
  NudgeStyle.windowed => 'Windowed',
  NudgeStyle.notification => 'Notification',
};

String nudgeStyleBlurb(NudgeStyle s) => switch (s) {
  NudgeStyle.fullScreen => 'The suggestion takes the whole screen. Hard to miss; steps back by itself after a minute.',
  NudgeStyle.windowed => 'The same suggestion in a window that floats over your work.',
  NudgeStyle.notification => 'A small card in Flow, and a system notification when Flow is not in front.',
};

/// The three ways a break suggestion can arrive. The choice is kept on this
/// computer (it is about this screen), with the other window preferences.
class NudgeStyleOptions extends ConsumerWidget {
  const NudgeStyleOptions({super.key, this.axis = Axis.vertical});
  final Axis axis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final prefs = ref.watch(desktopPrefsProvider);
    Widget option(NudgeStyle s) => Pressable(
      selected: s == prefs.nudgeStyle,
      onPressed: () => ref.read(desktopPrefsProvider.notifier).set(prefs.copyWith(nudgeStyle: s)),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nudgeStyleTitle(s), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              nudgeStyleBlurb(s),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: s == prefs.nudgeStyle ? p.onSelected : p.text2),
            ),
          ],
        ),
      ),
    );
    if (axis == Axis.horizontal) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, s) in NudgeStyle.values.indexed) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: option(s))],
          ],
        ),
      );
    }
    return Column(
      children: [for (final s in NudgeStyle.values) Padding(padding: const EdgeInsets.only(bottom: 8), child: option(s))],
    );
  }
}

/// A little screen showing where the suggestion will appear for [style]:
/// over everything, as a window over your work, or as a card in the corner.
/// Switching style replays the arrival.
class NudgeStylePreview extends StatefulWidget {
  const NudgeStylePreview({super.key, required this.style, this.minutes = 5});
  final NudgeStyle style;
  final int minutes;

  @override
  State<NudgeStylePreview> createState() => _NudgeStylePreviewState();
}

class _NudgeStylePreviewState extends State<NudgeStylePreview> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100), value: 1);

  @override
  void didUpdateWidget(NudgeStylePreview old) {
    super.didUpdateWidget(old);
    if (old.style != widget.style && !Motion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Semantics(
      label: 'Preview: ${nudgeStyleTitle(widget.style)}. ${nudgeStyleBlurb(widget.style)}',
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: CustomPaint(painter: _PreviewPainter(p, widget.style, widget.minutes, _c, MediaQuery.textScalerOf(context))),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.p, this.style, this.minutes, this.anim, this.scaler) : super(repaint: anim);
  final FlowPalette p;
  final NudgeStyle style;
  final int minutes;
  final Animation<double> anim;
  final TextScaler scaler;

  @override
  void paint(Canvas c, Size s) {
    final t = anim.isCompleted ? 1.0 : Motion.settleAt(anim.value * 1.1, response: 0.55);
    final screen = RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(10));
    c.drawRRect(screen, Paint()..color = p.raised);
    c.save();
    c.clipRRect(screen);

    // your work underneath: a few lines of "text" in another app
    final work = Paint()..color = p.hairline;
    for (var i = 0; i < 7; i++) {
      final w = s.width * (0.34 + 0.4 * ((i * 37) % 10) / 10);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s.width * 0.07, s.height * (0.12 + i * 0.105), w, s.height * 0.035),
          const Radius.circular(2),
        ),
        work,
      );
    }

    // where the suggestion appears
    final Rect r = switch (style) {
      NudgeStyle.fullScreen => Offset.zero & s,
      NudgeStyle.windowed => Rect.fromCenter(center: s.center(Offset.zero), width: s.width * 0.6, height: s.height * 0.6),
      NudgeStyle.notification => Rect.fromLTWH(s.width * 0.62, s.height * 0.62, s.width * 0.33, s.height * 0.3),
    };
    if (style == NudgeStyle.windowed) c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF000000).withValues(alpha: 0.22 * t));

    // it pops in: scales up from 90% while fading (the notification rises)
    c.save();
    final rise = style == NudgeStyle.notification ? (1 - t) * s.height * 0.12 : 0.0;
    c.translate(r.center.dx, r.center.dy + rise);
    final k = style == NudgeStyle.fullScreen ? 1.0 : 0.9 + 0.1 * t;
    c.scale(k);
    c.translate(-r.center.dx, -r.center.dy);
    final alpha = t.clamp(0.0, 1.0);
    final panel = RRect.fromRectAndRadius(r, Radius.circular(style == NudgeStyle.fullScreen ? 0 : 6));
    if (style != NudgeStyle.fullScreen) {
      c.drawRRect(panel.shift(const Offset(0, 3)), Paint()..color = const Color(0xFF000000).withValues(alpha: 0.18 * alpha));
    }
    c.drawRRect(panel, Paint()..color = p.bg.withValues(alpha: alpha));
    c.save();
    c.clipRRect(panel);
    // the amber tide, to its line
    final level = r.bottom - r.height * 0.36 * t;
    c.drawRect(
      Rect.fromLTRB(r.left, level, r.right, r.bottom),
      Paint()..color = Color.lerp(p.amberTint, p.bg, 0.25)!.withValues(alpha: alpha),
    );
    final dash = Paint()
      ..color = p.amber.withValues(alpha: 0.8 * alpha)
      ..strokeWidth = 1;
    for (var x = r.left; x < r.right; x += 6) {
      c.drawLine(Offset(x, r.bottom - r.height * 0.36), Offset(math.min(x + 3, r.right), r.bottom - r.height * 0.36), dash);
    }
    // "Take 5?" and its buttons, in miniature
    final tp = TextPainter(
      text: TextSpan(
        text: 'Take $minutes?',
        style: FlowType.headline(
          p,
          size: (r.height * 0.2).clamp(8.0, 40.0),
          color: p.text1.withValues(alpha: alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: r.width * 0.86);
    tp.paint(c, Offset(r.left + r.width * 0.08, r.top + r.height * 0.2));
    final by = r.bottom - r.height * 0.22, bh = (r.height * 0.11).clamp(3.0, 14.0);
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(r.left + r.width * 0.08, by, r.width * 0.34, bh), const Radius.circular(2.5)),
      Paint()..color = p.selected.withValues(alpha: alpha),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(r.left + r.width * 0.46, by, r.width * 0.18, bh), const Radius.circular(2.5)),
      Paint()
        ..color = p.text3.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke,
    );
    c.restore();
    if (style != NudgeStyle.fullScreen) {
      c.drawRRect(
        panel,
        Paint()
          ..color = p.amber.withValues(alpha: 0.5 * alpha)
          ..style = PaintingStyle.stroke,
      );
    }
    c.restore();
    c.restore();
    c.drawRRect(
      screen,
      Paint()
        ..color = p.hairline
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_PreviewPainter o) => o.style != style || o.p != p || o.minutes != minutes || o.scaler != scaler;
}
