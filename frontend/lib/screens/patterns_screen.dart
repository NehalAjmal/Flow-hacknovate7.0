// lib/screens/patterns_screen.dart
//
// Additions vs original:
//   • Week-over-week comparison card (This week vs Last week, 4 metrics)
//   • 3-day predicted peak forecast (Tomorrow + Day after + Day +3)
//   • Both use the existing _TrendLinePainter and FlowDataCard primitives
//   • All original sections preserved below the new ones

import 'package:flutter/material.dart';
import '../widgets/flow_data_card.dart';
import '../core/theme.dart';

class PatternsScreen extends StatelessWidget {
  const PatternsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Text('PATTERNS', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text('Cognitive Intelligence Report',
              style: theme.textTheme.displayMedium),
          const SizedBox(height: 32),

          // ── ROW 1: Week-over-week + 3-day forecast (NEW) ───────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildWeekOverWeek(theme, context)),
              const SizedBox(width: 24),
              Expanded(child: _buildPeakForecast(theme, context)),
            ],
          ),
          const SizedBox(height: 24),

          // ── ROW 2: Trend line + ultradian stats (ORIGINAL) ─────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildTrendCard(theme)),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: _buildUltradianStats(theme)),
            ],
          ),
          const SizedBox(height: 24),

          // ── ROW 3: Pattern table (ORIGINAL) ─────────────────────────────
          _buildPatternTable(theme, context),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // NEW: Week-over-week comparison
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildWeekOverWeek(ThemeData theme, BuildContext context) {
    final primaryColor = theme.primaryColor;
    final fatigueColor = FlowTheme.stateColor(context, SessionState.trough);
    final driftColor   = FlowTheme.stateColor(context, SessionState.drift);

    final metrics = [
      _WowMetric(
        label:        'FOCUS SCORE AVG',
        thisWeek:     82,
        lastWeek:     74,
        suffix:       '%',
        improvColor:  primaryColor,
      ),
      _WowMetric(
        label:        'DEEP WORK / DAY',
        thisWeek:     134, // minutes
        lastWeek:     109,
        suffix:       'm',
        improvColor:  primaryColor,
      ),
      _WowMetric(
        label:        'DRIFT EVENTS',
        thisWeek:     4,
        lastWeek:     7,
        suffix:       '',
        improvColor:  fatigueColor,
        lowerIsBetter: true,
      ),
      _WowMetric(
        label:        'INTERVENTIONS',
        thisWeek:     2,
        lastWeek:     5,
        suffix:       '',
        improvColor:  driftColor,
        lowerIsBetter: true,
      ),
    ];

    return FlowDataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WEEK OVER WEEK', style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text('vs last 7 days',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.labelSmall?.color)),
          const SizedBox(height: 20),
          ...metrics.map((m) => _buildWowRow(m, theme)),
        ],
      ),
    );
  }

  Widget _buildWowRow(_WowMetric m, ThemeData theme) {
    final delta      = m.thisWeek - m.lastWeek;
    final improved   = m.lowerIsBetter ? delta < 0 : delta > 0;
    final deltaLabel = (delta > 0 ? '+' : '') + delta.toString() + m.suffix;
    final arrowIcon  = improved
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final deltaColor = improved
        ? theme.primaryColor
        : theme.colorScheme.error;

    // Bar widths
    final maxVal   = [m.thisWeek, m.lastWeek].reduce((a, b) => a > b ? a : b);
    final thisW    = maxVal > 0 ? m.thisWeek / maxVal : 0.0;
    final lastW    = maxVal > 0 ? m.lastWeek / maxVal : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(m.label, style: theme.textTheme.labelSmall),
              Row(
                children: [
                  Icon(arrowIcon, size: 12, color: deltaColor),
                  const SizedBox(width: 4),
                  Text(deltaLabel,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: deltaColor, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // This week bar
          Row(
            children: [
              SizedBox(
                  width: 60,
                  child: Text('This wk',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.textTheme.labelSmall?.color,
                              fontSize: 10))),
              Expanded(
                child: Stack(children: [
                  Container(
                      height: 6,
                      decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(3))),
                  FractionallySizedBox(
                    widthFactor: thisW.clamp(0.0, 1.0),
                    child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.circular(3))),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              SizedBox(
                  width: 40,
                  child: Text('${m.thisWeek}${m.suffix}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.right)),
            ],
          ),
          const SizedBox(height: 4),
          // Last week bar
          Row(
            children: [
              SizedBox(
                  width: 60,
                  child: Text('Last wk',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.labelSmall?.color,
                          fontSize: 10))),
              Expanded(
                child: Stack(children: [
                  Container(
                      height: 6,
                      decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(3))),
                  FractionallySizedBox(
                    widthFactor: lastW.clamp(0.0, 1.0),
                    child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                            color: theme.dividerColor.withValues(alpha: 0.0),
                            border: Border.all(
                                color: theme.textTheme.labelSmall?.color ??
                                    Colors.grey,
                                width: 1),
                            borderRadius: BorderRadius.circular(3))),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              SizedBox(
                  width: 40,
                  child: Text('${m.lastWeek}${m.suffix}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.textTheme.labelSmall?.color),
                      textAlign: TextAlign.right)),
            ],
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // NEW: 3-day predicted peak forecast
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildPeakForecast(ThemeData theme, BuildContext context) {
    final primaryColor = theme.primaryColor;
    final fatigueColor = FlowTheme.stateColor(context, SessionState.trough);

    // Each day: label + list of {time, strength, label, color}
    final days = [
      _ForecastDay(
        dayLabel: 'Tomorrow',
        dateLabel: 'Sat 6 Apr',
        windows: [
          _Window('9:00',  0.91, 'Peak — highest of the day', primaryColor),
          _Window('11:30', 0.35, 'Trough — take a break',     fatigueColor),
          _Window('14:15', 0.70, 'Second peak window',         primaryColor),
          _Window('16:00', 0.20, 'End-of-day trough',          fatigueColor),
        ],
      ),
      _ForecastDay(
        dayLabel: 'Day after',
        dateLabel: 'Sun 7 Apr',
        windows: [
          _Window('8:30',  0.85, 'Peak — start early',    primaryColor),
          _Window('10:45', 0.40, 'Trough',                 fatigueColor),
          _Window('13:00', 0.62, 'Moderate window',        primaryColor),
        ],
      ),
      _ForecastDay(
        dayLabel: 'Day +3',
        dateLabel: 'Mon 8 Apr',
        windows: [
          _Window('9:15',  0.89, 'Strong peak',            primaryColor),
          _Window('11:00', 0.30, 'Trough',                 fatigueColor),
          _Window('14:30', 0.74, 'Afternoon peak',         primaryColor),
          _Window('17:00', 0.15, 'Wrap-up window',         fatigueColor),
        ],
      ),
    ];

    return FlowDataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('PREDICTED PEAK FORECAST',
                  style: theme.textTheme.labelSmall),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: primaryColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 11, color: primaryColor),
                    const SizedBox(width: 4),
                    Text('AI MODEL',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: primaryColor, fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Based on your personal rhythm · 3-day window',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.labelSmall?.color)),
          const SizedBox(height: 20),
          ...days.map((day) => _buildForecastDay(day, theme)),
        ],
      ),
    );
  }

  Widget _buildForecastDay(_ForecastDay day, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(day.dayLabel,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Text(day.dateLabel,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.textTheme.labelSmall?.color)),
            ],
          ),
          const SizedBox(height: 10),
          ...day.windows.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  SizedBox(
                      width: 44,
                      child: Text(w.time,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.labelSmall?.color,
                              fontSize: 11))),
                  Expanded(
                    child: Stack(children: [
                      Container(
                          height: 8,
                          decoration: BoxDecoration(
                              color: theme.dividerColor,
                              borderRadius: BorderRadius.circular(4))),
                      FractionallySizedBox(
                        widthFactor: w.strength,
                        child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                                color: w.color,
                                borderRadius: BorderRadius.circular(4))),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                      width: 140,
                      child: Text(w.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: w.color,
                              fontWeight: FontWeight.w500,
                              fontSize: 11),
                          textAlign: TextAlign.right)),
                ],
              ),
            ),
          ),
          Divider(color: theme.dividerColor),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ORIGINAL sections below — preserved unchanged
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildTrendCard(ThemeData theme) {
    return FlowDataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('7-DAY FOCUS TREND', style: theme.textTheme.labelSmall),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: const Size(double.infinity, 120),
              painter: _TrendLinePainter(
                lineColor: theme.primaryColor,
                fillColor:
                    theme.primaryColor.withValues(alpha: 0.08),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((d) => Text(d,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.labelSmall?.color,
                        fontSize: 11)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUltradianStats(ThemeData theme) {
    return FlowDataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ULTRADIAN PROFILE', style: theme.textTheme.labelSmall),
          const SizedBox(height: 20),
          _buildProfileRow('Personal cycle',  '92 min', 'Measured over 14 sessions', theme, isHighlight: true),
          _buildProfileRow('Peak avg',        '87%',    'Focus score during peaks', theme, isHighlight: true),
          _buildProfileRow('Trough avg',      '38%',    'Focus score during troughs', theme),
          _buildProfileRow('Best hour',       '9 AM',   'Consistent across all days', theme, isHighlight: true),
          _buildProfileRow('Recovery speed',  'Fast',   'Returns to peak within 11 min', theme),
          _buildProfileRow('Pattern accuracy','91%',    'Model confidence this week', theme),
        ],
      ),
    );
  }

  Widget _buildProfileRow(
      String label, String value, String description, ThemeData theme,
      {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                flex: 2,
                child: Text(label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.labelSmall?.color))),
            Expanded(
                flex: 1,
                child: Text(value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isHighlight
                          ? theme.primaryColor
                          : theme.textTheme.bodyLarge?.color,
                    ))),
            Expanded(
                flex: 3,
                child: Text(description,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.right)),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternTable(ThemeData theme, BuildContext context) {
    final driftColor = FlowTheme.stateColor(context, SessionState.drift);
    return FlowDataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BEHAVIORAL PATTERNS', style: theme.textTheme.labelSmall),
          const SizedBox(height: 20),
          _buildProfileRow('Morning drift events',    '1.2 / day', 'Down 40% this week', theme, isHighlight: true),
          _buildProfileRow('Slack-induced breaks',    '3.4 / day', 'Primary drift trigger', theme),
          _buildProfileRow('Deep work blocks',        '4.2 / day', 'Up 23% vs last week', theme, isHighlight: true),
          _buildProfileRow('Avg session length',      '52 min',    'Closest to your target', theme),
          _buildProfileRow('Focus recovery time',     '8 min',     'After interruption', theme),
        ],
      ),
    );
  }
}

// ─── Data models ──────────────────────────────────────────────────────────────

class _WowMetric {
  final String label;
  final int    thisWeek;
  final int    lastWeek;
  final String suffix;
  final Color  improvColor;
  final bool   lowerIsBetter;

  _WowMetric({
    required this.label,
    required this.thisWeek,
    required this.lastWeek,
    required this.suffix,
    required this.improvColor,
    this.lowerIsBetter = false,
  });
}

class _ForecastDay {
  final String         dayLabel;
  final String         dateLabel;
  final List<_Window>  windows;
  _ForecastDay(
      {required this.dayLabel,
      required this.dateLabel,
      required this.windows});
}

class _Window {
  final String time;
  final double strength;
  final String label;
  final Color  color;
  _Window(this.time, this.strength, this.label, this.color);
}

// ─── Trend line painter (unchanged from original) ─────────────────────────────

class _TrendLinePainter extends CustomPainter {
  final Color lineColor;
  final Color fillColor;
  _TrendLinePainter({required this.lineColor, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    final points = [0.4, 0.6, 0.5, 0.8, 0.7, 0.9, 0.85];
    final path     = Path();
    final fillPath = Path();
    final widthStep = size.width / (points.length - 1);

    path.moveTo(0, size.height - (points[0] * size.height));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, size.height - (points[0] * size.height));

    for (int i = 1; i < points.length; i++) {
      final x  = i * widthStep;
      final y  = size.height - (points[i] * size.height);
      final px = (i - 1) * widthStep;
      final py = size.height - (points[i - 1] * size.height);
      final cx = px + (x - px) / 2;
      path.cubicTo(cx, py, cx, y, x, y);
      fillPath.cubicTo(cx, py, cx, y, x, y);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath,
        Paint()..color = fillColor..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color       = lineColor
          ..strokeWidth = 3
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}