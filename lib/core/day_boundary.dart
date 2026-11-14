/// Local calendar-day helpers shared by storage and the app lifecycle.
///
/// Days are always the user's local civil day (`yyyy-MM-dd`). Timestamps are
/// stored separately in UTC where a precise instant matters.
String localDateKey(DateTime time) {
  final local = time.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// The next local midnight after [now], used to refresh “Today” exactly once
/// per civil day.
DateTime nextLocalMidnight(DateTime now) {
  final local = now.toLocal();
  return DateTime(local.year, local.month, local.day + 1);
}
