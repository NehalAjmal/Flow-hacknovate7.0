import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/models/day.dart';
import '../api/models/member.dart';
import '../api/models/session.dart';
import '../api/models/team.dart';
import '../router/routes.dart';
import '../state/data_providers.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../ui/feature_note.dart';
import '../ui/kit.dart';
import '../ui/loading_blocks.dart';
import '../widgets/common.dart';
import 'shell.dart' show FlowHeader;

// ── shared ─────────────────────────────────────────────────────────────────

const _wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Break pressure as words (text carries the meaning; amber only when high).
class _Strain extends StatelessWidget {
  const _Strain(this.level);
  final String level;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final high = level == 'high';
    final n = switch (level) {
      'high' => 3,
      'moderate' => 2,
      _ => 1,
    };
    return Semantics(
      label: 'Break pressure $level',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 5,
              height: 6.0 + i * 4,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: i < n ? (high ? p.amber : p.pastHeavy) : null,
                border: i < n ? null : Border.all(color: p.hairline),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              flowCaps(level),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: FlowType.label(p, size: 9.5, color: high ? p.text1 : p.text2),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the admin is looking at, and what they never will. Always on screen.
class _Boundary extends StatelessWidget {
  const _Boundary();
  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Row(
      children: [
        Icon(Icons.shield_outlined, size: 14, color: p.text3),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Everyone here joined through your invite, which told them you see this. '
            'Time, sessions and breaks only: never what anyone works on.',
            style: FlowType.note(p, size: 13),
          ),
        ),
      ],
    );
  }
}

// ── /admin/people ──────────────────────────────────────────────────────────

enum _Sort { focus, strain, name }

/// Everyone on the team, side by side. One row per person: their week as
/// seven blocks on a shared scale (so heights compare across people, with the
/// team's average as a tick), then the read-outs. Rows grow to fill the page.
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});
  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> with SingleTickerProviderStateMixin {
  _Sort _sort = _Sort.focus;
  late final _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    Motion.enterOnMount(context, _rise, () => mounted);
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final members = ref.watch(adminMembersProvider);
    final list = [...?members.value];
    switch (_sort) {
      case _Sort.focus:
        list.sort((a, b) => b.focusMinutes.compareTo(a.focusMinutes));
      case _Sort.strain:
        list.sort((a, b) => b.strainRank != a.strainRank ? b.strainRank.compareTo(a.strainRank) : b.focusMinutes.compareTo(a.focusMinutes));
      case _Sort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
    }
    final today = DateTime.now().weekday - 1;
    final peak = list.expand((m) => m.focusByDay).fold(1, math.max);
    final avg = [for (var d = 0; d < 7; d++) list.isEmpty ? 0.0 : list.fold(0, (a, m) => a + m.focusByDay[d]) / list.length];
    final teamAvg = list.isEmpty ? 0 : (list.fold(0, (a, m) => a + m.focusMinutes) / list.length).round();

    return Padding(
      padding: const EdgeInsets.only(right: 24, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlowHeader(
            title: 'People',
            subtitle: members.hasValue ? '${list.length} people · this week' : 'This week',
            action: Pressable(onPressed: () => context.go(Routes.admin), child: const Text('Team overview')),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ColorField(
              tone: FieldTone.past,
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
              child: switch (members) {
                AsyncError(:final error) when !members.hasValue => InlineError(
                  message: errorText(error),
                  onRetry: () => ref.invalidate(adminMembersProvider),
                ),
                _ when !members.hasValue => const Center(child: LoadingBlocks(height: 140)),
                _ when list.isEmpty => Center(
                  child: Text('Nobody has joined yet. Invite people from the team overview.', style: FlowType.note(p, size: 15)),
                ),
                _ => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // column heads: day letters over the blocks, labels over the read-outs
                    _Row(
                      height: 22,
                      name: const SizedBox.shrink(),
                      week: Row(
                        children: [
                          for (var d = 0; d < 7; d++)
                            Expanded(
                              child: Center(
                                child: Text(_wd[d], style: FlowType.chart(p, size: 10, color: d == today ? p.text1 : p.text3)),
                              ),
                            ),
                        ],
                      ),
                      focus: const SectionLabel('Focus'),
                      sessions: const SectionLabel('Sessions'),
                      breaks: const SectionLabel('Breaks taken'),
                      strain: const SectionLabel('Break pressure'),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final rowH = (box.maxHeight / list.length).clamp(54.0, 104.0);
                          return ListView.builder(
                            itemCount: list.length,
                            itemExtent: rowH,
                            itemBuilder: (context, i) {
                              final m = list[i];
                              return _PersonRow(
                                key: ValueKey(m.id),
                                member: m,
                                height: rowH,
                                peak: peak,
                                avg: avg,
                                today: today,
                                rise: _rise,
                                index: i,
                                onOpen: () => context.go(Routes.adminPerson(m.id)),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    // read-out, then controls (placement order); wraps when narrow
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 14, height: 1.5, color: p.text2),
                            const SizedBox(width: 6),
                            Text(
                              'team average that day · ${flowDuration(teamAvg)} each this week',
                              style: FlowType.chart(p, size: 10.5, color: p.text2),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(flowCaps('Sort'), style: FlowType.label(p, size: 9.5, color: p.text3)),
                            const SizedBox(width: 8),
                            for (final (s, label) in const [
                              (_Sort.focus, 'Focus'),
                              (_Sort.strain, 'Break pressure'),
                              (_Sort.name, 'Name'),
                            ]) ...[
                              Pressable(
                                selected: _sort == s,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                onPressed: () => setState(() => _sort = s),
                                child: Text(label),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              },
            ),
          ),
          const SizedBox(height: 12),
          const _Boundary(),
        ],
      ),
    );
  }
}

/// The People table's column geometry, shared by the head and every row.
class _Row extends StatelessWidget {
  const _Row({
    required this.height,
    required this.name,
    required this.week,
    required this.focus,
    required this.sessions,
    required this.breaks,
    required this.strain,
  });
  final double height;
  final Widget name, week, focus, sessions, breaks, strain;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Row(
      children: [
        Expanded(flex: 16, child: name),
        const SizedBox(width: 12),
        Expanded(flex: 30, child: week),
        const SizedBox(width: 22),
        Expanded(flex: 9, child: focus),
        Expanded(flex: 8, child: sessions),
        Expanded(flex: 14, child: breaks),
        Expanded(flex: 13, child: strain),
        const SizedBox(width: 18),
      ],
    ),
  );
}

class _PersonRow extends StatefulWidget {
  const _PersonRow({
    super.key,
    required this.member,
    required this.height,
    required this.peak,
    required this.avg,
    required this.today,
    required this.rise,
    required this.index,
    required this.onOpen,
  });
  final MemberSummary member;
  final double height;
  final int peak;
  final List<double> avg;
  final int today;
  final Animation<double> rise;
  final int index;
  final VoidCallback onOpen;

  @override
  State<_PersonRow> createState() => _PersonRowState();
}

class _PersonRowState extends State<_PersonRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final m = widget.member;
    final big = widget.height >= 76;
    final share = m.breaksSuggested == 0 ? 0.0 : m.breaksTaken / m.breaksSuggested;
    return Semantics(
      button: true,
      label:
          '${m.name}: ${flowDuration(m.focusMinutes)} of focus, ${m.sessions} sessions, '
          '${m.breaksTaken} of ${m.breaksSuggested} breaks taken, break pressure ${m.strain}. Open their page.',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onOpen,
          child: AnimatedContainer(
            duration: Motion.fade,
            decoration: BoxDecoration(
              color: _hover ? p.raised.withValues(alpha: 0.7) : null,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                top: BorderSide(color: p.hairline.withValues(alpha: _hover ? 0 : 1)),
              ),
            ),
            padding: const EdgeInsets.only(left: 8),
            child: _Row(
              height: widget.height,
              name: Row(
                children: [
                  // now = accent: only while they are in a session
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: m.inSession ? p.accent : null,
                      border: m.inSession ? null : Border.all(color: p.text3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.text1, fontSize: big ? 15 : 13.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              week: Padding(
                padding: EdgeInsets.symmetric(vertical: big ? 10 : 7),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _WeekBlocks(p, m.focusByDay, widget.peak, widget.avg, widget.today, widget.rise, widget.index),
                ),
              ),
              focus: DurationNumeral(m.focusMinutes, size: big ? 22 : 17),
              sessions: TabularNumeral('${m.sessions}', style: FlowType.numeral(p, big ? 22 : 17)),
              breaks: Row(
                children: [
                  TabularNumeral('${m.breaksTaken}/${m.breaksSuggested}', style: FlowType.chart(p, size: 12, color: p.text1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(value: share, minHeight: 5, backgroundColor: p.recess, color: p.amber),
                      ),
                    ),
                  ),
                ],
              ),
              strain: Row(
                children: [
                  Expanded(
                    child: Align(alignment: Alignment.centerLeft, child: _Strain(m.strain)),
                  ),
                  AnimatedOpacity(
                    opacity: _hover ? 1 : 0,
                    duration: Motion.fade,
                    child: Icon(Icons.arrow_forward_rounded, size: 16, color: p.text2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Seven day blocks on the team's shared scale. Solid = happened; today's
/// remaining and future days are a dashed outline (not yet). A tick marks the
/// team's average for that day, so a glance compares one person to everyone.
class _WeekBlocks extends CustomPainter {
  _WeekBlocks(this.p, this.days, this.peak, this.avg, this.today, this.rise, this.index) : super(repaint: rise);
  final FlowPalette p;
  final List<int> days;
  final int peak;
  final List<double> avg;
  final int today;
  final Animation<double> rise;
  final int index;

  @override
  void paint(Canvas c, Size s) {
    final slot = s.width / 7;
    final w = math.min(slot * 0.62, 46.0);
    final t = rise.isCompleted ? 1.0 : Motion.settleAt(rise.value * 1.1 - index * 0.04);
    c.drawLine(
      Offset(0, s.height - 0.5),
      Offset(s.width, s.height - 0.5),
      Paint()
        ..color = p.hairline
        ..strokeWidth = 1,
    );
    for (var d = 0; d < 7; d++) {
      final x = d * slot + (slot - w) / 2;
      final h = s.height * (days[d] / peak) * t;
      if (d > today) {
        // not yet: a short dashed base
        final dash = Paint()
          ..color = p.future.withValues(alpha: 0.7)
          ..strokeWidth = 1.2;
        for (var k = x; k < x + w; k += 6) {
          c.drawLine(Offset(k, s.height - 3), Offset(math.min(k + 3, x + w), s.height - 3), dash);
        }
      } else if (h >= 1) {
        final r = RRect.fromRectAndCorners(
          Rect.fromLTWH(x, s.height - h, w, h),
          topLeft: const Radius.circular(2.5),
          topRight: const Radius.circular(2.5),
        );
        c.drawRRect(r, Paint()..color = d == today ? p.pastHeavy : p.pastModerate);
      }
      if (d <= today && avg[d] > 0) {
        final y = s.height - s.height * (avg[d] / peak) * t;
        c.drawLine(
          Offset(x - 4, y),
          Offset(x + w + 4, y),
          Paint()
            ..color = p.text2
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WeekBlocks o) => o.days != days || o.peak != peak || o.p != p || o.today != today || o.avg != avg;
}

// ── /admin/people/:id ──────────────────────────────────────────────────────

/// One person: the week as seven day lanes (display), their numbers against
/// the team's (read-out), then how they answer break suggestions and two
/// trends. Fills the page; the lanes grow with the window.
class MemberScreen extends ConsumerStatefulWidget {
  const MemberScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends ConsumerState<MemberScreen> with SingleTickerProviderStateMixin {
  late final _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    Motion.enterOnMount(context, _rise, () => mounted);
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final detail = ref.watch(adminMemberProvider(widget.id));
    final team = ref.watch(adminMembersProvider).value ?? const <MemberSummary>[];
    final m = detail.value;
    final name = m?.summary.name ?? team.where((x) => x.id == widget.id).firstOrNull?.name ?? 'Person';

    Widget body;
    if (m == null) {
      body = detail.hasError
          ? InlineError(message: errorText(detail.error!), onRetry: () => ref.invalidate(adminMemberProvider(widget.id)))
          : const Center(child: LoadingBlocks(height: 160));
    } else {
      final s = m.summary;
      final teamAvg = team.isEmpty ? null : (team.fold(0, (a, x) => a + x.focusMinutes) / team.length).round();
      final diff = teamAvg == null ? null : s.focusMinutes - teamAvg;
      body = LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 900;
          final week = ColorField(
            tone: FieldTone.past,
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionLabel('The week'),
                const SizedBox(height: 8),
                Expanded(
                  child: Semantics(
                    label: 'Week timeline: ${[for (final d in m.days) flowDuration(d.focusMinutes)].join(', ')} Monday to Sunday',
                    child: CustomPaint(size: Size.infinite, painter: _LanesPainter(p, m.days, _rise, MediaQuery.textScalerOf(context))),
                  ),
                ),
                const SizedBox(height: 10),
                const _Legend(),
              ],
            ),
          );
          final focusCard = ColorField(
            tone: FieldTone.planned,
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Focus this week'),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    DurationNumeral(s.focusMinutes, size: 46),
                    const SizedBox(width: 12),
                    if (diff != null)
                      Flexible(
                        child: Text(
                          diff.abs() < 15
                              ? 'about the team average'
                              : '${flowDuration(diff.abs())} ${diff > 0 ? 'above' : 'below'} the team average',
                          style: FlowType.note(p, size: 13.5),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(label: 'Sessions', value: '${s.sessions}'),
                    ),
                    Expanded(
                      child: _Stat(
                        label: 'Longest',
                        minutes: m.days.expand((d) => d.sessions).fold<int>(0, (a, x) => math.max(a, x.end.difference(x.start).inMinutes)),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [const SectionLabel('Break pressure'), const SizedBox(height: 8), _Strain(s.strain)],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
          final responsesCard = ColorField(
            tone: FieldTone.rest,
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Break suggestions'),
                const SizedBox(height: 4),
                Text(
                  s.nudges.total == 0
                      ? 'None yet this week.'
                      : 'Took ${s.nudges.taken} of ${s.nudges.total}. Snoozed ${s.nudges.snoozed}, dismissed ${s.nudges.dismissed}.',
                  style: FlowType.note(p, size: 14, color: p.text1),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 14,
                  child: CustomPaint(size: Size.infinite, painter: _ResponsesPainter(p, s.nudges, _rise)),
                ),
              ],
            ),
          );
          final trendsCard = ColorField(
            tone: FieldTone.past,
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Focus per day, 30 days · break pressure, 14 days'),
                const SizedBox(height: 10),
                Expanded(
                  child: Semantics(
                    label: 'Focus per day over 30 days with break pressure over the last 14 days',
                    child: CustomPaint(size: Size.infinite, painter: _TrendsPainter(p, m.focusTrend, m.strainTrend, _rise)),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 8, color: p.pastModerate),
                        const SizedBox(width: 6),
                        Flexible(child: Text('focus per day, oldest on the left', style: FlowType.chart(p, size: 10.5))),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 14, height: 2, color: p.amber),
                        const SizedBox(width: 6),
                        Text('break pressure', style: FlowType.chart(p, size: 10.5)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
          const gap = SizedBox(height: 14);
          // tall enough: the trends card takes what is left; otherwise the
          // column scrolls and the trends keep a readable height
          final numbers = LayoutBuilder(
            builder: (context, col) => col.maxHeight >= 640
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      focusCard,
                      gap,
                      responsesCard,
                      gap,
                      Expanded(child: trendsCard),
                    ],
                  )
                : ListView(
                    children: [
                      focusCard,
                      gap,
                      responsesCard,
                      gap,
                      SizedBox(height: 280, child: trendsCard),
                    ],
                  ),
          );
          if (!wide) {
            return ListView(
              children: [
                SizedBox(height: 420, child: week),
                gap,
                focusCard,
                gap,
                responsesCard,
                gap,
                SizedBox(height: 280, child: trendsCard),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 12, child: week),
              const SizedBox(width: 18),
              Expanded(flex: 9, child: numbers),
            ],
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 24, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlowHeader(
            title: name,
            subtitle: m?.summary.inSession == true ? 'In a session now' : 'This week',
            action: Pressable(
              onPressed: () => context.go(Routes.adminPeople),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(Icons.arrow_back_rounded, size: 14), SizedBox(width: 6), Text('Everyone')],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(child: body),
          const SizedBox(height: 12),
          const _Boundary(),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, this.value, this.minutes}) : assert(value != null || minutes != null);
  final String label;
  final String? value;

  /// A length of time: drawn with small units instead of [value].
  final int? minutes;
  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        const SizedBox(height: 2),
        if (minutes != null) DurationNumeral(minutes!, size: 24) else TabularNumeral(value!, style: FlowType.numeral(p, 24)),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    Widget sw(Color c, String t, {bool ring = false, bool round = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: round ? 8 : 14,
          height: 8,
          decoration: BoxDecoration(
            color: ring ? null : c,
            border: ring ? Border.all(color: c, width: 1.5) : null,
            borderRadius: BorderRadius.circular(round ? 4 : 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(t, style: FlowType.chart(p, size: 10.5)),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        sw(p.pastLight, 'light'),
        sw(p.pastModerate, 'moderate'),
        sw(p.pastHeavy, 'heavy session'),
        sw(p.amber, 'break taken', round: true),
        sw(p.amber, 'snoozed or dismissed', ring: true, round: true),
      ],
    );
  }
}

/// Seven lanes, one per day, on a shared clock. Sessions are solid blocks
/// shaded by demand; a filled amber dot is a break taken, a ring is a
/// suggestion that was snoozed or dismissed. Days still to come are a dashed
/// line. The day's total sits at the lane's right end.
class _LanesPainter extends CustomPainter {
  _LanesPainter(this.p, this.days, this.rise, this.scaler) : super(repaint: rise);
  final FlowPalette p;
  final List<MemberDay> days;
  final Animation<double> rise;
  final TextScaler scaler;

  @override
  void paint(Canvas c, Size s) {
    const left = 30.0, right = 58.0, foot = 18.0;
    // clock range from the data, widened to whole hours (default 8–18)
    var h0 = 8.0, h1 = 18.0;
    for (final x in days.expand((d) => d.sessions)) {
      h0 = math.min(h0, x.start.hour.toDouble());
      h1 = math.max(h1, x.end.hour + (x.end.minute > 0 ? 1.0 : 0.0));
    }
    final w = s.width - left - right;
    double xOf(DateTime t) => left + w * ((t.hour + t.minute / 60 - h0) / (h1 - h0)).clamp(0.0, 1.0);
    final lane = (s.height - foot) / 7;
    final blockH = (lane * 0.52).clamp(10.0, 38.0);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    TextPainter text(String t, TextStyle st) => TextPainter(
      text: TextSpan(text: t, style: st),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();

    // hour grid
    for (var h = h0.ceil(); h <= h1; h += 2) {
      final x = left + w * ((h - h0) / (h1 - h0));
      c.drawLine(Offset(x, 0), Offset(x, s.height - foot), Paint()..color = p.hairline.withValues(alpha: 0.6));
      final tp = text('$h', FlowType.chart(p, size: 9.5));
      tp.paint(c, Offset(x - tp.width / 2, s.height - foot + 4));
    }

    for (var i = 0; i < days.length && i < 7; i++) {
      final d = days[i];
      final y = lane * i + lane / 2;
      final future = d.date.isAfter(today);
      final isToday = d.date.year == today.year && d.date.month == today.month && d.date.day == today.day;
      final lbl = text(
        _wd[i],
        FlowType.chart(p, size: 11, color: isToday ? p.text1 : p.text3, weight: isToday ? FontWeight.w600 : FontWeight.w400),
      );
      lbl.paint(c, Offset(4, y - lbl.height / 2));

      if (future) {
        final dash = Paint()
          ..color = p.future.withValues(alpha: 0.7)
          ..strokeWidth = 1.2;
        for (var k = left; k < left + w; k += 7) {
          c.drawLine(Offset(k, y), Offset(math.min(k + 3.5, left + w), y), dash);
        }
        continue;
      }
      c.drawLine(Offset(left, y + blockH / 2), Offset(left + w, y + blockH / 2), Paint()..color = p.hairline);

      final t = rise.isCompleted ? 1.0 : Motion.settleAt(rise.value * 1.1 - i * 0.05);
      for (final x in d.sessions) {
        final a = xOf(x.start), b = xOf(x.end);
        final h = blockH * t;
        final color = switch (x.demand) {
          Demand.light => p.pastLight,
          Demand.moderate => p.pastModerate,
          _ => p.pastHeavy,
        };
        c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(a, y + blockH / 2 - h, math.max(b, a + 2), y + blockH / 2), const Radius.circular(2.5)),
          Paint()..color = color,
        );
      }
      for (final b in d.breaks) {
        final x = xOf(b.at);
        final o = Offset(x, y + blockH / 2 - blockH * t - 6);
        if (b.mark == BreakMark.taken) {
          c.drawCircle(o, 3.2 * t, Paint()..color = p.amber);
        } else {
          c.drawCircle(
            o,
            3 * t,
            Paint()
              ..color = p.amber
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }
      if (d.focusMinutes > 0) {
        final tp = text(flowDuration(d.focusMinutes), FlowType.chart(p, size: 11, color: p.text1));
        tp.paint(c, Offset(s.width - tp.width, y - tp.height / 2));
      } else {
        final tp = text('–', FlowType.chart(p, size: 11));
        tp.paint(c, Offset(s.width - tp.width - 4, y - tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_LanesPainter o) => o.days != days || o.p != p || o.scaler != scaler;
}

/// took | snoozed | dismissed as one bar: filled amber, amber outline, line.
class _ResponsesPainter extends CustomPainter {
  _ResponsesPainter(this.p, this.n, this.rise) : super(repaint: rise);
  final FlowPalette p;
  final NudgeResponses n;
  final Animation<double> rise;

  @override
  void paint(Canvas c, Size s) {
    final total = math.max(n.total, 1);
    final t = rise.isCompleted ? 1.0 : Motion.settleAt(rise.value * 1.1);
    final r = RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(3));
    c.drawRRect(r, Paint()..color = p.recess);
    c.save();
    c.clipRRect(r);
    final a = s.width * n.taken / total * t;
    final b = s.width * n.snoozed / total * t;
    c.drawRect(Rect.fromLTWH(0, 0, a, s.height), Paint()..color = p.amber);
    c.drawRect(Rect.fromLTWH(a, 0, b, s.height), Paint()..color = p.amber.withValues(alpha: 0.38));
    c.restore();
  }

  @override
  bool shouldRepaint(_ResponsesPainter o) => o.n != n || o.p != p;
}

/// 30 days of focus as thin solid bars, with the last 14 days of break
/// pressure drawn over them as an amber line (its own 0..1 scale, right).
class _TrendsPainter extends CustomPainter {
  _TrendsPainter(this.p, this.focus, this.strain, this.rise) : super(repaint: rise);
  final FlowPalette p;
  final List<TrendPoint> focus;
  final List<TrendPoint> strain;
  final Animation<double> rise;

  @override
  void paint(Canvas c, Size s) {
    if (focus.isEmpty) return;
    const foot = 4.0;
    final h = s.height - foot;
    final peak = focus.fold(1.0, (a, x) => math.max(a, x.value));
    final slot = s.width / focus.length;
    final t = rise.isCompleted ? 1.0 : Motion.settleAt(rise.value * 1.1);
    c.drawLine(Offset(0, h), Offset(s.width, h), Paint()..color = p.hairline);
    for (var i = 0; i < focus.length; i++) {
      final bh = h * (focus[i].value / peak) * 0.92 * t;
      if (bh < 1) continue;
      c.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(i * slot + slot * 0.2, h - bh, slot * 0.6, bh),
          topLeft: const Radius.circular(1.5),
          topRight: const Radius.circular(1.5),
        ),
        Paint()..color = i == focus.length - 1 ? p.pastHeavy : p.pastModerate.withValues(alpha: 0.8),
      );
    }
    if (strain.length < 2) return;
    final first = focus.length - strain.length;
    final path = Path();
    for (var i = 0; i < strain.length; i++) {
      final x = (first + i + 0.5) * slot;
      final y = h - h * strain[i].value.clamp(0.0, 1.0) * 0.92;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final m = path.computeMetrics().first;
    c.drawPath(
      m.extractPath(0, m.length * t),
      Paint()
        ..color = p.amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TrendsPainter o) => o.focus != focus || o.strain != strain || o.p != p;
}
