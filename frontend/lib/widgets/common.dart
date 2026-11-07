import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../api/models/session.dart';
import '../state/session_controller.dart';
import '../theme/tokens.dart';
import '../ui/loading_blocks.dart';

String errorText(Object e) => switch (e) {
  ApiError(:final message) => message,
  StateError(:final message) => message,
  _ => 'Something went wrong.',
};

/// Renders an AsyncValue with consistent loading / error+retry states.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({super.key, required this.value, required this.builder, this.onRetry, this.lines = 0});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  /// For list content: show this many skeleton rows instead of blocks.
  final int lines;

  @override
  Widget build(BuildContext context) {
    return switch (value) {
      AsyncData(:final value) => builder(value),
      // Errors are one inline line + Retry, never a modal (spec §13).
      AsyncError(:final error) => InlineError(message: errorText(error), onRetry: onRetry),
      _ when lines > 0 => SkeletonLines(rows: lines),
      _ => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: LoadingBlocks(height: 72, count: 5)),
    };
  }
}

/// Session state as a slim chip: a dot + caps label. Text always carries the
/// meaning (never colour alone); amber only when a break is near or due.
class FlowStateChip extends StatelessWidget {
  const FlowStateChip(this.state, {super.key});
  final FlowState state;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final (label, dot) = switch (state) {
      FlowState.steady => ('Steady', p.accent),
      FlowState.approachingBreak => ('Break soon', p.amber),
      FlowState.breakDue => ('Break due', p.amber),
      FlowState.paused => ('Paused', p.text3),
      FlowState.unknown => ('Starting', p.text3),
    };
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: p.raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(flowCaps(label), style: FlowType.label(p, size: 9.5, color: p.text1)),
        ],
      ),
    );
  }
}

/// One line, problem colour on the dot only, Retry beside it.
class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.problem),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(message, style: TextStyle(color: p.text1, fontSize: 13)),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: TextStyle(color: p.text1, fontSize: 13, decoration: TextDecoration.underline),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Live-connection state as a slim chip. Offline shows the connection line
/// with a gap in it (spec §13); live shows nothing.
class ConnectionChip extends StatelessWidget {
  const ConnectionChip(this.connection, {super.key});
  final LiveConnection connection;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    if (connection == LiveConnection.live) return const SizedBox.shrink();
    final offline = connection == LiveConnection.offline;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: p.raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(26, 10),
            painter: _GapLine(p, gap: offline),
          ),
          const SizedBox(width: 8),
          Text(offline ? 'Offline · retrying' : 'Updating every few seconds', style: TextStyle(color: p.text2, fontSize: 12)),
        ],
      ),
    );
  }
}

class _GapLine extends CustomPainter {
  _GapLine(this.p, {required this.gap});
  final FlowPalette p;
  final bool gap;
  @override
  void paint(Canvas c, Size s) {
    final y = s.height / 2;
    final paint = Paint()
      ..color = gap ? p.problem : p.text2
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    if (gap) {
      c.drawLine(Offset(0, y), Offset(s.width * 0.38, y), paint);
      c.drawLine(Offset(s.width * 0.62, y), Offset(s.width, y), paint);
    } else {
      for (var x = 0.0; x < s.width; x += 6) {
        c.drawLine(Offset(x, y), Offset(x + 3, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GapLine o) => o.gap != gap || o.p != p;
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

void showError(BuildContext context, Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));

/// Runs an async action with a snackbar on failure. Returns true on success.
Future<bool> runGuarded(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
    return true;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}
