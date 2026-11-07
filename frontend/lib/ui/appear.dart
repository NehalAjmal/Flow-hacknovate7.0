import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

/// First-appearance motion for 2D content: fades in (FADE) while rising a few
/// pixels into place (SETTLE closed form). [index] staggers by STAGGER steps.
/// Reduced motion: shown immediately.
class Appear extends StatefulWidget {
  const Appear({super.key, required this.child, this.index = 0, this.offset = 8});
  final Widget child;
  final int index;
  final double offset;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 700 + widget.index * 35),
  );

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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final secs = _c.value * (_c.duration!.inMilliseconds / 1000) - widget.index * Motion.staggerStep.inMilliseconds / 1000;
      final t = _c.isCompleted ? 1.0 : Motion.settleAt(secs);
      return Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * widget.offset), child: child),
      );
    },
  );
}
