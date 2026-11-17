import 'package:fitgo/services/notification_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nextDaily', () {
    test('keeps a time later today', () {
      final now = DateTime(2026, 11, 16, 10, 30);
      expect(
        NotificationSchedule.nextDaily(now, 21, 0),
        DateTime(2026, 11, 16, 21, 0),
      );
    });

    test('rolls to tomorrow when the time has passed', () {
      final now = DateTime(2026, 11, 16, 21, 30);
      expect(
        NotificationSchedule.nextDaily(now, 21, 0),
        DateTime(2026, 11, 17, 21, 0),
      );
    });

    test('rolls across a month boundary', () {
      final now = DateTime(2026, 11, 30, 22, 0);
      expect(
        NotificationSchedule.nextDaily(now, 9, 15),
        DateTime(2026, 12, 1, 9, 15),
      );
    });
  });

  group('fastingReminders', () {
    test('covers a 36 hour fast with hourly reminders', () {
      final now = DateTime(2026, 11, 16, 8, 0);
      final times = NotificationSchedule.fastingReminders(
        now: now,
        end: now.add(const Duration(hours: 36)),
        interval: const Duration(hours: 1),
      );

      expect(times, hasLength(35));
      expect(times.first, now.add(const Duration(hours: 1)));
      expect(times.last, now.add(const Duration(hours: 35)));
    });

    test('starts from the last reminder instead of postponing it', () {
      final now = DateTime(2026, 11, 16, 8, 30);
      final last = DateTime(2026, 11, 16, 8, 0);
      final times = NotificationSchedule.fastingReminders(
        now: now,
        end: now.add(const Duration(hours: 16)),
        interval: const Duration(hours: 1),
        lastReminder: last,
      );

      expect(times.first, DateTime(2026, 11, 16, 9, 0));
    });

    test('moves a stale anchor out of the past', () {
      final now = DateTime(2026, 11, 16, 12, 0);
      final times = NotificationSchedule.fastingReminders(
        now: now,
        end: now.add(const Duration(hours: 4)),
        interval: const Duration(hours: 1),
        lastReminder: now.subtract(const Duration(hours: 3)),
      );

      expect(times.first, now.add(const Duration(minutes: 1)));
    });

    test('never exceeds the pending-notification budget', () {
      final now = DateTime(2026, 11, 16, 8, 0);
      final times = NotificationSchedule.fastingReminders(
        now: now,
        end: now.add(const Duration(hours: 24)),
        interval: const Duration(minutes: 15),
        maxCount: 60,
      );

      expect(times, hasLength(60));
    });

    test('returns nothing when the fast has already ended', () {
      final now = DateTime(2026, 11, 16, 12, 0);
      final times = NotificationSchedule.fastingReminders(
        now: now,
        end: now.subtract(const Duration(minutes: 1)),
        interval: const Duration(hours: 1),
      );

      expect(times, isEmpty);
    });

    test('returns nothing for a non-positive interval', () {
      final now = DateTime(2026, 11, 16, 12, 0);
      final times = NotificationSchedule.fastingReminders(
        now: now,
        end: now.add(const Duration(hours: 4)),
        interval: Duration.zero,
      );

      expect(times, isEmpty);
    });
  });
}
