import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';

enum PressableTone {
  /// Neutral raised (chips, presets, secondary buttons).
  raised,

  /// The one filled action per view (dark neutral, never the accent).
  primary,
}

/// A tiny front-on solid with a 2 px lip (spec §2, control language).
///
/// Hover lifts 1 px (SNAP) · press sinks 2 px into the lip (FOLLOW) ·
/// release springs back (SNAP). No drop shadow: the lip is the depth.
/// Keyboard: focusable, Enter/Space activate; screen readers get a button.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.tone = PressableTone.raised,
    this.selected = false,
    this.radius = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    this.semanticLabel,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final PressableTone tone;

  /// Chosen state for chips/presets: dark neutral face, pressed in by 1 px.
  final bool selected;
  final double radius;
  final EdgeInsets padding;
  final String? semanticLabel;
  final String? tooltip;

  static const lip = 2.0;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final _y = SpringValue(vsync: this, initial: 0);
  bool _hover = false;
  bool _down = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  double get _rest => widget.selected ? 1 : 0;

  void _to(double v, {bool press = false}) {
    if (!mounted) return;
    _y.animateTo(v, spring: press ? Motion.follow : Motion.snap, reduced: Motion.reduced(context));
  }

  void _sync() {
    if (!_enabled) return _to(_rest);
    if (_down) return _to(Pressable.lip, press: true);
    if (_hover) return _to(widget.selected ? _rest : -1);
    _to(_rest);
  }

  @override
  void didUpdateWidget(Pressable old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _sync();
  }

  @override
  void dispose() {
    _y.dispose();
    super.dispose();
  }

  void _press(bool down) {
    _down = down;
    _sync();
  }

  void _activate() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final primary = widget.tone == PressableTone.primary || widget.selected;
    final face = !_enabled ? p.recess : (primary ? p.selected : p.raised);
    final lip = primary ? Faces.ground(face) : Color.lerp(p.hairline, p.text3, 0.25)!;
    final fg = !_enabled ? p.text3 : (primary ? p.onSelected : p.text1);
    final r = BorderRadius.circular(widget.radius);

    Widget body = AnimatedBuilder(
      animation: _y.animation,
      builder: (context, child) {
        final dy = _y.value.clamp(-1.0, Pressable.lip);
        return Padding(
          padding: const EdgeInsets.only(top: 1), // room for the hover lift
          child: Stack(
            children: [
              // the lip: what remains visible under the face
              Positioned.fill(
                top: Pressable.lip,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: lip, borderRadius: r),
                ),
              ),
              Transform.translate(
                offset: Offset(0, dy),
                child: Padding(
                  padding: EdgeInsets.only(bottom: Pressable.lip),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: face,
                      borderRadius: r,
                      border: primary ? null : Border.all(color: p.hairline, width: 1),
                    ),
                    child: Padding(padding: widget.padding, child: child),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w500),
        child: IconTheme.merge(
          data: IconThemeData(color: fg, size: 16),
          child: Center(widthFactor: 1, child: widget.child),
        ),
      ),
    );

    body = FocusableActionDetector(
      enabled: _enabled,
      mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowHoverHighlight: (h) {
        _hover = h;
        _sync();
      },
      onShowFocusHighlight: (f) => setState(() => _focused = f),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _activate())},
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _press(true) : null,
        onTapCancel: () => _press(false),
        onTapUp: _enabled ? (_) => _press(false) : null,
        onTap: _activate,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius + 2),
            border: _focused ? Border.all(color: p.accent, width: 1.5) : null,
          ),
          child: body,
        ),
      ),
    );

    body = Semantics(button: true, enabled: _enabled, selected: widget.selected, label: widget.semanticLabel, child: body);
    if (widget.tooltip != null) body = Tooltip(message: widget.tooltip!, child: body);
    return body;
  }
}
