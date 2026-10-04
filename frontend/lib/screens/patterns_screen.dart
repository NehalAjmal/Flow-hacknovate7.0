import 'package:flutter/material.dart';
import 'dart:math';
import '../api_service.dart';
import '../core/models.dart';

class PatternsScreen extends StatefulWidget {
  const PatternsScreen({super.key});

  @override
  State<PatternsScreen> createState() => _PatternsScreenState();
}

class _PatternsScreenState extends State<PatternsScreen> {
  bool _isLoading = true;
  String? _error;
  PatternsData? _patterns;
  late Future<Map<String, dynamic>> _focusDnaFuture;
  final List<double> _heatmapData = List.generate(28, (index) => Random().nextDouble());

  @override
  void initState() {
    super.initState();
    _focusDnaFuture = ApiService.focusDna();
    _fetchPatterns();
  }

  Future<void> _fetchPatterns() async {
    setState(() {
      _isLoading = _patterns == null;
      _error = null;
    });
    try {
      final data = await ApiService.userPatterns();
      if (!mounted) return;
      setState(() {
        _patterns = PatternsData.fromJson(data);
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load your patterns.';
      });
    }
  }

  void _retryFocusDna() {
    setState(() => _focusDnaFuture = ApiService.focusDna());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState(context)
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(context),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 320,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 3, child: _buildPeakHoursChart(context)),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  Expanded(child: _buildCycleCard(context)),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(child: _buildStatPill(context, _weeklySessionCount().toString(), "Sessions / week")),
                                      const SizedBox(width: 8),
                                      Expanded(child: _buildStatPill(context, _avgWeeklyScore(), "Avg focus", isWarning: false)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildInsightsCard(context),
                      const SizedBox(height: 14),
                      _buildHeatmapCard(context),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart_rounded, size: 40, color: Theme.of(context).textTheme.bodySmall?.color),
          const SizedBox(height: 16),
          Text('Patterns unavailable', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchPatterns,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
          ),
        ],
      ),
    );
  }

  int _weeklySessionCount() {
    if (_patterns == null) return 0;
    return _patterns!.weeklyTrends.fold(0, (sum, p) => sum + (p.value > 0 ? 1 : 0));
  }

  String _avgWeeklyScore() {
    if (_patterns == null) return '—';
    final scored = _patterns!.weeklyTrends.where((p) => p.value > 0).toList();
    if (scored.isEmpty) return '—';
    final avg = scored.fold<int>(0, (s, p) => s + p.value) / scored.length;
    return '${avg.round()}%';
  }

  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("YOUR COGNITIVE PROFILE",
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6))),
            const SizedBox(height: 2),
            Text("Patterns & Insights", style: theme.textTheme.headlineLarge),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Text('LAST 7 DAYS',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color,
              )),
        ),
      ],
    );
  }

  Widget _buildPeakHoursChart(BuildContext context) {
    final theme = Theme.of(context);
    final hourly = _patterns?.hourlyQuality ?? [];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor, width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Focus by hour", style: theme.textTheme.headlineSmall),
                _buildTag(context, "Peak: ${_patterns?.peakHoursLabel ?? '—'}", isGreen: true),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: hourly.isEmpty
                  ? Center(
                      child: Text(
                        'Complete a few sessions and your hourly focus profile will appear here.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: hourly.map((point) {
                        final h = (point.value / 100).clamp(0.05, 1.0).toDouble();
                        final color = theme.primaryColor;
                        final opacity = h > 0.7 ? 0.9 : (h > 0.4 ? 0.5 : 0.3);

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: FractionallySizedBox(
                                    heightFactor: h,
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: opacity),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(point.label, style: theme.textTheme.labelSmall, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCycleCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F6F57), Color(0xFF6B8F71)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("PERSONAL CYCLE", style: TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'DM Mono', letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text.rich(TextSpan(children: [
            TextSpan(text: "${_patterns?.cycleMinutes ?? 90} ", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -2)),
            const TextSpan(text: "min", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          ])),
          const SizedBox(height: 2),
          Text(
            _patterns != null && _patterns!.cycleMinutes != 90
                ? "Learned from your sessions"
                : "Default until FLOW learns your rhythm",
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(BuildContext context, String value, String label, {bool isWarning = false}) {
    final theme = Theme.of(context);
    final bgColor = isWarning ? theme.colorScheme.error.withValues(alpha: 0.1) : theme.primaryColor.withValues(alpha: 0.1);
    final valColor = isWarning ? theme.colorScheme.error : theme.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: valColor, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(label.toUpperCase(), style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildInsightsCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor, width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text("AI insights this week", style: theme.textTheme.headlineSmall),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                   decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(100)),
                   child: Text("↑ AI Sync", style: theme.textTheme.labelLarge?.copyWith(color: theme.primaryColor, fontSize: 10)),
                 ),
               ],
             ),
             const SizedBox(height: 14),

             // Dynamic Gemini Block (future cached in state — doesn't refire on rebuild)
             FutureBuilder<Map<String, dynamic>>(
               future: _focusDnaFuture,
               builder: (context, snapshot) {
                 if (snapshot.connectionState == ConnectionState.waiting) {
                   return const Padding(
                     padding: EdgeInsets.symmetric(vertical: 20),
                     child: Center(child: CircularProgressIndicator()),
                   );
                 }
                 final insight = snapshot.data?['gemini_insight'] as String?;
                 if (snapshot.hasData && insight != null && insight.isNotEmpty) {
                   return _buildInsightItem(context, "🧠", "FLOW Core AI Insight", insight, "Focus DNA", "orange");
                 }
                 return _buildInsightItem(
                   context,
                   "🧠",
                   "AI insight unavailable",
                   snapshot.error?.toString() ?? "Gemini couldn't be reached. Check the backend GEMINI_API_KEY.",
                   "Error",
                   "rose",
                 );
               },
             ),
             const SizedBox(height: 8),
             TextButton.icon(
               onPressed: _retryFocusDna,
               icon: const Icon(Icons.refresh_rounded, size: 16),
               label: const Text('Refresh AI insight'),
             ),

            const SizedBox(height: 8),
            _buildInsightItem(context, "📊", "Weekly trend", _weeklyTrendLine(), "Pattern", "green"),
          ],
        ),
      ),
    );
  }

  String _weeklyTrendLine() {
    if (_patterns == null) return 'No data yet';
    final scored = _patterns!.weeklyTrends.where((p) => p.value > 0).toList();
    if (scored.isEmpty) return 'Complete sessions this week to see your trend.';
    final best = scored.reduce((a, b) => a.value >= b.value ? a : b);
    return 'Best day: ${best.label} at ${best.value}% average focus.';
  }

  Widget _buildInsightItem(BuildContext context, String emoji, String title, String sub, String tag, String type) {
    final theme = Theme.of(context);

    Color bgColor = theme.primaryColor.withValues(alpha: 0.05);
    if (type == "orange") bgColor = theme.colorScheme.secondary.withValues(alpha: 0.1);
    if (type == "rose") bgColor = theme.colorScheme.error.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
                Text(sub, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          _buildTag(context, tag, isGreen: type == "green", isOrange: type == "orange", isRose: type == "rose"),
        ],
      ),
    );
  }

  Widget _buildHeatmapCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor, width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Focus heatmap — last 28 days", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, crossAxisSpacing: 4, mainAxisSpacing: 4, childAspectRatio: 1,
              ),
              itemCount: 28,
              itemBuilder: (context, index) {
                final val = _heatmapData[index];
                double opacity = 0.2;
                if (val > 0.8) { opacity = 1.0; }
                else if (val > 0.6) { opacity = 0.85; }
                else if (val > 0.4) { opacity = 0.65; }
                else if (val > 0.2) { opacity = 0.4; }
                return Container(
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: opacity),
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text("LESS", style: theme.textTheme.labelSmall),
                const SizedBox(width: 8),
                _buildLegendBox(0.1), _buildLegendBox(0.3), _buildLegendBox(0.6), _buildLegendBox(0.85), _buildLegendBox(1.0),
                const SizedBox(width: 8),
                Text("MORE", style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendBox(double opacity) {
    return Container(
      width: 10, height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text, {bool isGreen = false, bool isOrange = false, bool isRose = false}) {
    final theme = Theme.of(context);

    Color bgColor = theme.primaryColor.withValues(alpha: 0.15);
    Color textColor = theme.primaryColor;

    if (isOrange) {
      bgColor = theme.colorScheme.secondary.withValues(alpha: 0.15);
      textColor = theme.colorScheme.secondary;
    } else if (isRose) {
      bgColor = theme.colorScheme.error.withValues(alpha: 0.15);
      textColor = theme.colorScheme.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(100)),
      child: Text(text, style: theme.textTheme.labelLarge?.copyWith(color: textColor, fontSize: 11)),
    );
  }
}
