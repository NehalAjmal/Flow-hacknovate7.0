import 'package:flutter/material.dart';

/// "Stone & Verdigris, ink drying". DESIGN_SPEC §16.
///
/// Colour carries meaning, never decoration:
/// - warm stone = the past, cool verdigris line-work = the future
/// - [accent] = NOW / active only (never "selected"; that is [selected])
/// - [ultra] (mist, a grey-green) = planned / not yet: schedules,
///   projections, the next block. Quiet line-work and faint washes only;
///   colour in Flow is atmosphere, never a loud second accent.
///   [ultraDeep] is the warm-stone brand field.
/// - [amber] = break soon / due
/// - [problem] = system problems only, never a person's state
@immutable
class FlowPalette extends ThemeExtension<FlowPalette> {
  const FlowPalette({
    required this.bg,
    required this.raised,
    required this.recess,
    required this.hairline,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.selected,
    required this.pastLight,
    required this.pastModerate,
    required this.pastHeavy,
    required this.accent,
    required this.accentTint,
    required this.accentDeep,
    required this.future,
    required this.ultra,
    required this.ultraTint,
    required this.ultraDeep,
    required this.amber,
    required this.amberTint,
    required this.problem,
  });

  final Color bg;
  final Color raised;
  final Color recess;
  final Color hairline;
  final Color text1;
  final Color text2;
  final Color text3;

  /// Dark neutral: active nav pill, lit pillar, segmented choice, Start button.
  final Color selected;

  /// Finished session blocks, by declared demand.
  final Color pastLight;
  final Color pastModerate;
  final Color pastHeavy;

  final Color accent;
  final Color accentTint;
  final Color accentDeep;

  /// Line-work for everything that has not happened yet (= [ultra]).
  final Color future;

  /// Mist: the quiet hue for planned / not yet.
  final Color ultra;
  final Color ultraTint;

  /// Brand field (sign-in stage): a deeper warm stone; normal ink on it.
  final Color ultraDeep;

  /// Paper-white text/strokes drawn on [ultraDeep].
  Color get onField => const Color(0xFFF4F2EC);

  final Color amber;
  final Color amberTint;
  final Color problem;

  List<Color> get pastByDemand => [pastLight, pastModerate, pastHeavy];

  /// Text/icons drawn on [selected].
  Color get onSelected => bg;

  static const light = FlowPalette(
    bg: Color(0xFFEEECE6),
    raised: Color(0xFFF7F6F2),
    recess: Color(0xFFE2DFD7),
    hairline: Color(0xFFCFCBC1),
    text1: Color(0xFF1F201D),
    text2: Color(0xFF585A54),
    text3: Color(0xFF7D7E77),
    selected: Color(0xFF262724),
    pastLight: Color(0xFFD3C8B4),
    pastModerate: Color(0xFFB09F84),
    pastHeavy: Color(0xFF7D6C55),
    accent: Color(0xFF0B8A70),
    accentTint: Color(0xFFCFEFE6),
    accentDeep: Color(0xFF06604E),
    future: Color(0xFF6F8580),
    ultra: Color(0xFF6F8580),
    ultraTint: Color(0xFFE3E7E4),
    ultraDeep: Color(0xFFE3DED3),
    amber: Color(0xFFB06E00),
    amberTint: Color(0xFFF6E2BC),
    problem: Color(0xFF9A4436),
  );

  static const dark = FlowPalette(
    bg: Color(0xFF161816),
    raised: Color(0xFF1F221F),
    recess: Color(0xFF0F110F),
    hairline: Color(0xFF313531),
    text1: Color(0xFFE9ECE6),
    text2: Color(0xFFA2A79E),
    text3: Color(0xFF6F746C),
    selected: Color(0xFFE4E8E0),
    pastLight: Color(0xFF3D362C),
    pastModerate: Color(0xFF5E5243),
    pastHeavy: Color(0xFF8C7B62),
    accent: Color(0xFF3FE0B8),
    accentTint: Color(0xFF123A31),
    accentDeep: Color(0xFF8AF0D6),
    future: Color(0xFF7F9590),
    ultra: Color(0xFF7F9590),
    ultraTint: Color(0xFF1C211F),
    ultraDeep: Color(0xFF1F221E),
    amber: Color(0xFFFFB733),
    amberTint: Color(0xFF3A2A0E),
    problem: Color(0xFFDB7E69),
  );

  static FlowPalette of(BuildContext context) => Theme.of(context).extension<FlowPalette>() ?? light;

  /// "Ink drying": a finished block drifts from accent to its stone shade
  /// over [dryingTime] after it ends.
  static const dryingTime = Duration(minutes: 10);

  Color drying(Color stone, Duration sinceEnd) {
    final t = (sinceEnd.inMilliseconds / dryingTime.inMilliseconds).clamp(0.0, 1.0);
    return Color.lerp(accent, stone, Curves.easeOut.transform(t))!;
  }

  @override
  FlowPalette copyWith() => this;

  @override
  FlowPalette lerp(FlowPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FlowPalette(
      bg: l(bg, other.bg),
      raised: l(raised, other.raised),
      recess: l(recess, other.recess),
      hairline: l(hairline, other.hairline),
      text1: l(text1, other.text1),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      selected: l(selected, other.selected),
      pastLight: l(pastLight, other.pastLight),
      pastModerate: l(pastModerate, other.pastModerate),
      pastHeavy: l(pastHeavy, other.pastHeavy),
      accent: l(accent, other.accent),
      accentTint: l(accentTint, other.accentTint),
      accentDeep: l(accentDeep, other.accentDeep),
      future: l(future, other.future),
      ultra: l(ultra, other.ultra),
      ultraTint: l(ultraTint, other.ultraTint),
      ultraDeep: l(ultraDeep, other.ultraDeep),
      amber: l(amber, other.amber),
      amberTint: l(amberTint, other.amberTint),
      problem: l(problem, other.problem),
    );
  }
}

/// 3D face shading, one light direction app-wide (top-left).
/// Values from the spec: top +22% toward white, side −18%, grounding edge −35%.
abstract final class Faces {
  static Color top(Color c) => Color.lerp(c, const Color(0xFFFFFFFF), 0.22)!;
  static Color side(Color c) => Color.lerp(c, const Color(0xFF000000), 0.18)!;
  static Color ground(Color c) => Color.lerp(c, const Color(0xFF000000), 0.35)!;
}
