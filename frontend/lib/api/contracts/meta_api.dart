import '../models/meta.dart';

/// /flags, /feedback, /changelog — team doc §5.9.
abstract interface class MetaApi {
  Future<FeatureFlags> flags();
  Future<void> sendFeedback(FeedbackRequest req);
  Future<List<ChangelogEntry>> changelog();
}
