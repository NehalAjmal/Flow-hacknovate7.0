import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_connector.dart';
import '../api/models/meta.dart';
import '../state/data_providers.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../ui/appear.dart';
import '../ui/feature_note.dart';
import '../ui/kit.dart';
import '../ui/loading_blocks.dart';
import '../widgets/common.dart';
import 'auth_layout.dart' show AuthError;
import 'shell.dart' show FlowHeader;

// ── /feedback ──────────────────────────────────────────────────────────────

/// Feedback (spec §12), filling the page: the message on the left (kind ·
/// message · optional diagnostics with exactly what's included · Send), what
/// changed recently on the right.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});
  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  FeedbackKind _kind = FeedbackKind.feedback;
  final _msg = TextEditingController();
  bool _diagnostics = false;
  bool _showWhat = false;
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _msg.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  // Diagnostics are coarse app state only: no tokens, no task text, no titles.
  Map<String, Object> get _diag => {
    'app_version': '2.0.0',
    'platform': Theme.of(context).platform.name,
    'agent': ref.read(agentStatusProvider).connection.name,
  };

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(metaApiProvider)
          .sendFeedback(FeedbackRequest(kind: _kind, message: _msg.text.trim(), diagnostics: _diagnostics ? _diag : null));
      if (mounted) {
        setState(() {
          _busy = false;
          _sent = true;
          _msg.clear();
        });
      }
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
    final p = FlowPalette.of(context);
    final changelog = ref.watch(changelogProvider);
    final ready = _msg.text.trim().length >= 3 && !_busy;

    final form = ColorField(
      tone: FieldTone.planned,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tell us', style: FlowType.headline(p, size: 24)),
          const SizedBox(height: 6),
          Text('Every message is read by a person. Short is fine.', style: FlowType.note(p, size: 14)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in FeedbackKind.values)
                Pressable(selected: _kind == k, onPressed: () => setState(() => _kind = k), child: Text(k.label)),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Recessed(
              radius: 8,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                controller: _msg,
                minLines: null,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(color: p.text1, fontSize: 13.5),
                cursorColor: p.accent,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: switch (_kind) {
                    FeedbackKind.bug => 'What happened, and what did you expect?',
                    FeedbackKind.feature => 'What would you like Flow to do?',
                    FeedbackKind.feedback => 'Anything on your mind.',
                  },
                  hintStyle: TextStyle(color: p.text3, fontSize: 13.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              PillToggle(value: _diagnostics, onChanged: (v) => setState(() => _diagnostics = v), semanticLabel: 'Include diagnostics'),
              const SizedBox(width: 10),
              Flexible(
                child: Text('Include diagnostics', style: TextStyle(color: p.text1, fontSize: 13)),
              ),
              TextButton(
                onPressed: () => setState(() => _showWhat = !_showWhat),
                child: Text(
                  _showWhat ? 'hide' : "what's included",
                  style: TextStyle(color: p.text2, fontSize: 12, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: !_showWhat
                ? const SizedBox(width: double.infinity)
                : Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p.raised,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: p.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in _diag.entries) Text('${e.key}: ${e.value}', style: FlowType.chart(p, size: 11, color: p.text1)),
                        const SizedBox(height: 6),
                        Text('Never sent: tokens, task text, window titles, what you type.', style: FlowType.chart(p, size: 10.5)),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Pressable(tone: PressableTone.primary, onPressed: ready ? _send : null, child: Text(_busy ? 'Sending…' : 'Send')),
              const SizedBox(width: 14),
              AnimatedSwitcher(
                duration: Motion.fade,
                child: _sent
                    ? Text(
                        'Sent. Thank you.',
                        key: const ValueKey('sent'),
                        style: FlowType.note(p, size: 14, color: p.text1),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          if (_error != null) ...[const SizedBox(height: 8), AuthError(_error!)],
        ],
      ),
    );

    final news = ColorField(
      tone: FieldTone.past,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("What's new", style: FlowType.headline(p, size: 24)),
          const SizedBox(height: 14),
          switch (changelog) {
            AsyncData(:final value) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (value.isEmpty) Text('Nothing new yet.', style: FlowType.note(p, size: 14)),
                for (final (i, e) in value.indexed)
                  Appear(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              // chart voice: the display numerals have no full stop
                              Text(e.version, style: FlowType.chart(p, size: 15, color: p.text1, weight: FontWeight.w600)),
                              const SizedBox(width: 10),
                              if (e.date != null)
                                Text(MaterialLocalizations.of(context).formatMediumDate(e.date!), style: FlowType.chart(p, size: 10.5)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          for (final (k, item) in e.items.indexed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: FeatureNote(number: k + 1, compact: true, title: item, body: ''),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            AsyncError(:final error) => Text(errorText(error)),
            _ => const LoadingBlocks(height: 100),
          },
          const Spacer(),
          const SectionLabel('What helps us most'),
          const SizedBox(height: 10),
          const FeatureNote(
            number: 1,
            compact: true,
            title: 'What you were doing',
            body: 'A session, a break, the guide: where it happened.',
          ),
          const SizedBox(height: 8),
          const FeatureNote(number: 2, compact: true, title: 'What you expected', body: 'And what happened instead.'),
          const SizedBox(height: 8),
          const FeatureNote(
            number: 3,
            compact: true,
            title: 'A wrong nudge?',
            body: 'Use the flag on the nudge itself: it carries the exact moment.',
          ),
        ],
      ),
    );

    // fills the page: both columns run to the bottom, the message box grows
    return LayoutBuilder(
      builder: (context, box) {
        final fits = box.maxWidth >= 980 && box.maxHeight >= 600;
        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 11, child: form),
            const SizedBox(width: 18),
            Expanded(flex: 9, child: news),
          ],
        );
        return Padding(
          padding: const EdgeInsets.only(right: 24, bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FlowHeader(title: 'Feedback', subtitle: 'Bugs, ideas, anything'),
              const SizedBox(height: 10),
              Expanded(
                child: fits ? row : SingleChildScrollView(child: SizedBox(height: 900, child: row)),
              ),
            ],
          ),
        );
      },
    );
  }
}
