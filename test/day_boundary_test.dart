import 'package:fitgo/core/day_boundary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('localDateKey pads months and days', () {
    expect(localDateKey(DateTime(2026, 1, 2, 23, 59)), '2026-01-02');
    expect(localDateKey(DateTime(2026, 11, 13, 0, 0)), '2026-11-13');
  });

  test('nextLocalMidnight is the following civil day', () {
    final next = nextLocalMidnight(DateTime(2026, 11, 13, 23, 59, 59));
    expect(next, DateTime(2026, 11, 14));
  });

  test('nextLocalMidnight crosses month and year boundaries', () {
    expect(nextLocalMidnight(DateTime(2026, 1, 31, 12)), DateTime(2026, 2, 1));
    expect(nextLocalMidnight(DateTime(2026, 12, 31, 23)), DateTime(2027, 1, 1));
  });
}
