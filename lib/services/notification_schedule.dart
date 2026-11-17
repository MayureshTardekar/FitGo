/// Pure scheduling math for local notifications.
///
/// Kept separate from the platform plugin so the edge cases can be tested
/// without a device: day rollover, stale reminder anchors, the end of a fast,
/// and the iOS pending-notification limit.
class NotificationSchedule {
  NotificationSchedule._();

  /// The next occurrence of [hour]:[minute] after [now].
  static DateTime nextDaily(DateTime now, int hour, int minute) {
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    if (today.isAfter(now)) return today;
    // Construct tomorrow from calendar fields, not a 24-hour Duration, so a
    // DST transition does not shift the chosen wall-clock time.
    return DateTime(now.year, now.month, now.day + 1, hour, minute);
  }

  /// A finite series of fasting reminder times before [end].
  ///
  /// [lastReminder] keeps a reschedule from postponing the next reminder just
  /// because the app was reopened. A stale anchor is moved to one minute from
  /// now instead of producing a notification in the past.
  static List<DateTime> fastingReminders({
    required DateTime now,
    required DateTime end,
    required Duration interval,
    DateTime? lastReminder,
    int maxCount = 60,
  }) {
    if (!end.isAfter(now) || interval.inMinutes <= 0 || maxCount <= 0) {
      return const [];
    }

    var next = lastReminder != null
        ? lastReminder.add(interval)
        : now.add(interval);
    if (!next.isAfter(now)) {
      next = now.add(const Duration(minutes: 1));
    }

    final times = <DateTime>[];
    while (next.isBefore(end) && times.length < maxCount) {
      times.add(next);
      next = next.add(interval);
    }
    return times;
  }
}
