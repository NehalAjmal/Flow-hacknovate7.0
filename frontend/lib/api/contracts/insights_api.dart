import 'dart:typed_data';

import '../models/day.dart';
import '../models/insights.dart';

/// /user/*, /forecast, /calendar/*, /export/* — team doc §5.6.
abstract interface class InsightsApi {
  Future<Dashboard> dashboard();
  Future<Patterns> patterns();
  Future<Forecast> forecast();

  /// GET /user/day?date=YYYY-MM-DD: the full timeline for the Day Score.
  Future<DayTimeline> day(DateTime date);

  /// GET /user/month?month=YYYY-MM: focus minutes per day for the terrain.
  Future<Map<DateTime, int>> month(DateTime month);

  /// Weekly Focus DNA card as PNG bytes.
  Future<Uint8List> focusDnaPng();
}

abstract interface class CalendarApi {
  /// Returns the Google OAuth URL to open in the system browser.
  Future<Uri> connect();
  Future<CalendarContext> context();
  Future<void> disconnect();
}
