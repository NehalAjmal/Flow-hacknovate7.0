import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/routes.dart';
import '../state/account_controllers.dart';
import '../state/auth_controller.dart';
import '../state/break_controller.dart';
import '../state/data_providers.dart';
import '../state/schedule_runner.dart';
import '../state/session_controller.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../ui/brand/wordmark.dart';
import '../ui/dial.dart';
import '../ui/pressable.dart';
import '../widgets/common.dart';
import 'intervention_card.dart';

class _NavItem {
  const _NavItem(this.path, this.label, this.icon, {this.shortcut});
  final String path;
  final String label;
  final IconData icon;
  final String? shortcut;
}

/// App shell (DESIGN_SPEC §3): a floating rail inset 12 px from the window
/// edges, 56 px wide, the main group vertically centred, a sliding
/// dark-neutral pill for the active item; content starts 24 px to its right.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final user = ref.watch(currentUserProvider);
    final live = ref.watch(liveSessionProvider).value;
    final location = GoRouterState.of(context).matchedLocation;

    ref.watch(resumptionTrackerProvider);
    ref.listen(breakProvider, (prev, next) {
      if (prev == null && next != null) context.push(Routes.sessionBreak);
    });

    final main = [
      const _NavItem(Routes.home, 'Home', Icons.home_outlined, shortcut: 'Ctrl+1'),
      const _NavItem(Routes.patterns, 'Insights', Icons.insights_outlined, shortcut: 'Ctrl+2'),
      if (user?.hasTeam ?? false) const _NavItem(Routes.team, 'Team', Icons.groups_outlined),
      if (user?.isAdmin ?? false) const _NavItem(Routes.admin, 'Admin', Icons.admin_panel_settings_outlined),
    ];
    const bottom = [
      _NavItem(Routes.settings, 'Settings', Icons.tune, shortcut: 'Ctrl+,'),
      _NavItem(Routes.privacy, 'Privacy', Icons.shield_outlined),
      _NavItem(Routes.feedback, 'Feedback', Icons.chat_bubble_outline),
    ];
    bool isActive(_NavItem i) => i.path == Routes.home
        ? location == Routes.home
        : location.startsWith(i.path) || (i.path == Routes.patterns && location.startsWith(Routes.history));

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        children: [
          Row(
            children: [
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _Rail(
                  main: main,
                  bottom: bottom,
                  isActive: isActive,
                  liveSession: live != null && location != Routes.home,
                  onLogout: () => _confirmLogout(context, ref, sessionRunning: live != null),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    const _PauseBanner(),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
          if (live?.pendingInterventionId case final id?)
            Positioned(right: 20, bottom: 20, width: 400, child: InterventionCard(interventionId: id)),
          // a routine about to start: "Weekly review starts in 9 s · Start now · Skip"
          if (ref.watch(scheduleRunnerProvider) case final pending?)
            Positioned(
              top: 18,
              left: 0,
              right: 0,
              child: Center(child: _StartingBanner(pending: pending)),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref, {required bool sessionRunning}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text(sessionRunning ? 'Your running session will end and tracking stops.' : 'You can sign back in any time.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) await ref.read(authProvider.notifier).logout();
  }
}

class _Rail extends StatefulWidget {
  const _Rail({required this.main, required this.bottom, required this.isActive, required this.liveSession, required this.onLogout});
  final List<_NavItem> main;
  final List<_NavItem> bottom;
  final bool Function(_NavItem) isActive;
  final bool liveSession;
  final VoidCallback onLogout;

  @override
  State<_Rail> createState() => _RailState();
}

class _RailState extends State<_Rail> with SingleTickerProviderStateMixin {
  static const itemH = 44.0;
  late final _pillY = SpringValue(vsync: this, initial: -1);
  final _keys = <String, GlobalKey>{};
  final _railKey = GlobalKey();

  GlobalKey _k(String path) => _keys.putIfAbsent(path, GlobalKey.new);

  @override
  void didUpdateWidget(_Rail old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _movePill());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _movePill(jump: true));
  }

  void _movePill({bool jump = false}) {
    if (!mounted) return;
    final active = [...widget.main, ...widget.bottom].where(widget.isActive).firstOrNull;
    final railBox = _railKey.currentContext?.findRenderObject() as RenderBox?;
    final box = active == null ? null : _k(active.path).currentContext?.findRenderObject() as RenderBox?;
    if (railBox == null || box == null) {
      _pillY.value = -1000;
      return;
    }
    final y = box.localToGlobal(Offset.zero, ancestor: railBox).dy + (itemH - 22) / 2;
    if (jump || _pillY.value < -100) {
      _pillY.value = y;
    } else {
      // fast clicks keep their speed (Rule 2)
      _pillY.animateTo(y, spring: Motion.settle, reduced: Motion.reduced(context));
    }
  }

  @override
  void dispose() {
    _pillY.dispose();
    super.dispose();
  }

  Widget _item(BuildContext context, _NavItem i) {
    final p = FlowPalette.of(context);
    final on = widget.isActive(i);
    return Tooltip(
      key: _k(i.path),
      message: i.shortcut == null ? i.label : '${i.label}  (${i.shortcut})',
      preferBelow: false,
      verticalOffset: 0,
      margin: const EdgeInsets.only(left: 64),
      child: Semantics(
        button: true,
        selected: on,
        label: i.label,
        child: InkResponse(
          onTap: () => context.go(i.path),
          radius: 22,
          child: SizedBox(
            width: 56,
            height: itemH,
            child: Icon(i.icon, size: 20, color: on ? p.text1 : p.text3),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Container(
      key: _railKey,
      width: 56,
      decoration: BoxDecoration(
        color: p.raised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.hairline, width: 1),
      ),
      child: Stack(
        children: [
          // sliding pill: dark neutral (selection, never the accent)
          AnimatedBuilder(
            animation: _pillY.animation,
            builder: (context, _) => Positioned(
              left: 4,
              top: _pillY.value,
              child: Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(color: p.selected, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 14),
              const SizedBox(width: 56, height: 28, child: Center(child: FlowWordmark(capHeight: 11))),
              const Spacer(),
              for (final i in widget.main) _item(context, i),
              if (widget.liveSession) ...[
                const SizedBox(height: 8),
                Tooltip(
                  message: 'Session running',
                  child: InkResponse(onTap: () => context.go(Routes.home), child: const _RailSessionRing()),
                ),
              ],
              const Spacer(),
              for (final i in widget.bottom) _item(context, i),
              const SizedBox(height: 6),
              _Avatar(onLogout: widget.onLogout),
              const SizedBox(height: 12),
            ],
          ),
        ],
      ),
    );
  }
}

class _RailSessionRing extends ConsumerWidget {
  const _RailSessionRing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveSessionProvider).value;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    if (live == null) return const SizedBox.shrink();
    final s = live.session;
    final frac = (s.elapsedAt(now).inSeconds / (s.plannedMinutes * 60)).clamp(0.0, 1.0);
    return SizedBox(
      width: 56,
      height: 44,
      child: Center(
        child: DurationDial(minutes: s.plannedMinutes, onChanged: null, mode: DialMode.progress, fraction: frac, size: 40, centerLabel: ''),
      ),
    );
  }
}

class _Avatar extends ConsumerWidget {
  const _Avatar({required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final user = ref.watch(currentUserProvider);
    final initial = (user?.name.trim().isNotEmpty ?? false) ? user!.name.trim()[0].toUpperCase() : '·';
    return PopupMenuButton<String>(
      tooltip: 'Account',
      position: PopupMenuPosition.over,
      offset: const Offset(52, -120),
      onSelected: (v) => switch (v) {
        'account' => context.go(Routes.settings),
        'help' => context.go(Routes.settings),
        _ => onLogout(),
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'account', child: Text('Account')),
        PopupMenuItem(value: 'help', child: Text('Help & shortcuts')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'out', child: Text('Sign out')),
      ],
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.recess,
          border: Border.all(color: p.hairline),
        ),
        child: Text(
          initial,
          style: TextStyle(color: p.text2, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// Header for main screens (DESIGN_SPEC §3): title on the left;
/// "Flow on ▾" (global pause, status + control) and sensing chips on the right.
class FlowHeader extends ConsumerWidget {
  const FlowHeader({super.key, required this.title, this.subtitle, this.action});
  final String title;
  final String? subtitle;

  /// Optional screen-level action shown before the status chips (e.g. "How to read this").
  final Widget? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 24, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FlowType.headline(p, size: 26)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(flowCaps(subtitle!), style: FlowType.label(p, size: 10, color: p.text3)),
                ],
              ],
            ),
          ),
          if (action != null) ...[action!, const SizedBox(width: 12)],
          const FlowOnChip(),
          const SizedBox(width: 8),
          const HeaderSensing(),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, this.dotColor, this.trailing, this.tooltip});
  final String label;
  final bool on;
  final Color? dotColor;
  final Widget? trailing;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final chip = Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: p.raised,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: p.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? (dotColor ?? p.selected) : null,
              border: on ? null : Border.all(color: p.text3, width: 1),
            ),
          ),
          const SizedBox(width: 7),
          Text(flowCaps(label), style: FlowType.label(p, size: 9.5)),
          ?trailing,
        ],
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

/// Global pause: status and control in one chip.
class FlowOnChip extends ConsumerWidget {
  const FlowOnChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final pause = ref.watch(pauseProvider).value;
    final paused = pause?.paused ?? false;
    return PopupMenuButton<int>(
      tooltip: paused ? 'Flow is paused' : 'Pause Flow',
      onSelected: (v) {
        final n = ref.read(pauseProvider.notifier);
        switch (v) {
          case 0:
            n.resume();
          case 1:
            n.pauseFor(60);
          case 2:
            n.pauseForToday();
        }
      },
      itemBuilder: (_) => [
        if (paused) const PopupMenuItem(value: 0, child: Text('Resume Flow')),
        if (!paused) const PopupMenuItem(value: 1, child: Text('Pause for 1 hour')),
        if (!paused) const PopupMenuItem(value: 2, child: Text('Pause for today')),
      ],
      child: _Chip(
        label: paused ? 'Flow paused' : 'Flow on',
        on: !paused,
        dotColor: p.accent,
        trailing: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(Icons.expand_more, size: 14, color: p.text3),
        ),
      ),
    );
  }
}

/// "Behavior on · Camera off": what is sensed right now (doc §6.1).
class HeaderSensing extends ConsumerWidget {
  const HeaderSensing({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sensingProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Chip(
          label: 'Behavior',
          on: s.behavior,
          tooltip: s.behavior ? 'Activity counts are being sensed' : 'Not sensing (agent not connected)',
        ),
        const SizedBox(width: 6),
        _Chip(label: 'Camera', on: s.camera, tooltip: s.camera ? 'Eye signal on (on this computer only)' : 'Camera off'),
      ],
    );
  }
}

class _PauseBanner extends ConsumerWidget {
  const _PauseBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final pause = ref.watch(pauseProvider).value;
    if (pause == null || !pause.paused) return const SizedBox.shrink();
    final until = pause.until;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: p.raised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.hairline),
      ),
      child: Row(
        children: [
          Icon(Icons.pause_circle_outline, size: 16, color: p.text2),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              until == null ? 'Flow is paused.' : 'Flow is paused until ${TimeOfDay.fromDateTime(until).format(context)}.',
              style: TextStyle(color: p.text2, fontSize: 13),
            ),
          ),
          TextButton(onPressed: () => ref.read(pauseProvider.notifier).resume(), child: const Text('Resume')),
        ],
      ),
    );
  }
}

class _StartingBanner extends ConsumerWidget {
  const _StartingBanner({required this.pending});
  final PendingStart pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final secs = pending.at.difference(now).inSeconds.clamp(0, 99);
    final runner = ref.read(scheduleRunnerProvider.notifier);
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        decoration: BoxDecoration(
          color: p.raised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.future.withValues(alpha: 0.5)),
          boxShadow: [BoxShadow(color: Faces.ground(p.raised), offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: p.future, width: 1.5),
              ),
            ),
            const SizedBox(width: 10),
            Text('${pending.schedule.name} starts in ', style: TextStyle(color: p.text1, fontSize: 13)),
            TabularNumeral('$secs', style: FlowType.numeral(p, 20)),
            Text(' s', style: TextStyle(color: p.text1, fontSize: 13)),
            const SizedBox(width: 14),
            Pressable(tone: PressableTone.primary, onPressed: () => runGuarded(context, runner.startNow), child: const Text('Start now')),
            const SizedBox(width: 6),
            TextButton(
              onPressed: runner.skip,
              child: Text(
                'Skip',
                style: TextStyle(color: p.text2, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
