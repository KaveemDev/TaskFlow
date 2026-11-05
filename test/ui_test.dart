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
    expect(WeekStrip.mondayOf(DateTime(2026, 11, 5)), DateTime(2026, 11, 2)); // Thursday
    expect(WeekStrip.mondayOf(DateTime(2026, 11, 8)), DateTime(2026, 11, 2)); // Sunday
    expect(WeekStrip.mondayOf(DateTime(2026, 11, 2, 15)), DateUtils.dateOnly(DateTime(2026, 11, 2)));
  });
}
