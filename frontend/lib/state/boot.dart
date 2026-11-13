import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_controllers.dart';
import 'auth_controller.dart';
import 'data_providers.dart';
import 'session_controller.dart';

/// Everything Home needs for its first frame, loaded *before* the app is
/// shown, so it arrives whole instead of filling in piece by piece.
///
/// The launch screen holds its reveal on this, and after a sign-in the shell
/// shows one loader until it completes. It never blocks for long: a slow or
/// failing request is given [cap] and then the app opens anyway (each part
/// still has its own loader and retry).
///
/// Re-runs when the signed-in user changes; signed out there is nothing to load.
final bootReadyProvider = FutureProvider<void>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  Future<void> quiet(Future<Object?> f) => f.then<void>((_) {}, onError: (Object _) {});
  await Future.wait([
    quiet(ref.read(settingsProvider.future)),
    quiet(ref.read(consentProvider.future)),
    quiet(ref.read(liveSessionProvider.future)),
    quiet(ref.read(dayTimelineProvider(today).future)),
    quiet(ref.read(rollingMinutesProvider.future)),
    quiet(ref.read(preCheckProvider.future)),
    quiet(ref.read(schedulesProvider.future)),
  ]).timeout(cap, onTimeout: () => const []);
});

/// The longest the launch reveal (or the post-sign-in loader) waits for data.
const cap = Duration(seconds: 4);
