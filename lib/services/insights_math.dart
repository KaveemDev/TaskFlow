import '../models/focus_session_model.dart';

/// Pure date and aggregation helpers behind the Insights screen.

enum InsightPeriod { week, month, year }

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// [start, end) of the period that contains [anchor], shifted by [offset] periods.
(DateTime, DateTime) periodBounds(
  InsightPeriod p,
  DateTime anchor,
  int offset,
) {
  final a = _day(anchor);
  switch (p) {
    case InsightPeriod.week:
      final monday = DateTime(
        a.year,
        a.month,
        a.day - (a.weekday - 1) + 7 * offset,
      );
      return (monday, DateTime(monday.year, monday.month, monday.day + 7));
    case InsightPeriod.month:
      return (
        DateTime(a.year, a.month + offset),
        DateTime(a.year, a.month + offset + 1),
      );
    case InsightPeriod.year:
      return (DateTime(a.year + offset), DateTime(a.year + offset + 1));
  }
}

List<FocusSession> sessionsIn(
  List<FocusSession> all,
  DateTime start,
  DateTime end,
) => all
    .where((s) => !s.timestamp.isBefore(start) && s.timestamp.isBefore(end))
    .toList();

int totalMinutes(Iterable<FocusSession> s) =>
    s.fold(0, (sum, x) => sum + x.durationMinutes);

/// (current, best) runs of consecutive days with at least one focus session.
/// The current run survives a today without focus as long as yesterday had some.
(int, int) streaks(List<FocusSession> sessions, DateTime now) {
  final days = sessions.map((s) => _day(s.timestamp)).toSet();
  final today = _day(now);
  var day = days.contains(today)
      ? today
      : DateTime(today.year, today.month, today.day - 1);
  var current = 0;
  while (days.contains(day)) {
    current++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  var best = 0;
  for (final d in days) {
    if (days.contains(DateTime(d.year, d.month, d.day - 1)))
      continue; // not the start of a run
    var len = 0;
    var x = d;
    while (days.contains(x)) {
      len++;
      x = DateTime(x.year, x.month, x.day + 1);
    }
    if (len > best) best = len;
  }
  return (current, best);
}

/// Focus minutes per hour of the day, splitting sessions that cross an hour boundary.
List<int> minutesByHour(Iterable<FocusSession> sessions) {
  final hours = List.filled(24, 0);
  for (final s in sessions) {
    var t = s.timestamp;
    var left = s.durationMinutes;
    while (left > 0) {
      final take = (60 - t.minute).clamp(1, left);
      hours[t.hour] += take;
      left -= take;
      t = t.add(Duration(minutes: take));
    }
  }
  return hours;
}

/// Focus minutes per calendar day of [year], keyed by day of year (0-based).
Map<int, int> minutesByDayOfYear(Iterable<FocusSession> sessions, int year) {
  final out = <int, int>{};
  final jan1 = DateTime.utc(year);
  for (final s in sessions.where((s) => s.timestamp.year == year)) {
    final d = DateTime.utc(
      year,
      s.timestamp.month,
      s.timestamp.day,
    ).difference(jan1).inDays;
    out[d] = (out[d] ?? 0) + s.durationMinutes;
  }
  return out;
}
