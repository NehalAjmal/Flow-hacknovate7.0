import '../models/consent.dart';
import '../models/privacy.dart';
import '../models/settings.dart';

/// /consent — team doc §5.2.
abstract interface class ConsentApi {
  Future<ConsentState> get();
  Future<ConsentEntry> set(ConsentScope scope, {required bool granted, required String policyVersion});
}

/// /settings — team doc §5.2.
abstract interface class SettingsApi {
  Future<UserSettings> get();

  /// Returns the full settings after the partial update.
  Future<UserSettings> update(SettingsPatch patch);
}

/// /pause — team doc §5.2. Pauses Flow globally (not one session).
abstract interface class PauseApi {
  Future<PauseState> get();
  Future<PauseState> pause({int? minutes, bool untilEndOfDay = false});
  Future<PauseState> resume();
}

/// /me/* — team doc §5.7.
abstract interface class PrivacyApi {
  Future<DataSummary> dataSummary();
  Future<ExportJob> requestExport();
  Future<ExportJob> exportStatus(String id);

  /// Irreversible. Caller must confirm with the user first.
  Future<void> deleteAccount();
}
