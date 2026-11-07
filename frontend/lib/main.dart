import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config.dart';
import 'dev/dev_panel.dart';
import 'desktop/desktop_host.dart';

Future<void> main(List<String> args) async {
  // Desktop: single instance (Windows), window setup, notifications.
  // Web and tests: a no-op.
  await prepareDesktop(args);
  runApp(
    ProviderScope(
      // Screens have explicit Retry buttons; silent automatic retries would
      // hammer a failing backend and hide errors.
      retry: (_, _) => null,
      overrides: kDevBuild ? devOverrides() : const [],
      child: const FlowApp(),
    ),
  );
}
