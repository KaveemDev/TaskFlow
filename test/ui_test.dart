import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow_suite/widgets/ui.dart';

void main() {
  test('formatMinutes', () {
    expect(formatMinutes(0), '0m');
    expect(formatMinutes(40), '40m');
    expect(formatMinutes(60), '1h');
    expect(formatMinutes(325), '5h 25m');
  });

  test('week strip starts on Monday', () {
    expect(
      WeekStrip.mondayOf(DateTime(2026, 11, 5)),
      DateTime(2026, 11, 2),
    ); // Thursday
    expect(
      WeekStrip.mondayOf(DateTime(2026, 11, 8)),
      DateTime(2026, 11, 2),
    ); // Sunday
    expect(
      WeekStrip.mondayOf(DateTime(2026, 11, 2, 15)),
      DateUtils.dateOnly(DateTime(2026, 11, 2)),
    );
  });

  test('timeRange formats one-day and multi-day slots', () {
    expect(
      timeRange(DateTime(2026, 11, 5, 10, 30), DateTime(2026, 11, 5, 11, 15)),
      '10:30–11:15',
    );
    expect(timeRange(DateTime(2026, 11, 5, 10, 30), null), '10:30');
    expect(
      timeRange(DateTime(2026, 11, 5, 9), DateTime(2026, 11, 7, 18)),
      'Thu 5 Nov 09:00 – Sat 7 Nov 18:00',
    );
  });

  test('slotCoversDay', () {
    final from = DateTime(2026, 11, 5, 22),
        to = DateTime(2026, 11, 7, 0); // ends at midnight
    expect(slotCoversDay(from, to, DateTime(2026, 11, 4)), isFalse);
    expect(slotCoversDay(from, to, DateTime(2026, 11, 5)), isTrue);
    expect(slotCoversDay(from, to, DateTime(2026, 11, 6)), isTrue);
    expect(slotCoversDay(from, to, DateTime(2026, 11, 7)), isFalse);
    expect(slotCoversDay(from, null, DateTime(2026, 11, 5)), isFalse);
  });

  test('shiftDays keeps the time of day', () {
    expect(
      shiftDays(DateTime(2026, 10, 24, 9, 30), 7),
      DateTime(2026, 10, 31, 9, 30),
    );
    expect(shiftDays(DateTime(2026, 1, 31, 18), 1), DateTime(2026, 2, 1, 18));
  });
}
