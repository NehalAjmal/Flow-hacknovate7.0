import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/app_state.dart';
import '../api_service.dart';

class IntentScreen extends StatefulWidget {
  final VoidCallback? onStartSession;

  //  FIX: use_super_parameters
  const IntentScreen({super.key, this.onStartSession});

  @override
  State<IntentScreen> createState() => _IntentScreenState();
}

class _IntentScreenState extends State<IntentScreen> {
  String _selectedTask = 'Deep work';
  String _selectedDuration = '50m';
  bool _isStarting = false;
  String? _recommendation;
  int? _suggestedDuration;
  List<Map<String, dynamic>> _recentIntentions = [];
  final TextEditingController _intentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    // pre-check: server-side recommendation + suggested duration
    try {
      final data = await ApiService.preCheck();
      if (!mounted) return;
      setState(() {
        _recommendation = data['recommendation']?.toString();
        _suggestedDuration = (data['suggested_duration_min'] as num?)?.toInt();
        if (_suggestedDuration != null && _suggestedDuration! > 0) {
          _selectedDuration = '${_suggestedDuration}m';
        }
      });
    } on ApiException {
      // no recommendation available - the honest fallback copy stays
    } catch (_) {}

    // recent intentions from real session history
    try {
      final recent = await ApiService.recentIntentions();
      if (!mounted) return;
      setState(() => _recentIntentions = recent);
    } catch (_) {}
  }

  final List<Map<String, dynamic>> _taskChips = [
    {'icon': Icons.psychology_rounded, 'label': 'Deep work'},
    {'icon': Icons.edit_note_rounded, 'label': 'Writing'},
    {'icon': Icons.build_rounded, 'label': 'Debugging'},
    {'icon': Icons.fact_check_rounded, 'label': 'Review'},
    {'icon': Icons.groups_rounded, 'label': 'Meeting prep'},
    {'icon': Icons.palette_rounded, 'label': 'Design'},
  ];

  List<String> get _durations {
    final presets = ['25m', '50m', '90m'];
    final suggested = _suggestedDuration;
    if (suggested != null && suggested > 0 && !presets.contains('${suggested}m')) {
      presets.insert(0, '${suggested}m');
    }
    return presets;
  }

  @override
  void dispose() {
    _intentController.dispose();
    super.dispose();
  }

  int get _plannedMinutes {
    final m = RegExp(r'(\d+)').firstMatch(_selectedDuration)?.group(1);
    return int.tryParse(m ?? '') ?? 50;
  }

  Future<void> _beginSession() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);

    final intentText = _intentController.text.trim().isNotEmpty
        ? _intentController.text.trim()
        : '$_selectedTask session';

    try {
      final data = await ApiService.startSession(
        taskDescription: intentText,
        difficulty: 'moderate',
        plannedMinutes: _plannedMinutes,
      );

      final sessionId = (data['session_id'] ?? data['id'])?.toString();
      if (sessionId == null || sessionId.isEmpty) {
        throw ApiException('Server did not return a session id.', null);
      }

      if (!mounted) return;
      context.read<AppState>().startSession(
            sessionId,
            task: '$_selectedTask — $intentText',
            intent: intentText,
          );
      widget.onStartSession?.call();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start session: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(context),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── LEFT COLUMN (Inputs) ──────────────────────────────
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTaskTypeCard(context),
                      const SizedBox(height: 16),
                      _buildIntentDeclarationCard(context),
                      const SizedBox(height: 16),
                      _buildDurationCard(context),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isStarting ? null : _beginSession,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                        //  FIX: prefer_const_constructors
                        child: _isStarting
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_circle_fill_rounded, size: 22),
                                  SizedBox(width: 8),
                                  Text("Begin focus session", style: TextStyle(fontSize: 16)),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // ─── RIGHT COLUMN (Recommendations) ────────────────────
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildOptimalWindowHero(context),
                      const SizedBox(height: 12),
                      _buildPermissionsCard(context),
                      const SizedBox(height: 12),
                      if (_recentIntentions.isNotEmpty) _buildRecentIntentionsCard(context),
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ─── TOP BAR ─────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "STARTING A SESSION",
          style: theme.textTheme.labelMedium?.copyWith(
            color: isDark ? FlowTheme.text3Dark : FlowTheme.text3Light,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "What will you focus on?",
          style: theme.textTheme.headlineLarge,
        ),
      ],
    );
  }

  // ─── LEFT COLUMN WIDGETS ─────────────────────────────────────────────────

  Widget _buildTaskTypeCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Task type", style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _taskChips.map((chip) {
                final isSelected = _selectedTask == chip['label'];
                return _buildChip(
                  context,
                  icon: chip['icon'] as IconData,
                  label: chip['label'] as String,
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedTask = chip['label'] as String),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntentDeclarationCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Declare your intention", style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _intentController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: "e.g. Fix the JWT token refresh bug in the auth module and write unit tests for edge cases...",
                contentPadding: EdgeInsets.all(20),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Be specific — FLOW will track drift against this intent.",
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Target duration", style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 12),
            Row(
              children: _durations.map((dur) {
                final isSelected = _selectedDuration == dur;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: dur != _durations.last ? 8.0 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDuration = dur),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).scaffoldBackgroundColor,
                          border: Border.all(
                            color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).dividerColor,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          dur,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── RIGHT COLUMN WIDGETS ────────────────────────────────────────────────

  Widget _buildOptimalWindowHero(BuildContext context) {
    final recommendation = _recommendation ?? 'Complete a few sessions so FLOW can learn your peak hours.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: Theme.of(context).brightness == Brightness.dark
              ? FlowTheme.brandGradientDark
              : FlowTheme.brandGradientLight,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(FlowTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SMART RECOMMENDATION", style: TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'DM Mono', letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(
            _suggestedDuration != null && _suggestedDuration! > 0 ? "${_suggestedDuration}m window" : "Ready when you are",
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1),
          ),
          const SizedBox(height: 6),
          Text(recommendation, style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildPermissionsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FlowTheme.radiusLg)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_rounded, size: 16, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text("Before your first session", style: theme.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "The backend needs macOS camera and Input Monitoring permission to track fatigue and keystrokes.",
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 6),
            Text(
              "Run:  python Backend/check_camera.py",
              style: theme.textTheme.labelSmall?.copyWith(color: theme.primaryColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildRecentIntentionsCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Recent intentions", style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 10),
            ..._recentIntentions.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _buildRecentTaskItem(context, item['task']?.toString() ?? ''),
            )),
          ],
        ),
      ),
    );
  }

  // ─── HELPER WIDGETS ──────────────────────────────────────────────────────

  Widget _buildChip(BuildContext context, {required IconData icon, required String label, required bool isSelected, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer : theme.scaffoldBackgroundColor,
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.dividerColor,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? theme.primaryColor : theme.textTheme.bodyMedium?.color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? theme.primaryColor : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTaskItem(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
      ),
    );
  }
}