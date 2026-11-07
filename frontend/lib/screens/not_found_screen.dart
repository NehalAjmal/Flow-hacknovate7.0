import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/routes.dart';
import '../theme/tokens.dart';
import '../ui/kit.dart';
import 'auth_layout.dart' show BlocksStage, StageState;

/// 404: the day's line with the next block left as an outline: the page you
/// asked for isn't here (yet). One way back.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.uri});
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 220, child: BlocksStage(state: StageState.rest, showBrand: false)),
                const SizedBox(height: 24),
                Text('Nothing here', style: FlowType.headline(p, size: 34)),
                const SizedBox(height: 8),
                Text('The page ${uri.path} does not exist. The link may be old.', style: FlowType.note(p, size: 15)),
                const SizedBox(height: 20),
                Pressable(tone: PressableTone.primary, onPressed: () => context.go(Routes.home), child: const Text('Back to Home')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
