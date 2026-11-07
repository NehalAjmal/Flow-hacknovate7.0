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
    // no dependency: the scope's later value must not restart anything
    if (!AppearScope.animates(context)) {
      _c.value = 1;
      return;
    }
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


/// Entrances play on a page's first visit only. Going back to a page you've
/// seen shows it settled; replaying the cascade on every switch reads as
/// jitter, not as arrival. Decided once per visit, so content that arrives
/// after a first-visit load still animates in.
class AppearScope extends StatefulWidget {
  const AppearScope({super.key, required this.route, required this.child});
  final String route;
  final Widget child;

  static final _seen = <String>{};

  /// False on a revisit; true outside any scope (dialogs, signed-out pages).
  static bool animates(BuildContext context) => context.getInheritedWidgetOfExactType<_AppearFlag>()?.animate ?? true;

  @override
  State<AppearScope> createState() => _AppearScopeState();
}

class _AppearScopeState extends State<AppearScope> {
  String? _route;
  bool _animate = true;

  @override
  Widget build(BuildContext context) {
    if (_route != widget.route) {
      _route = widget.route;
      _animate = AppearScope._seen.add(widget.route);
    }
    return _AppearFlag(animate: _animate, child: widget.child);
  }
}

class _AppearFlag extends InheritedWidget {
  const _AppearFlag({required this.animate, required super.child});
  final bool animate;
  @override
  bool updateShouldNotify(_AppearFlag old) => false;
}
