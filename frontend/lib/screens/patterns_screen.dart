import 'package:flutter/material.dart';
import '../widgets/flow_data_card.dart';
import '../core/theme.dart'; // Needed for warningAmber

class PatternsScreen extends StatelessWidget {
  const PatternsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Cognitive Patterns & DNA",
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),

          // ROW 1: Core DNA Stats
          Row(
            children: [
              Expanded(child: _buildDnaCard("PEAK WINDOW", "09:00", "to 11:30 AM", theme)),
              const SizedBox(width: 16),
              Expanded(child: _buildDnaCard("NATURAL CYCLE", "75", "minutes avg", theme)),
              const SizedBox(width: 16),
              Expanded(child: _buildDnaCard("BEST DAY", "Tuesday", "+14% focus var", theme)),
            ],
          ),
          const SizedBox(height: 16),

          // ROW 2: Focus by Hour (Custom Native Bar Chart)
          Expanded(
            flex: 3,
            child: FlowDataCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("FOCUS QUALITY BY HOUR", style: theme.textTheme.labelSmall),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildHourlyBar("8AM", 0.3, theme.primaryColor.withOpacity(0.4), theme),
                        _buildHourlyBar("9AM", 0.7, theme.primaryColor, theme),
                        _buildHourlyBar("10AM", 0.9, theme.primaryColor, theme),
                        _buildHourlyBar("11AM", 0.85, theme.primaryColor, theme),
                        _buildHourlyBar("12PM", 0.4, theme.primaryColor.withOpacity(0.6), theme),
                        _buildHourlyBar("1PM", 0.15, FlowTheme.warningAmber, theme), // Trough
                        _buildHourlyBar("2PM", 0.5, theme.primaryColor.withOpacity(0.8), theme),
                        _buildHourlyBar("3PM", 0.65, theme.primaryColor, theme),
                        _buildHourlyBar("4PM", 0.55, theme.primaryColor.withOpacity(0.8), theme),
                        _buildHourlyBar("5PM", 0.2, theme.dividerColor, theme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ROW 3: Trends & Learned Parameters
          Expanded(
            flex: 4,
            child: Row(
              children: [
                // 7-Day Trend (Custom Sparkline)
                Expanded(
                  flex: 3,
                  child: FlowDataCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("7-DAY TREND", style: theme.textTheme.labelSmall),
                        const SizedBox(height: 24),
                        Expanded(
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _TrendLinePainter(
                              lineColor: theme.primaryColor,
                              fillColor: theme.primaryColor.withOpacity(0.1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Mon", style: theme.textTheme.labelSmall),
                            Text("Wed", style: theme.textTheme.labelSmall),
                            Text("Fri", style: theme.textTheme.labelSmall),
                            Text("Sun", style: theme.textTheme.labelSmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Learned Parameters List
                Expanded(
                  flex: 4,
                  child: FlowDataCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.psychology_rounded, color: theme.primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Text("LEARNED PARAMETERS", style: theme.textTheme.labelSmall),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildParameterRow("HRV Baseline", "42ms", "Stable", theme),
                              _buildParameterRow("Difficulty Bias", "+12%", "Overestimates heavy tasks", theme),
                              _buildParameterRow("Context Recovery", "4.2 min", "Time to return to deep work", theme),
                              _buildParameterRow("Burnout Risk", "Low", "No flags in 14 days", theme, isHighlight: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDnaCard(String title, String mainValue, String subValue, ThemeData theme) {
    return FlowDataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: theme.textTheme.labelSmall),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(mainValue, style: theme.textTheme.displayLarge),
              const SizedBox(width: 6),
              Text(subValue, style: theme.textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyBar(String time, double heightRatio, Color color, ThemeData theme) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: FractionallySizedBox(
              heightFactor: heightRatio,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(time, style: theme.textTheme.labelSmall?.copyWith(fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildParameterRow(String label, String value, String description, ThemeData theme, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.labelSmall?.color)),
          ),
          Expanded(
            flex: 1,
            child: Text(
              value, 
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600, 
                color: isHighlight ? theme.primaryColor : theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(description, style: theme.textTheme.bodyMedium, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

// Custom Native Sparkline Graph Builder
class _TrendLinePainter extends CustomPainter {
  final Color lineColor;
  final Color fillColor;

  _TrendLinePainter({required this.lineColor, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Mock 7-day data points (0.0 to 1.0)
    final points = [0.4, 0.6, 0.5, 0.8, 0.7, 0.9, 0.85];
    
    final path = Path();
    final fillPath = Path();
    
    final widthStep = size.width / (points.length - 1);

    // Start coordinates
    path.moveTo(0, size.height - (points[0] * size.height));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, size.height - (points[0] * size.height));

    for (int i = 1; i < points.length; i++) {
      final x = i * widthStep;
      final y = size.height - (points[i] * size.height);
      
      // Smooth bezier curves
      final prevX = (i - 1) * widthStep;
      final prevY = size.height - (points[i - 1] * size.height);
      
      final controlPointX = prevX + (x - prevX) / 2;
      
      path.cubicTo(controlPointX, prevY, controlPointX, y, x, y);
      fillPath.cubicTo(controlPointX, prevY, controlPointX, y, x, y);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw Fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Draw Line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}