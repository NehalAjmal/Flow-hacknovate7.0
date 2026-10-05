import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../api_service.dart';
import '../widgets/count_up_text.dart';
import '../widgets/focus_ring.dart';
import 'session_end_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onViewActive;
  const DashboardScreen({super.key, this.onViewActive});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isBusy = false;
  String? _error;
  Timer? _refreshTimer;
  late AnimationController _ringEntry;

  DashboardData? _dashData;
  BiometricData? _bioData;

  @override
  void initState() {
    super.initState();
    _ringEntry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _fetchLiveData();
    // Keep the dashboard alive: refresh every 30s
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_isBusy) _fetchLiveData(silent: true);
    });
  }

  Future<void> _fetchLiveData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = _dashData == null;
        _error = null;
      });
    }
    try {
      final activeId = context.read<AppState>().activeSessionId;
      final results = await Future.wait([
        ApiService.userDashboard(),
        ApiService.biometricLatest(sessionId: activeId),
      ]);
      if (!mounted) return;
      setState(() {
        _dashData = DashboardData.fromJson(results[0]);
        _bioData = BiometricData.fromJson(results[1]);
        _isLoading = false;
        _error = null;
      });
      _ringEntry.forward(from: _ringEntry.isCompleted ? 0 : _ringEntry.value);
    } on ApiException catch (e) {
      // An invalid/expired token (e.g. backend restarted) should bounce the
      // user back to the login screen instead of a dead error page.
      if (e.isAuthError && mounted) {
        await context.read<AppState>().logout();
        return;
      }
      if (!mounted || silent) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _isLoading = false;
        _error = 'Something went wrong refreshing the dashboard.';
      });
    }
  }

  Future<void> _startSession() async {
    setState(() => _isBusy = true);
    try {
      final data = await ApiService.startSession(
        taskDescription: 'Quick focus session',
        difficulty: 'moderate',
        plannedMinutes: 50,
      );
      final sessionId = (data['session_id'] ?? data['id'])?.toString();
      if (sessionId == null || sessionId.isEmpty) {
        throw ApiException('Server did not return a session id.', null);
      }
      if (!mounted) return;
      context.read<AppState>().startSession(sessionId, task: 'Quick focus session');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session started! Background tracker active.')),
      );
      _fetchLiveData();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _endSession() async {
    final appState = context.read<AppState>();
    final navigator = Navigator.of(context);
    final sessionId = appState.activeSessionId;
    if (sessionId == null) return;

    setState(() => _isBusy = true);
    try {
      final result = await ApiService.endSession(sessionId);
      if (!mounted) return;
      await appState.endSession();
      navigator
          .push(MaterialPageRoute(builder: (_) => SessionEndScreen(result: SessionEndData.fromJson(result))))
          .then((_) => _fetchLiveData());
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _resetFocus() async {
    final sessionId = context.read<AppState>().activeSessionId;
    if (sessionId != null) {
      try {
        await ApiService.respond(sessionId, 'accepted');
      } catch (_) {/* best-effort */}
    }
    await _fetchLiveData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Focus reset applied.')));
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ringEntry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: Theme.of(context).textTheme.bodySmall?.color),
            const SizedBox(height: 16),
            Text('Can\'t reach FLOW', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _fetchLiveData(),
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

    final isActive = context.watch<AppState>().activeSessionId != null;
    final bool isFatigued = (_bioData?.fatigueSignal ?? 0) > 0.7;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(context, isActive),
            const SizedBox(height: 24),
            if (isFatigued) ...[
              _buildInterventionBanner(context),
              const SizedBox(height: 20),
            ],
            _buildRow1(context),
            const SizedBox(height: 14),
            _buildRow2(context),
            const SizedBox(height: 14),
            _buildRow3(context, isActive),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime now) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    String hh = now.hour % 12 == 0 ? '12' : '${now.hour % 12}';
    String mm = now.minute.toString().padLeft(2, '0');
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} · $hh:$mm';
  }

  Widget _buildTopBar(BuildContext context, bool isActive) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatDate(DateTime.now()), style: theme.textTheme.labelMedium?.copyWith(color: isDark ? FlowTheme.text3Dark : FlowTheme.text3Light)),
            const SizedBox(height: 2),
            Text(_dashData?.greeting ?? 'Welcome back', style: theme.textTheme.headlineLarge),
          ],
        ),
        if (isActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('SESSION LIVE', style: theme.textTheme.labelLarge?.copyWith(color: theme.primaryColor)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInterventionBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final driftColor = isDark ? FlowTheme.driftDark : FlowTheme.driftLight;
    final driftBg = isDark ? FlowTheme.driftBgDark : FlowTheme.driftBgLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(color: driftBg, border: Border.all(color: driftColor, width: 1.5), borderRadius: BorderRadius.circular(28)),
      child: Row(
        children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: driftColor, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.warning_amber_rounded, color: Colors.white)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Eye fatigue running high", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: driftColor)),
                const SizedBox(height: 3),
                Text("Your webcam fatigue signal is elevated. A short visual reset is recommended.", style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          ElevatedButton(onPressed: _resetFocus, style: ElevatedButton.styleFrom(backgroundColor: driftColor), child: const Text("Reset Focus"))
        ],
      ),
    );
  }

  Widget _buildRow1(BuildContext context) {
    final dash = _dashData;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("FOCUS SCORE TODAY", style: Theme.of(context).textTheme.labelMedium),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                CountUpText(target: dash?.focusScore ?? 0, style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Theme.of(context).primaryColor)),
                                Padding(padding: const EdgeInsets.only(bottom: 8, left: 2), child: Text("%", style: TextStyle(fontSize: 24, color: Theme.of(context).primaryColor, fontWeight: FontWeight.w700))),
                                if ((dash?.focusDelta ?? 0) != 0)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10, left: 8),
                                    child: Text(
                                      '${(dash!.focusDelta) > 0 ? '+' : ''}${dash.focusDelta} vs yesterday',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: dash.focusDelta > 0 ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.secondary),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        FocusRing(score: (dash?.focusScore ?? 0).toDouble(), color: Theme.of(context).primaryColor, trackColor: Theme.of(context).dividerColor),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("ULTRADIAN RHYTHM", style: Theme.of(context).textTheme.labelSmall),
                            Text(
                              dash != null && dash.minutesUntilTrough > 0
                                  ? '~${dash.minutesUntilTrough} min to trough'
                                  : 'No rhythm data yet',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).primaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildRhythmSegment(context, isTrough: true),
                            _buildRhythmSegment(context, isPeak: true),
                            _buildRhythmSegment(context, isPeak: true),
                            _buildRhythmSegment(context, isCurrent: true),
                            _buildRhythmSegment(context, isUpcoming: true),
                            _buildRhythmSegment(context, isUpcoming: true),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildStatPill(context, dash?.rhythmPositionMin ?? 0, "INTO CYCLE", "min", isPrimary: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildStatPill(context, dash?.minutesUntilTrough ?? 0, "NEXT BREAK", "min", isFatigue: true, prefix: '~')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildHeroCard(
                  context,
                  "SESSIONS TODAY",
                  '${dash?.sessionsToday ?? 0}',
                  "${(dash?.totalFocusMins ?? 0) ~/ 60}h ${(dash?.totalFocusMins ?? 0) % 60}m total focus",
                  isGreen: true,
                ),
                const SizedBox(height: 12),
                _buildHeroCard(
                  context,
                  "NEXT RECOMMENDED BREAK",
                  '~${dash?.minutesUntilTrough ?? 0}m',
                  "per your learned rhythm",
                  isOrange: true,
                ),
                const SizedBox(height: 12),
                _buildEyeFatigueCard(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEyeFatigueCard(BuildContext context) {
    final theme = Theme.of(context);
    final bio = _bioData;
    final signal = bio?.fatigueSignal ?? 0.0;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("EYE FATIGUE", style: theme.textTheme.labelMedium),
                Text(
                  bio == null ? '—' : '${(signal * 100).round()}%',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: theme.primaryColor),
                ),
                Text(
                  signal < 0.3 ? 'Normal' : (signal < 0.7 ? 'Elevated' : 'High'),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(value: signal.clamp(0.0, 1.0), minHeight: 8, backgroundColor: theme.dividerColor, color: theme.primaryColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bio != null && bio.ear > 0 ? 'EAR ${bio.ear.toStringAsFixed(2)}' : 'webcam signal',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRow2(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Today's schedule", style: Theme.of(context).textTheme.headlineSmall),
                        Text("FLOW sessions", style: TextStyle(fontSize: 11, color: Theme.of(context).primaryColor, fontFamily: 'DM Mono', fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: List.generate(7, (i) {
                        final now = DateTime.now();
                        final day = now.subtract(Duration(days: now.weekday - 1 - i));
                        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        return _buildCalDay(context, names[i], '${day.day}', isActive: _sameDay(day, now), hasEvent: false);
                      }),
                    ),
                    const SizedBox(height: 20),
                    Column(
                      children: [
                        _buildTimelineItem(context, Icons.adjust_rounded, _dashData != null && _dashData!.sessionsToday > 0 ? "Focus sessions today" : "No sessions yet today", "${_dashData?.sessionsToday ?? 0} sessions · ${_dashData?.totalFocusMins ?? 0} min tracked", true, false),
                        _buildTimelineItem(context, Icons.waves_rounded, "Rhythm position", "${_dashData?.rhythmPositionMin ?? 0} min into your cycle", false, true),
                        _buildTimelineItem(context, Icons.hotel_rounded, "Recommended break", "~${_dashData?.minutesUntilTrough ?? 0} min from now", false, false, isLast: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Biometric snapshot", style: Theme.of(context).textTheme.headlineSmall),
                        _buildTag(context, _bioData != null ? "Live" : "No data", _bioData != null),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildAppRow(context, Icons.favorite_rounded, "Heart rate", _bioData?.hasHr == true ? '${_bioData!.hr} bpm' : '—', _bioData?.hasHr == true ? (_bioData!.hr / 120).clamp(0.0, 1.0) : 0, FlowTheme.iconChipBg(context), Theme.of(context).primaryColor),
                    _buildAppRow(context, Icons.show_chart_rounded, "HRV", _bioData?.hasHrv == true ? '${_bioData!.hrv} ms' : '—', _bioData?.hasHrv == true ? (_bioData!.hrv / 100).clamp(0.0, 1.0) : 0, FlowTheme.iconChipBg(context), Theme.of(context).primaryColor),
                    _buildAppRow(context, Icons.visibility_rounded, "Eye openness (EAR)", _bioData != null && _bioData!.ear > 0 ? _bioData!.ear.toStringAsFixed(2) : '—', (_bioData?.ear ?? 0).clamp(0.0, 1.0), FlowTheme.iconChipBg(context), Theme.of(context).colorScheme.secondary),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("FATIGUE SIGNAL", style: Theme.of(context).textTheme.labelSmall),
                        _buildTag(context, _fatigueLabel(), (_bioData?.fatigueSignal ?? 0) < 0.4),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _fatigueLabel() {
    final s = _bioData?.fatigueSignal ?? 0;
    if (s < 0.3) return 'LOW · ${(s * 100).round()}%';
    if (s < 0.7) return 'MODERATE · ${(s * 100).round()}%';
    return 'HIGH · ${(s * 100).round()}%';
  }

  Widget _buildRow3(BuildContext context, bool isActive) {
    bool isFatigued = (_bioData?.fatigueSignal ?? 0) > 0.7;
    return Row(
      children: [
        Expanded(
            child: _buildBiometricCard(context, "Heart Rate", _bioData?.hr ?? 0, "BPM",
            _bioData?.hasHr != true ? "no data yet" :
            (_bioData!.hr > 90 ? "↑ high" : "↓ calm"),
            isDrift: isFatigued, heights: [0.4, 0.6, 0.5, 0.45, 0.48, 0.42, 0.44])),
        const SizedBox(width: 14),
        Expanded(
            child: _buildBiometricCard(context, "HRV", _bioData?.hrv ?? 0, "ms",
            _bioData?.hasHrv != true ? "no data yet" :
            (_bioData!.hrv < 40 ? "↓ low" : "↑ optimal"),
            heights: [0.55, 0.7, 0.8, 0.75, 0.85, 0.82, 0.88])),
        const SizedBox(width: 14),
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("QUICK ACTIONS", style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isBusy ? null : (isActive ? _endSession : _startSession),
                      style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: Text(_isBusy ? "Working..." : (isActive ? "End session" : "New session")),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: isActive ? widget.onViewActive : null,
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12), side: BorderSide(color: Theme.of(context).colorScheme.primaryContainer), backgroundColor: Theme.of(context).colorScheme.primaryContainer),
                      child: Text("View active →", style: TextStyle(color: isActive ? Theme.of(context).primaryColor : Theme.of(context).disabledColor)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- HELPERS ---
  Widget _buildRhythmSegment(BuildContext context, {bool isTrough = false, bool isPeak = false, bool isCurrent = false, bool isUpcoming = false}) {
    final theme = Theme.of(context);
    Color bgColor = theme.dividerColor;
    Border? border;
    if (isTrough) {
      bgColor = theme.colorScheme.secondary.withValues(alpha: 0.6);
    } else if (isPeak) {
      bgColor = theme.primaryColor;
    } else if (isCurrent) {
      bgColor = theme.brightness == Brightness.dark ? FlowTheme.primaryStrongDark : FlowTheme.primaryStrongLight;
      border = Border.all(color: theme.primaryColor, width: 2);
    }
    return Expanded(child: Container(height: 32, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4), border: border)));
  }

  Widget _buildStatPill(BuildContext context, int target, String label, String unit, {bool isPrimary = false, bool isFatigue = false, String prefix = ''}) {
    final theme = Theme.of(context);
    Color bgColor = theme.colorScheme.primaryContainer;
    Color valColor = theme.primaryColor;
    if (isFatigue) { bgColor = theme.colorScheme.secondaryContainer; valColor = theme.colorScheme.secondary; }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CountUpText(target: target, prefix: prefix, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: valColor, letterSpacing: -0.5)),
              Padding(padding: const EdgeInsets.only(bottom: 3, left: 2), child: Text(unit, style: TextStyle(fontSize: 11, color: valColor, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 4), Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, String label, String value, String sub, {bool isGreen = false, bool isOrange = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isGreen
        ? (isDark ? FlowTheme.brandGradientDark : FlowTheme.brandGradientLight)
        : null;
    final accent = isGreen
        ? (isDark ? FlowTheme.primaryDark : FlowTheme.primaryLight)
        : (isDark ? FlowTheme.fatigueDark : FlowTheme.fatigueLight);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isGreen ? null : (isDark ? FlowTheme.surfaceDark : FlowTheme.surfaceLight),
        gradient: gradientColors == null ? null : LinearGradient(colors: gradientColors),
        border: Border.all(color: isDark ? FlowTheme.borderDark : FlowTheme.borderLight),
        borderRadius: BorderRadius.circular(FlowTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: isGreen ? Colors.white70 : (isDark ? FlowTheme.text3Dark : FlowTheme.text3Light), fontFamily: 'DM Mono', letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: isGreen ? Colors.white : accent, letterSpacing: -2, height: 1)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(fontSize: 12, color: isGreen ? Colors.white70 : (isDark ? FlowTheme.text2Dark : FlowTheme.text2Light))),
        ],
      ),
    );
  }

  Widget _buildBiometricCard(BuildContext context, String title, int target, String unit, String sub, {bool isDrift = false, required List<double> heights}) {
    final theme = Theme.of(context);
    final highlightColor = isDrift ? theme.colorScheme.error : theme.primaryColor;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Row(
              children: [
                CountUpText(target: target, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: highlightColor, letterSpacing: -1.5)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [ Text(unit, style: theme.textTheme.bodySmall), Text(sub, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.primaryColor)) ],
                )
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: heights.map((h) => Expanded(
                    child: Container(
                      height: 48 * h, margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: h > 0.6 ? 1.0 : (h > 0.45 ? 0.7 : 0.3)), borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                    ),
                  )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalDay(BuildContext context, String name, String num, {bool isActive = false, bool hasEvent = false}) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: isActive ? theme.primaryColor : theme.scaffoldBackgroundColor, border: Border.all(color: isActive ? theme.primaryColor : theme.dividerColor), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text(name, style: TextStyle(fontSize: 9, fontFamily: 'DM Mono', color: isActive ? Colors.white70 : theme.textTheme.bodySmall?.color)),
            const SizedBox(height: 2),
            Text(num, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isActive ? Colors.white : theme.textTheme.bodyLarge?.color)),
            if (hasEvent)
              ...[
                const SizedBox(height: 4),
                Container(width: 4, height: 4, decoration: BoxDecoration(color: isActive ? Colors.white : theme.colorScheme.secondary, shape: BoxShape.circle)),
              ]
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, IconData icon, String title, String time, bool isGreen, bool isOrange, {bool isLast = false}) {
    final theme = Theme.of(context);
    Color dotBg = isGreen ? theme.colorScheme.primaryContainer : (isOrange ? theme.colorScheme.secondaryContainer : theme.colorScheme.surface);
    Color dotBorder = isGreen ? theme.primaryColor : (isOrange ? theme.colorScheme.secondary : theme.dividerColor);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(width: 34, height: 34, decoration: BoxDecoration(color: dotBg, border: Border.all(color: dotBorder, width: 2), shape: BoxShape.circle), alignment: Alignment.center, child: Icon(icon, size: 16, color: dotBorder)),
                if (!isLast) Expanded(child: Container(width: 2, color: theme.dividerColor)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 20, top: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(time, style: theme.textTheme.labelSmall) ])))
        ],
      ),
    );
  }

  Widget _buildAppRow(BuildContext context, IconData icon, String name, String time, double progress, Color iconBg, Color barColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)), alignment: Alignment.center, child: Icon(icon, size: 16, color: barColor)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), Text(time, style: Theme.of(context).textTheme.labelSmall) ]),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(100), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Theme.of(context).dividerColor, color: barColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text, bool isGreen) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: isGreen ? (isDark ? FlowTheme.primaryTintDark : FlowTheme.primaryTintLight) : (isDark ? FlowTheme.fatigueBgDark : FlowTheme.fatigueBgLight), borderRadius: BorderRadius.circular(100)),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: isGreen ? (isDark ? FlowTheme.primaryDark : FlowTheme.primaryLight) : (isDark ? FlowTheme.fatigueDark : FlowTheme.fatigueLight))),
    );
  }
}
