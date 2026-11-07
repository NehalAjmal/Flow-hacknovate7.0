import 'package:flutter/material.dart';

import 'palette.dart';

export 'palette.dart';

/// Font families. Three voices, never mixed inside one line:
///  * [instrument] OffBit 101: wordmark, big numbers, headlines. Only at
///    [instrumentMin] px and up; below that it stops reading as letters.
///  * [notYet] OffBit Dot: same skeleton as 101, used for things that have not
///    happened yet (scheduled times, countdown before a start). Rule L in type.
///  * [ui] Sono: controls, labels, read-outs. [mono] for small tabular numbers.
///  * [note] Cutive: Flow speaking to you (nudges, insights, guide, summary).
abstract final class FlowFonts {
  static const instrument = 'OffBit';
  static const notYet = 'OffBitDot';
  static const ui = 'Sono';
  static const mono = 'SonoMono';
  static const note = 'Cutive';
  static const double instrumentMin = 20;
}

/// App-wide type step (+10%) on top of the OS text scale.
class FlowTextScaler extends TextScaler {
  const FlowTextScaler(this.base, {this.factor = 1.1});
  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  bool operator ==(Object other) => other is FlowTextScaler && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}

/// Upper-cases a label but keeps the product name as "Flow" (capital F only).
String flowCaps(String s) => s.toUpperCase().replaceAll('FLOW', 'Flow');

/// Typography (Rule E: slim).
abstract final class FlowType {
  static const tabular = [FontFeature.tabularFigures()];

  /// Big numerals (timers, margin numbers). OffBit at [FlowFonts.instrumentMin]
  /// and above, SonoMono below. OffBit digits are proportional: for values that
  /// tick, render through [TabularNumeral] so the row does not jiggle.
  static TextStyle numeral(FlowPalette p, double size, {bool notYet = false, Color? color}) => size >= FlowFonts.instrumentMin
      ? TextStyle(
          fontFamily: notYet ? FlowFonts.notYet : FlowFonts.instrument,
          fontSize: size,
          fontWeight: FontWeight.w400,
          height: 1.0,
          letterSpacing: -0.01 * size,
          color: color ?? p.text1,
        )
      : TextStyle(
          fontFamily: FlowFonts.mono,
          fontSize: size,
          fontWeight: FontWeight.w300,
          height: 1.0,
          color: color ?? p.text1,
          fontFeatures: tabular,
        );

  /// Headline in the instrument voice (screen titles, card heads).
  static TextStyle headline(FlowPalette p, {double size = 24, bool bold = true, Color? color}) => TextStyle(
    fontFamily: FlowFonts.instrument,
    fontSize: size < FlowFonts.instrumentMin ? FlowFonts.instrumentMin : size,
    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    height: 1.05,
    color: color ?? p.text1,
  );

  /// Letter-spaced small caps for read-outs and section labels.
  static TextStyle label(FlowPalette p, {double size = 10.5, Color? color}) => TextStyle(
    fontFamily: FlowFonts.ui,
    fontSize: size,
    fontWeight: FontWeight.w500,
    letterSpacing: size * 0.14,
    color: color ?? p.text2,
    fontFeatures: tabular,
  );

  /// Small numbers in charts and painters (TextPainter does not inherit the theme).
  static TextStyle chart(FlowPalette p, {double size = 9.5, Color? color, FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontFamily: FlowFonts.mono, fontSize: size, fontWeight: weight, color: color ?? p.text3, fontFeatures: tabular);

  /// Flow's own voice. Cutive's lowercase runs large, so it sits 1 px under UI size.
  static TextStyle note(FlowPalette p, {double size = 14, Color? color}) =>
      TextStyle(fontFamily: FlowFonts.note, fontSize: size - 1, height: 1.5, color: color ?? p.text2);
}

/// Fixed-width digit cells for OffBit numbers that change (timers, dial value),
/// since the face has no tabular figures. Non-digits keep their natural width.
class TabularNumeral extends StatelessWidget {
  const TabularNumeral(this.text, {super.key, required this.style, this.semanticsLabel});
  final String text;
  final TextStyle style;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 14;
    final cell = size * (style.fontWeight == FontWeight.w700 ? 0.66 : 0.56);
    return Semantics(
      label: semanticsLabel ?? text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final ch in text.split(''))
            if (RegExp(r'\d').hasMatch(ch))
              SizedBox(
                width: cell,
                child: Text(ch, style: style, textAlign: TextAlign.center),
              )
            else
              Text(ch, style: style),
        ],
      ),
    );
  }
}

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? FlowPalette.dark : FlowPalette.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.selected,
    onPrimary: p.onSelected,
    secondary: p.accent,
    onSecondary: p.bg,
    tertiary: p.amber,
    onTertiary: p.bg,
    error: p.problem,
    onError: p.bg,
    surface: p.bg,
    onSurface: p.text1,
    onSurfaceVariant: p.text2,
    surfaceContainerLowest: p.recess,
    surfaceContainerLow: p.raised,
    surfaceContainer: p.raised,
    surfaceContainerHigh: p.raised,
    surfaceContainerHighest: p.recess,
    outline: p.hairline,
    outlineVariant: p.hairline,
  );
  // Sono everywhere by default; the instrument voice takes display/headline/titleLarge.
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness, fontFamily: FlowFonts.ui);
  TextStyle? inst(TextStyle? t, {FontWeight w = FontWeight.w400}) =>
      t?.copyWith(fontFamily: FlowFonts.instrument, fontWeight: w, letterSpacing: 0, height: 1.05);
  final text = base.textTheme
      .apply(bodyColor: p.text1, displayColor: p.text1)
      .copyWith(
        displayLarge: inst(base.textTheme.displayLarge),
        displayMedium: inst(base.textTheme.displayMedium),
        displaySmall: inst(base.textTheme.displaySmall),
        headlineLarge: inst(base.textTheme.headlineLarge),
        headlineMedium: inst(base.textTheme.headlineMedium),
        headlineSmall: inst(base.textTheme.headlineSmall),
        titleLarge: inst(base.textTheme.titleLarge),
      );
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    dividerColor: p.hairline,
    textTheme: text,
    splashFactory: NoSplash.splashFactory, // depth comes from the press physics, not ink
    hoverColor: p.text1.withValues(alpha: 0.04),
    focusColor: p.accent.withValues(alpha: 0.18),
    extensions: [p],
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(color: p.selected, borderRadius: BorderRadius.circular(6)),
      textStyle: TextStyle(fontFamily: FlowFonts.ui, color: p.onSelected, fontSize: 12),
    ),
  );
}
