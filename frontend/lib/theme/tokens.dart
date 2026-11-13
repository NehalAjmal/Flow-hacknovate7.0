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

/// A length of time in words, one format everywhere: "25 min", "1 h 05 min",
/// "2 h". The unit always follows its number after a space, so it never reads
/// as part of the number. [caps] is for all-caps captions, where a lone "H"
/// is hard to read: "1 HR 05 MIN" once upper-cased.
String flowDuration(int minutes, {bool caps = false}) {
  final m = minutes.abs();
  final h = m ~/ 60, r = m % 60;
  final hour = caps ? 'hr' : 'h';
  if (h == 0) return '$r min';
  if (r == 0) return '$h $hour';
  return '$h $hour ${r.toString().padLeft(2, '0')} min';
}

/// The same length of time as a display numeral: the numbers in the
/// instrument face, the units small and quiet beside them ("1 h 25 min").
/// In the display face an "h" set at full size reads as another digit.
List<InlineSpan> durationSpans(FlowPalette p, int minutes, double size, {Color? color}) {
  final m = minutes.abs();
  final h = m ~/ 60, r = m % 60;
  final num = FlowType.numeral(p, size, color: color);
  final unit = TextStyle(
    fontFamily: FlowFonts.ui,
    fontSize: (size * 0.4).clamp(9.0, 22.0),
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: color?.withValues(alpha: 0.75) ?? p.text2,
  );
  final gap = TextSpan(text: '\u2009', style: unit); // thin space
  return [
    if (h > 0) ...[TextSpan(text: '$h', style: num), gap, TextSpan(text: 'h', style: unit), TextSpan(text: ' ', style: unit)],
    if (h == 0 || r > 0) ...[
      TextSpan(text: h > 0 ? r.toString().padLeft(2, '0') : '$r', style: num),
      gap,
      TextSpan(text: 'min', style: unit),
    ],
  ];
}

class DurationNumeral extends StatelessWidget {
  const DurationNumeral(this.minutes, {super.key, required this.size, this.color});
  final int minutes;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(children: durationSpans(FlowPalette.of(context), minutes, size, color: color)),
    maxLines: 1,
    softWrap: false,
    semanticsLabel: flowDuration(minutes),
  );
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
    // One page motion everywhere, replacing each platform's default (the
    // Windows/Linux zoom is the loudest): a short fade with a small rise.
    pageTransitionsTheme: PageTransitionsTheme(builders: {for (final t in TargetPlatform.values) t: const FlowPageTransitions()}),
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

/// Incoming page: 180 ms fade + 6 px rise (FADE family, ease-out). The page
/// underneath fades out a little faster, so the two never sit at half opacity
/// over each other for long. No scale, no slide across: switching pages in
/// Flow is a change of view, not a journey.
class FlowPageTransitions extends PageTransitionsBuilder {
  const FlowPageTransitions();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 140);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final inCurve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    final outCurve = CurvedAnimation(
      parent: secondaryAnimation,
      curve: const Interval(0, 0.7, curve: Curves.easeIn),
    );
    return FadeTransition(
      opacity: ReverseAnimation(outCurve),
      child: FadeTransition(
        opacity: inCurve,
        child: AnimatedBuilder(
          animation: inCurve,
          child: child,
          builder: (context, child) => Transform.translate(offset: Offset(0, 6 * (1 - inCurve.value)), child: child),
        ),
      ),
    );
  }
}
