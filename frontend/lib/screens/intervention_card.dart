import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models/intervention.dart';
import '../api/models/settings.dart';
import '../state/account_controllers.dart';
import '../state/break_controller.dart';
import '../ui/nudge_card.dart';
import '../widgets/common.dart';

/// The live nudge: Take a break · Snooze · Dismiss · Why? · Report.
/// Why? expands in place: contribution bars rise from their baseline; the
/// full weighted table stays one click further ("More detail").
class InterventionCard extends ConsumerStatefulWidget {
  const InterventionCard({super.key, required this.interventionId});
  final String interventionId;

  @override
  ConsumerState<InterventionCard> createState() => _InterventionCardState();
}

class _InterventionCardState extends ConsumerState<InterventionCard> {
  bool _why = false;

  @override
  Widget build(BuildContext context) {
    final i = ref.watch(interventionProvider(widget.interventionId));
    final snoozeOptions = ref.watch(settingsProvider).value?.snoozeOptions ?? const [5, 10, 20];
    final actions = ref.read(interventionActionsProvider);
    final why = _why ? ref.watch(explanationProvider((widget.interventionId, ExplainDetail.short))).value : null;

    return AsyncSection(
      value: i,
      onRetry: () => ref.invalidate(interventionProvider(widget.interventionId)),
      builder: (iv) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          NudgeCardView(
            message: iv.message,
            // "Explained" mode shows the reason up front; advisory keeps it behind Why?.
            reason: iv.deliveryMode != DeliveryMode.advisory ? iv.shortReason : null,
            breakMinutes: (iv.suggestedBreakSec / 60).round(),
            onBreak: () => runGuarded(context, () => actions.accept(iv)),
            snoozeOptions: snoozeOptions,
            onSnooze: (m) => runGuarded(context, () => actions.snooze(iv, m)),
            onDismiss: () => runGuarded(context, () => actions.dismiss(iv)),
            onWhy: () => setState(() => _why = !_why),
            onReport: () => showReportDialog(context, ref, iv.id),
            why: why == null
                ? (_why ? const [] : null)
                : [for (final c in why.contributions) (name: c.name, share: _share(c.contribution, why.combinedScore))],
          ),
          if (_why) TextButton(onPressed: () => showExplanation(context, iv.id), child: const Text('More detail')),
        ],
      ),
    );
  }
}

/// Short view first (one sentence, primary driver); "More detail" loads the
/// full weighted table (doc §6.4).
Future<void> showExplanation(BuildContext context, String interventionId) => showDialog<void>(
  context: context,
  builder: (_) => _ExplainDialog(interventionId: interventionId),
);

class _ExplainDialog extends ConsumerStatefulWidget {
  const _ExplainDialog({required this.interventionId});
  final String interventionId;
  @override
  ConsumerState<_ExplainDialog> createState() => _ExplainDialogState();
}

class _ExplainDialogState extends ConsumerState<_ExplainDialog> {
  ExplainDetail _detail = ExplainDetail.short;

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(explanationProvider((widget.interventionId, _detail)));
    return AlertDialog(
      title: const Text('Why this suggestion?'),
      content: SizedBox(
        width: 420,
        child: AsyncSection(
          value: e,
          builder: (x) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(x.headline),
              const SizedBox(height: 12),
              for (final c in x.contributions) ...[
                // Share of the combined score, not the raw contribution value.
                Text(
                  '${c.name}: ${(_share(c.contribution, x.combinedScore) * 100).round()}% of the score '
                  '(signal ${c.value.toStringAsFixed(2)} × weight ${c.weight.toStringAsFixed(2)})',
                ),
                LinearProgressIndicator(value: _share(c.contribution, x.combinedScore)),
                const SizedBox(height: 8),
              ],
              Text(
                'Combined ${x.combinedScore.toStringAsFixed(2)} vs threshold ${x.threshold.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (_detail == ExplainDetail.short)
          TextButton(onPressed: () => setState(() => _detail = ExplainDetail.full), child: const Text('More detail')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

double _share(double contribution, double combined) => combined <= 0 ? 0 : (contribution / combined).clamp(0.0, 1.0);

Future<void> showReportDialog(BuildContext context, WidgetRef ref, String interventionId) async {
  var reason = ReportReason.wrongTime;
  final text = TextEditingController();
  final send = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: const Text('What was wrong with this nudge?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<ReportReason>(
              groupValue: reason,
              onChanged: (v) => setState(() => reason = v ?? reason),
              child: Column(
                children: [for (final r in ReportReason.values) RadioListTile<ReportReason>(value: r, title: Text(r.label))],
              ),
            ),
            TextField(
              controller: text,
              decoration: const InputDecoration(labelText: 'Anything else? (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Send')),
        ],
      ),
    ),
  );
  final note = text.text;
  text.dispose();
  if (send == true && context.mounted) {
    final ok = await runGuarded(context, () => ref.read(interventionActionsProvider).report(interventionId, reason, text: note));
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks — this helps Flow get timing right.')));
    }
  }
}
