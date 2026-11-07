import 'package:flow/api/mock/mock_backend.dart';
import 'package:flow/api/mock/mock_day.dart';
import 'package:flow/api/models/day.dart';
import 'package:flow/ui/score/day_score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 7, 15, 12);

  test('auto-fit: 30 min padding, half-hour snapped, at least 6 h', () {
    final d = mockDay(MockBackend(), now, newUser: false, nowOverride: now);
    final r = scoreRange(d, now);
    expect(r.start.minute % 30, 0);
    expect(r.end.minute % 30, 0);
    expect(r.end.difference(r.start).inHours, greaterThanOrEqualTo(6));
    final first = d.sessions.map((s) => s.start).reduce((a, b) => a.isBefore(b) ? a : b);
    expect(r.start.isBefore(first.subtract(const Duration(minutes: 29))), isTrue);
  });

  test('auto-fit expands for a long ghost block', () {
    final d = mockDay(MockBackend(), now, newUser: false, nowOverride: now);
    final r0 = scoreRange(d, now);
    final r1 = scoreRange(d, now, ghostMinutes: 180 + 60 * 4);
    expect(r1.end.isAfter(r0.end), isTrue);
  });

  test('new user: empty day still gets a 6 h axis', () {
    final d = mockDay(MockBackend(), now, newUser: true, nowOverride: now);
    final r = scoreRange(d, now);
    expect(r.end.difference(r.start).inHours, greaterThanOrEqualTo(6));
  });

  test('mock day: nudges only where pressure reaches the line; widths are real durations', () {
    final d = mockDay(MockBackend(), now, newUser: false, nowOverride: now);
    for (final n in d.nudges) {
      expect(d.pressureAt(n.at), closeTo(1.0, 0.02));
    }
    for (final s in d.sessions.where((s) => s.state == TimelineSessionState.done)) {
      expect(s.end.isAfter(s.start), isTrue);
      expect(s.end.isBefore(now) || s.end == now, isTrue);
    }
  });
}
