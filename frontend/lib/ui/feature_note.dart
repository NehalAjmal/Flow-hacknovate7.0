import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A coloured ground that gives a screen its character. Colour = meaning:
/// [FieldTone.planned] ultramarine (not yet / about to start),
/// [FieldTone.now] verdigris (running), [FieldTone.rest] amber (break),
/// [FieldTone.past] warm stone (what happened).
enum FieldTone { planned, now, rest, past, brand }

class ColorField extends StatelessWidget {
  const ColorField({super.key, required this.tone, required this.child, this.padding = const EdgeInsets.all(22), this.radius = 20});
  final FieldTone tone;
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  /// Washes, not panels: each tone is mostly the ground with a hint of its
  /// meaning-colour, so colour reads as atmosphere rather than decoration.
  static Color colorOf(FlowPalette p, FieldTone t) => switch (t) {
    FieldTone.planned => Color.lerp(p.ultraTint, p.bg, 0.25)!,
    FieldTone.now => Color.lerp(p.accentTint, p.bg, 0.55)!,
    FieldTone.rest => Color.lerp(p.amberTint, p.bg, 0.45)!,
    FieldTone.past => Color.lerp(p.pastLight, p.bg, 0.62)!,
    FieldTone.brand => p.ultraDeep,
  };

  static Color edgeOf(FlowPalette p, FieldTone t) => switch (t) {
    FieldTone.planned => p.ultra.withValues(alpha: 0.2),
    FieldTone.now => p.accent.withValues(alpha: 0.22),
    FieldTone.rest => p.amber.withValues(alpha: 0.22),
    FieldTone.past => p.pastModerate.withValues(alpha: 0.3),
    FieldTone.brand => p.hairline,
  };

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colorOf(p, tone),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: edgeOf(p, tone)),
      ),
      child: child,
    );
  }
}

/// Explains one piece of functionality: a numbered ring, a
/// short title in the UI voice, and one or two lines in Flow's own voice.
/// Used on Welcome, in the guide, and in Home's "explain this screen" layer.
class FeatureNote extends StatelessWidget {
  const FeatureNote({super.key, required this.number, required this.title, required this.body, this.onField = false, this.compact = false});
  final int number;
  final String title;
  final String body;

  /// On the deep ultramarine field (paper text).
  final bool onField;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final ink = onField ? p.onField : p.text1;
    final sub = onField ? p.onField.withValues(alpha: 0.8) : p.text2;
    final marker = onField ? p.onField : p.text2;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 22 : 26,
          height: compact ? 22 : 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: marker, width: 1.4),
          ),
          child: Text(
            '$number',
            style: TextStyle(fontFamily: FlowFonts.mono, fontSize: compact ? 10.5 : 12, fontWeight: FontWeight.w500, color: marker),
          ),
        ),
        SizedBox(width: compact ? 10 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: ink, fontSize: compact ? 12.5 : 13.5, fontWeight: FontWeight.w600),
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  body,
                  style: FlowType.note(p, size: compact ? 13 : 14, color: sub),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A small floating caption for the explain layer: ultramarine tab with a
/// number, sits above the thing it explains.
class ExplainCaption extends StatelessWidget {
  const ExplainCaption({super.key, required this.number, required this.title, required this.body});
  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10, right: 24),
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(
        color: p.raised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.hairline),
      ),
      child: FeatureNote(number: number, title: title, body: body, compact: true),
    );
  }
}
