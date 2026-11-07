import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_connector.dart';
import '../api/models/consent.dart';
import '../api/models/privacy.dart';
import '../core/config.dart';
import '../state/account_controllers.dart';
import '../state/auth_controller.dart';
import '../state/data_providers.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../ui/appear.dart';
import '../ui/blocks.dart';
import '../ui/feature_note.dart';
import '../ui/kit.dart';
import '../ui/loading_blocks.dart';
import '../widgets/common.dart';
import 'auth_layout.dart' show AuthError;
import 'auth_screens.dart' show consentDescription, consentTitle;
import 'shell.dart' show FlowHeader;

/// Privacy (spec §10), filling the page: what is stored as one 3D stack
/// (a layer per category, labelled by leader lines) beside what Flow may use;
/// export and delete underneath.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dataSummaryProvider);
    return LayoutBuilder(
      builder: (context, viewport) {
        final stackH = (viewport.maxHeight * 0.5).clamp(320.0, 460.0);
        return ListView(
          padding: const EdgeInsets.only(right: 24, bottom: 32),
          children: [
            const FlowHeader(title: 'Privacy', subtitle: 'What Flow may use, and what it keeps'),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, box) {
                final stored = ColorField(
                  tone: FieldTone.past,
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel("What's stored"),
                      const SizedBox(height: 4),
                      Text(
                        'Everything Flow keeps about you, as one stack. Hover a layer to read it.',
                        style: FlowType.note(p(context), size: 14),
                      ),
                      const SizedBox(height: 12),
                      switch (summary) {
                        AsyncData(:final value) => _Stack(categories: value.categories, height: stackH),
                        AsyncError(:final error) => Text(errorText(error)),
                        _ => SizedBox(
                          height: stackH,
                          child: const Center(child: LoadingBlocks(height: 160, count: 4)),
                        ),
                      },
                    ],
                  ),
                );
                const consents = _Consents();
                if (box.maxWidth < 980) return Column(children: [stored, const SizedBox(height: 18), consents]);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: stored),
                    const SizedBox(width: 18),
                    const Expanded(flex: 10, child: consents),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, box) {
                const export = _Export();
                const delete = _Delete();
                if (box.maxWidth < 980) return const Column(children: [export, SizedBox(height: 18), delete]);
                return const IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: export),
                      SizedBox(width: 18),
                      Expanded(child: delete),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

FlowPalette p(BuildContext context) => FlowPalette.of(context);

// ── the stack ───────────────────────────────────────────────────────────────

/// One 3D block, a layer per category; layer height ∝ log(items) so a big
/// category doesn't flatten the rest. Layers stack from the floor up
/// (SETTLE, staggered); leader lines carry the labels outside the object.
class _Stack extends StatefulWidget {
  const _Stack({required this.categories, required this.height});
  final List<DataCategory> categories;
  final double height;
  @override
  State<_Stack> createState() => _StackState();
}

class _StackState extends State<_Stack> with SingleTickerProviderStateMixin {
  late final _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  int? _hover;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Motion.enter(context, _rise, () => mounted);
    });
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = p(context);
    final cats = widget.categories;
    final hovered = _hover == null || _hover! >= cats.length ? null : cats[_hover!];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, box) {
              final geo = _StackGeo(box.biggest, cats);
              return MouseRegion(
                onHover: (e) {
                  final i = geo.layerAt(e.localPosition);
                  if (i != _hover) setState(() => _hover = i);
                },
                onExit: (_) => setState(() => _hover = null),
                child: AnimatedBuilder(
                  animation: _rise,
                  builder: (context, _) => CustomPaint(
                    size: box.biggest,
                    painter: _StackPainter(
                      pal,
                      cats,
                      geo,
                      _rise.isCompleted ? 1e9 : _rise.value * 1.8,
                      _hover,
                      MediaQuery.textScalerOf(context),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: Motion.fade,
          child: Text(
            key: ValueKey(hovered?.name),
            hovered == null
                ? '${cats.fold<int>(0, (a, c) => a + c.itemCount)} items in ${cats.length} kinds. Nothing here leaves Flow unless you export it.'
                : '${hovered.name}: ${hovered.description}',
            style: FlowType.note(pal, size: 14, color: pal.text1),
          ),
        ),
      ],
    );
  }
}

class _StackGeo {
  _StackGeo(this.size, this.cats) {
    final weights = [for (final c in cats) math.log(c.itemCount + 2)];
    final total = weights.fold<double>(0, (a, b) => a + b);
    final usable = size.height - floorPad - depth - 10;
    var y = size.height - floorPad;
    for (final w in weights) {
      final h = total == 0 ? 0.0 : usable * w / total;
      layers.add((y - h, y));
      y -= h;
    }
  }
  final Size size;
  final List<DataCategory> cats;
  static const floorPad = 14.0;
  double get depth => (size.width * 0.06).clamp(10.0, 26.0);
  double get x0 => size.width * 0.06;
  double get x1 => size.width * 0.44;
  final layers = <(double, double)>[]; // (top, bottom) per category, bottom first

  int? layerAt(Offset o) {
    if (o.dx < x0 || o.dx > x1 + depth + 260) return null;
    for (var i = 0; i < layers.length; i++) {
      if (o.dy >= layers[i].$1 - depth && o.dy <= layers[i].$2) return i;
    }
    return null;
  }
}

class _StackPainter extends CustomPainter {
  _StackPainter(this.p, this.cats, this.geo, this.rise, this.hover, this.scaler);
  final FlowPalette p;
  final List<DataCategory> cats;
  final _StackGeo geo;
  final double rise;
  final int? hover;
  final TextScaler scaler;

  @override
  void paint(Canvas c, Size s) {
    final floor = s.height - _StackGeo.floorPad;
    c.drawLine(
      Offset(0, floor),
      Offset(s.width, floor),
      Paint()
        ..color = p.text3
        ..strokeWidth = 1,
    );
    final stones = [p.pastHeavy, p.pastModerate, p.pastLight, Color.lerp(p.pastModerate, p.bg, 0.3)!, Color.lerp(p.pastHeavy, p.bg, 0.25)!];
    // each layer drops in onto the one below (stacking from the floor)
    for (var i = 0; i < cats.length; i++) {
      final (top, bottom) = geo.layers[i];
      final t = rise >= 1e8 ? 1.0 : Motion.settleAt(rise - i * 0.12);
      if (t <= 0.01) break;
      final drop = (1 - t) * 60;
      final h = bottom - top;
      final col = stones[i % stones.length];
      final hov = hover == i;
      final dx = hov ? 6.0 : 0.0;
      c.save();
      c.translate(dx, -drop);
      paintSolidBlock(c, geo.x0, geo.x1, bottom, h - 1.5, geo.depth, hov ? Color.lerp(col, p.selected, 0.25)! : col);
      c.restore();

      // leader line → label (outside the object, Hairline rule 10)
      final ly = top + h / 2 - drop;
      final lx0 = geo.x1 + geo.depth + 6 + dx;
      final lx1 = geo.x1 + geo.depth + 42;
      final alpha = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
      c.drawLine(
        Offset(lx0, ly),
        Offset(lx1, ly),
        Paint()
          ..color = (hov ? p.text1 : p.text3).withValues(alpha: alpha)
          ..strokeWidth = hov ? 1.2 : 0.8,
      );
      c.drawCircle(Offset(lx0, ly), 2, Paint()..color = (hov ? p.text1 : p.text3).withValues(alpha: alpha));
      final cat = cats[i];
      final name = TextPainter(
        text: TextSpan(
          text: cat.name,
          style: TextStyle(
            fontFamily: FlowFonts.ui,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: p.text1.withValues(alpha: alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: s.width - lx1 - 8);
      final meta = TextPainter(
        text: TextSpan(
          text: '${cat.itemCount} items${cat.retentionDays == null ? ' · kept until you delete' : ' · kept ${cat.retentionDays} days'}',
          style: FlowType.chart(p, size: 10.5, color: p.text2.withValues(alpha: alpha)),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: s.width - lx1 - 8);
      final blockH = name.height + 2 + meta.height;
      name.paint(c, Offset(lx1 + 8, ly - blockH / 2));
      meta.paint(c, Offset(lx1 + 8, ly - blockH / 2 + name.height + 2));
    }
  }

  @override
  bool shouldRepaint(_StackPainter o) => o.rise != rise || o.hover != hover || o.cats != cats || o.p != p;
}

// ── consents ────────────────────────────────────────────────────────────────

class _Consents extends ConsumerWidget {
  const _Consents();

  Future<void> _toggle(BuildContext context, WidgetRef ref, ConsentScope scope, bool granted) async {
    if (!granted && scope.required) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Stop behavior sensing?'),
          content: const Text('Flow cannot run sessions without it. A running session will stop getting updates.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep it')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Withdraw')),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (context.mounted) await runGuarded(context, () => ref.read(consentProvider.notifier).set(scope, granted));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = p(context);
    final consent = ref.watch(consentProvider);
    final loc = MaterialLocalizations.of(context);
    return ColorField(
      tone: FieldTone.planned,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('What Flow may use'),
          const SizedBox(height: 4),
          Text('Nothing was on until you turned it on. Turning one off stops that feature at once.', style: FlowType.note(pal, size: 14)),
          const SizedBox(height: 10),
          AsyncSection(
            lines: 5,
            value: consent,
            onRetry: () => ref.invalidate(consentProvider),
            builder: (c) => Column(
              children: [
                for (final (i, scope) in ConsentScope.values.indexed)
                  Appear(
                    index: i,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        border: i == 0 ? null : Border(top: BorderSide(color: pal.hairline)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  consentTitle(scope) + (scope.required ? ' (required)' : ''),
                                  style: TextStyle(color: pal.text1, fontSize: 13.5, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 3),
                                Text(consentDescription(scope), style: TextStyle(color: pal.text2, fontSize: 12, height: 1.4)),
                                if (c.entries[scope]?.at case final at?)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('changed ${loc.formatMediumDate(at)}', style: FlowType.chart(pal, size: 10.5)),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          PillToggle(
                            value: c.granted(scope),
                            semanticLabel: consentTitle(scope),
                            onChanged: (v) => _toggle(context, ref, scope, v),
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
}

// ── export ──────────────────────────────────────────────────────────────────

class _Export extends ConsumerStatefulWidget {
  const _Export();
  @override
  ConsumerState<_Export> createState() => _ExportState();
}

class _ExportState extends ConsumerState<_Export> {
  ExportJob? _job;
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _request() async {
    try {
      final job = await ref.read(privacyApiProvider).requestExport();
      if (!mounted) return;
      setState(() => _job = job);
      _poll?.cancel();
      _poll = Timer.periodic(Duration(seconds: kDevBuild ? 2 : 10), (_) async {
        try {
          final j = await ref.read(privacyApiProvider).exportStatus(job.id);
          if (!mounted) return;
          setState(() => _job = j);
          if (j.status != ExportStatus.pending) _poll?.cancel();
        } catch (_) {}
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = p(context);
    final j = _job;
    final state = j?.status;
    return ColorField(
      tone: FieldTone.rest,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Export'),
          const SizedBox(height: 4),
          Text('Everything above as JSON and CSV. It is prepared on the server and kept for a day.', style: FlowType.note(pal, size: 14)),
          const SizedBox(height: 16),
          _ProgressPill(state: state),
          const SizedBox(height: 8),
          Text(switch (state) {
            null => 'Not requested yet.',
            ExportStatus.pending => 'Preparing… you can leave this page; it keeps going.',
            ExportStatus.ready => 'Ready${j?.downloadUrl == null ? '' : ': ${j!.downloadUrl}'}',
            ExportStatus.failed => "It didn't finish. Try again.",
          }, style: FlowType.chart(pal, size: 11, color: state == ExportStatus.failed ? pal.problem : pal.text2)),
          const SizedBox(height: 14),
          Pressable(
            tone: PressableTone.primary,
            onPressed: state == ExportStatus.pending ? null : _request,
            child: Text(state == ExportStatus.ready ? 'Export again' : 'Export my data'),
          ),
        ],
      ),
    );
  }
}

/// The export as a pill: a dashed line runs while it is prepared (not yet),
/// the pill fills once it is actually ready. No invented percentages.
class _ProgressPill extends StatefulWidget {
  const _ProgressPill({required this.state});
  final ExportStatus? state;
  @override
  State<_ProgressPill> createState() => _ProgressPillState();
}

class _ProgressPillState extends State<_ProgressPill> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((e) => setState(() => _t = e.inMicroseconds / 1e6));
  double _t = 0;
  double _fill = 0;

  @override
  void didUpdateWidget(_ProgressPill old) {
    super.didUpdateWidget(old);
    final running = widget.state == ExportStatus.pending;
    if (running && !_ticker.isActive && !Motion.reduced(context)) _ticker.start();
    if (!running && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = p(context);
    final target = widget.state == ExportStatus.ready ? 1.0 : 0.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _fill, end: target),
      duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      onEnd: () => _fill = target,
      builder: (context, v, _) => SizedBox(
        height: 18,
        child: CustomPaint(
          size: const Size(double.infinity, 18),
          painter: _PillPainter(pal, v, widget.state == ExportStatus.pending ? _t : null, widget.state == ExportStatus.failed),
        ),
      ),
    );
  }
}

class _PillPainter extends CustomPainter {
  _PillPainter(this.p, this.fill, this.runT, this.failed);
  final FlowPalette p;
  final double fill;
  final double? runT;
  final bool failed;

  @override
  void paint(Canvas c, Size s) {
    final r = RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(s.height / 2));
    c.drawRRect(r, Paint()..color = p.recess);
    if (fill > 0) {
      c.save();
      c.clipRRect(r);
      c.drawRect(Rect.fromLTWH(0, 0, s.width * fill, s.height), Paint()..color = p.pastHeavy);
      c.restore();
    }
    final t = runT;
    if (t != null) {
      final y = s.height / 2;
      final paint = Paint()
        ..color = p.text2
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      const dash = 8.0, gap = 7.0;
      final shift = (t * 40) % (dash + gap);
      for (var x = 8 - dash + shift; x < s.width - 8; x += dash + gap) {
        final a = math.max(x, 8.0), b = math.min(x + dash, s.width - 8);
        if (b > a) c.drawLine(Offset(a, y), Offset(b, y), paint);
      }
    }
    if (failed) {
      c.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = p.problem,
      );
    }
  }

  @override
  bool shouldRepaint(_PillPainter o) => o.fill != fill || o.runT != runT || o.failed != failed;
}

// ── delete ──────────────────────────────────────────────────────────────────

class _Delete extends ConsumerStatefulWidget {
  const _Delete();
  @override
  ConsumerState<_Delete> createState() => _DeleteState();
}

class _DeleteState extends ConsumerState<_Delete> {
  final _ctl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(privacyApiProvider).deleteAccount();
      await ref.read(authProvider.notifier).logout();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = p(context);
    final armed = _ctl.text.trim() == 'DELETE';
    return ColorField(
      tone: FieldTone.past,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Delete account'),
          const SizedBox(height: 4),
          Text(
            'Deletes your account, sessions and settings for good. Export first if you want a copy.',
            style: FlowType.note(pal, size: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FlowTextField(controller: _ctl, hint: 'Type DELETE to confirm'),
              ),
              const SizedBox(width: 10),
              // the button wakes only when the word is typed exactly
              Pressable(
                tone: PressableTone.primary,
                onPressed: armed && !_busy ? _delete : null,
                child: Text(_busy ? 'Deleting…' : 'Delete for good'),
              ),
            ],
          ),
          if (_error != null) ...[const SizedBox(height: 8), AuthError(_error!)],
          const SizedBox(height: 14),
          const FeatureNote(
            number: 1,
            compact: true,
            title: 'What happens',
            body: 'You are signed out at once; your data is removed from Flow within 24 hours.',
          ),
        ],
      ),
    );
  }
}
