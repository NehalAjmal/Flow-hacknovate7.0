import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

/// One "why" factor: its share of the combined score (0..1).
typedef WhyBar = ({String name, double share});

/// The nudge, as one presentational card (spec §3 nudge choreography).
/// Used by the live intervention card and by the guide's preview/practice.
/// Head in the instrument voice, message in Flow's own voice (Cutive).
class NudgeCardView extends StatelessWidget {
  const NudgeCardView({
    super.key,
    required this.message,
    this.reason,
    this.breakMinutes = 5,
    this.onBreak,
    this.snoozeOptions = const [5, 10, 20],
    this.onSnooze,
    this.onDismiss,
    this.onWhy,
    this.onReport,
    this.why,
    this.note,
  });

  final String message;

  /// Shown up front in "explained" delivery; otherwise behind Why?.
  final String? reason;
  final int breakMinutes;
  final VoidCallback? onBreak;
  final List<int> snoozeOptions;
  final ValueChanged<int>? onSnooze;
  final VoidCallback? onDismiss;
  final VoidCallback? onWhy;
  final VoidCallback? onReport;

  /// When non-null the card shows the contribution bars (Why? expanded).
  final List<WhyBar>? why;

  /// Transient line under the actions ("snoozed 10 m").
  final String? note;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Break suggestion',
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          color: p.raised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.hairline),
          boxShadow: [BoxShadow(color: Faces.ground(p.raised).withValues(alpha: 0.6), offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: p.amber, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Text('Take $breakMinutes?', style: FlowType.headline(p, size: 26)),
                const Spacer(),
                if (onReport != null)
                  IconButton(
                    tooltip: 'This nudge was wrong',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.flag_outlined, size: 16, color: p.text3),
                    onPressed: onReport,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message, style: FlowType.note(p, size: 14.5, color: p.text1)),
            if (reason != null && reason!.isNotEmpty) ...[const SizedBox(height: 4), Text(reason!, style: FlowType.note(p, size: 13))],
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              child: why == null ? const SizedBox(width: double.infinity) : _WhyBars(bars: why!),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Pressable(
                  tone: PressableTone.primary,
                  onPressed: onBreak,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Text('Take a $breakMinutes min break'),
                ),
                if (onSnooze != null)
                  MenuAnchor(
                    builder: (c, ctl, _) => Pressable(
                      onPressed: () => ctl.isOpen ? ctl.close() : ctl.open(),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      child: const Text('Snooze'),
                    ),
                    menuChildren: [for (final m in snoozeOptions) MenuItemButton(onPressed: () => onSnooze!(m), child: Text('$m min'))],
                  ),
                if (onDismiss != null) _Quiet('Dismiss', onDismiss!),
                if (onWhy != null) _Quiet(why == null ? 'Why?' : 'Hide why', onWhy!),
              ],
            ),
            if (note != null) ...[const SizedBox(height: 8), Text(note!, style: FlowType.label(p, size: 10, color: p.text3))],
          ],
        ),
      ),
    );
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet(this.label, this.onPressed);
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: p.text2,
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: const TextStyle(fontFamily: FlowFonts.ui, fontSize: 13),
      ),
      child: Text(label),
    );
  }
}

/// Contribution bars rising from their baseline (SETTLE, staggered).
class _WhyBars extends StatefulWidget {
  const _WhyBars({required this.bars});
  final List<WhyBar> bars;

  @override
  State<_WhyBars> createState() => _WhyBarsState();
}

class _WhyBarsState extends State<_WhyBars> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Motion.enter(context, _c, () => mounted);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, b) in widget.bars.indexed) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${(b.share * 100).round()}%', style: FlowType.chart(p, size: 11, color: p.text1)),
                    const SizedBox(height: 4),
                    Container(
                      height: 4 + 46 * b.share * (_c.isCompleted ? 1 : Motion.settleAt(_c.value * 0.9 - i * 0.035)),
                      decoration: BoxDecoration(
                        color: i == 0 ? p.pastHeavy : p.pastModerate,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                      ),
                    ),
                    Container(height: 1, color: p.text3),
                    const SizedBox(height: 4),
                    Text(b.name, style: TextStyle(fontSize: 11.5, color: p.text2), maxLines: 2),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
