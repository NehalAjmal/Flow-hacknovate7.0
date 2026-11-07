import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_connector.dart';
import '../api/models/consent.dart';
import '../api/models/settings.dart';
import 'auth_controller.dart';

/// Requires a signed-in user; throws otherwise so screens never render stale
/// data from a previous account.
String _requireUser(Ref ref) {
  final id = ref.watch(currentUserIdProvider);
  if (id == null) throw StateError('Not signed in');
  return id;
}

// ── consent ────────────────────────────────────────────────────────────────

class ConsentController extends AsyncNotifier<ConsentState> {
  @override
  Future<ConsentState> build() {
    _requireUser(ref);
    return ref.watch(consentApiProvider).get();
  }

  /// Grant or withdraw one scope. Withdrawing also switches the matching
  /// feature off so settings never claim something consent forbids.
  Future<void> set(ConsentScope scope, bool granted) async {
    final current = await future;
    final version = current.policyVersion ?? 'unversioned';
    final entry = await ref.read(consentApiProvider).set(scope, granted: granted, policyVersion: version);
    if (!ref.mounted) return;
    state = AsyncData(current.copyWithEntry(entry));

    if (!granted) {
      final patch = switch (scope) {
        ConsentScope.camera => const SettingsPatch(cameraEnabled: false),
        ConsentScope.calendar => const SettingsPatch(calendarEnabled: false),
        ConsentScope.llm => const SettingsPatch(llmEnabled: false),
        _ => null,
      };
      if (patch != null) await ref.read(settingsProvider.notifier).patch(patch);
      if (scope == ConsentScope.camera) {
        try {
          await ref.read(localAgentApiProvider).setCamera(false);
        } catch (_) {}
      }
    }
  }
}

final consentProvider = AsyncNotifierProvider<ConsentController, ConsentState>(ConsentController.new);

// ── settings ───────────────────────────────────────────────────────────────

class ConsentRequired implements Exception {
  const ConsentRequired(this.scope);
  final ConsentScope scope;
  @override
  String toString() => 'Consent required: ${scope.wire}';
}

class SettingsController extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() {
    _requireUser(ref);
    return ref.watch(settingsApiProvider).get();
  }

  /// Throws [ConsentRequired] when enabling a feature whose consent scope
  /// isn't granted; the UI then routes the user to the consent toggle.
  Future<void> patch(SettingsPatch patch) async {
    final consent = ref.read(consentProvider).value;
    void need(bool? enabling, ConsentScope s) {
      if (enabling == true && !(consent?.granted(s) ?? false)) throw ConsentRequired(s);
    }

    need(patch.cameraEnabled, ConsentScope.camera);
    need(patch.calendarEnabled, ConsentScope.calendar);
    need(patch.llmEnabled, ConsentScope.llm);

    final previous = state.value;
    if (previous != null) state = AsyncData(patch.applyTo(previous)); // optimistic
    try {
      final saved = await ref.read(settingsApiProvider).update(patch);
      if (ref.mounted) state = AsyncData(saved);
      if (patch.cameraEnabled != null) {
        try {
          await ref.read(localAgentApiProvider).setCamera(patch.cameraEnabled!);
        } catch (_) {}
      }
    } catch (_) {
      if (ref.mounted && previous != null) state = AsyncData(previous); // roll back
      rethrow;
    }
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsController, UserSettings>(SettingsController.new);

// ── global pause ───────────────────────────────────────────────────────────

class PauseController extends AsyncNotifier<PauseState> {
  @override
  Future<PauseState> build() {
    _requireUser(ref);
    return ref.watch(pauseApiProvider).get();
  }

  Future<void> pauseFor(int minutes) async {
    final s = await ref.read(pauseApiProvider).pause(minutes: minutes);
    if (ref.mounted) state = AsyncData(s);
  }

  Future<void> pauseForToday() async {
    final s = await ref.read(pauseApiProvider).pause(untilEndOfDay: true);
    if (ref.mounted) state = AsyncData(s);
  }

  Future<void> resume() async {
    final s = await ref.read(pauseApiProvider).resume();
    if (ref.mounted) state = AsyncData(s);
  }
}

final pauseProvider = AsyncNotifierProvider<PauseController, PauseState>(PauseController.new);
