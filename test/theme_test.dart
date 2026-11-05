import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow_suite/theme/app_theme.dart';

void main() {
  const colors = AppColors(raised: Colors.grey, ring: Colors.grey, high: Colors.red, medium: Colors.amber, low: Colors.blueGrey);

  test('priority maps to its colour and falls back to low', () {
    expect(colors.priority('High'), Colors.red);
    expect(colors.priority('Medium'), Colors.amber);
    expect(colors.priority('Low'), Colors.blueGrey);
    expect(colors.priority(null), Colors.blueGrey);
  });

  test('accent names are unique, since they are saved to preferences', () {
    final names = AccentTheme.values.map((a) => a.name).toSet();
    expect(names.length, AccentTheme.values.length);
  });
}
