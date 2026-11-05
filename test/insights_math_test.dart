import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow_suite/models/focus_session_model.dart';
import 'package:taskflow_suite/models/task_model.dart';
import 'package:taskflow_suite/services/insights_math.dart';
import 'package:taskflow_suite/services/widget_service.dart';

FocusSession s(DateTime t, int m, [String? task]) => FocusSession(id: '$t', durationMinutes: m, timestamp: t, linkedTaskId: task);

void main() {
  final now = DateTime(2026, 11, 5, 15); // Thursday

  test('period bounds and offsets', () {
    expect(periodBounds(InsightPeriod.week, now, 0), (DateTime(2026, 11, 2), DateTime(2026, 11, 9)));
    expect(periodBounds(InsightPeriod.week, now, -1), (DateTime(2026, 10, 26), DateTime(2026, 11, 2)));
    expect(periodBounds(InsightPeriod.month, DateTime(2026, 1, 10), -1), (DateTime(2025, 12), DateTime(2026, 1)));
    expect(periodBounds(InsightPeriod.year, now, 0), (DateTime(2026), DateTime(2027)));
  });

  test('streaks: current survives an empty today, best finds the longest run', () {
    final sessions = [
      s(DateTime(2026, 11, 4, 9), 25), s(DateTime(2026, 11, 3, 9), 25), // current run: 2 (today empty)
      s(DateTime(2026, 10, 1, 9), 25), s(DateTime(2026, 10, 2, 9), 25), s(DateTime(2026, 10, 3, 9), 25),
    ];
    expect(streaks(sessions, now), (2, 3));
    expect(streaks(const [], now), (0, 0));
  });

  test('minutesByHour splits sessions across hours', () {
    final h = minutesByHour([s(DateTime(2026, 11, 5, 9, 50), 25)]);
    expect(h[9], 10);
    expect(h[10], 15);
    expect(h.reduce((a, b) => a + b), 25);
  });

  test('minutesByDayOfYear keys by day of year', () {
    final m = minutesByDayOfYear([s(DateTime(2026, 1, 1, 8), 30), s(DateTime(2026, 12, 31, 8), 20), s(DateTime(2025, 6, 1), 99)], 2026);
    expect(m, {0: 30, 364: 20});
  });

  test('countdown: pinned wins, otherwise nearest not overdue', () {
    final tasks = [
      Task(id: 'late', title: 'Late', dueDate: DateTime(2026, 11, 1)),
      Task(id: 'soon', title: 'Soon', dueDate: DateTime(2026, 11, 7)),
      Task(id: 'later', title: 'Later', dueDate: DateTime(2026, 12, 1)),
      Task(id: 'done', title: 'Done', dueDate: DateTime(2026, 11, 6), isCompleted: true),
    ];
    final items = WidgetService.countdownCandidates(tasks, const [], now);
    expect(items.map((i) => i.id), ['late', 'soon', 'later']);
    expect(WidgetService.pickCountdown(items, null, now)!.id, 'soon');
    expect(WidgetService.pickCountdown(items, 'later', now)!.id, 'later');
    expect(WidgetService.pickCountdown(items, 'gone', now)!.id, 'soon');
    expect(items.first.countdown(now), ('4', 'days overdue'));
    expect(items[1].countdown(now), ('2', 'days left'));
  });

  test('task duration falls back to the start–end range', () {
    final t = Task(id: 'a', title: 'a', startTime: DateTime(2026, 1, 1, 10), endTime: DateTime(2026, 1, 1, 11, 30));
    expect(t.effectiveDurationMinutes, 90);
    expect(Task(id: 'b', title: 'b', durationMinutes: 45).effectiveDurationMinutes, 45);
  });
}
