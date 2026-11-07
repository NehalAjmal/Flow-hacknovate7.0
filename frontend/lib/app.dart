import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'desktop/compact_views.dart';
import 'dev/dev_panel.dart';
import 'router/app_router.dart';
import 'theme/input_kind.dart';
import 'theme/scrolling.dart';
import 'theme/tokens.dart';
import 'ui/brand/launch_overlay.dart';

class FlowApp extends ConsumerWidget {
  const FlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Flow',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(appRouterProvider),
      scrollBehavior: const FlowScrollBehavior(),
      // kDevBuild is const: in release this branch and DevShell are compiled out.
      builder: (context, child) {
        // Flow's type runs one step larger than platform defaults; the
        // person's own OS text size still multiplies on top.
        final mq = MediaQuery.of(context);
        final app = MediaQuery(
          data: mq.copyWith(textScaler: FlowTextScaler(mq.textScaler)),
          child: LaunchOverlay(
            child: WindowFrame(child: InputKindListener(child: child ?? const SizedBox())),
          ),
        );
        return kDevBuild ? DevShell(child: app) : app;
      },
    );
  }
}
