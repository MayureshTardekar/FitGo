package com.fitgo.fitgo

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

object FastingNotificationHelper {
    private const val CHANNEL_ID = "fitgo_fasting_alerts"
    private const val CHANNEL_NAME = "Fasting alerts"
    private const val NOTIFICATION_ID = 5001
    private const val REQUEST_CODE = 5001
    private const val PREFS = "fitgo_notifications"

    fun scheduleRepeating(
        context: Context,
        intervalMinutes: Int,
        untilEpoch: Long,
        title: String,
        message: String
    ) {
        val now = System.currentTimeMillis()
        if (untilEpoch <= now) {
            cancel(context)
            return
        }

        createChannel(context)
        val safeIntervalMinutes = intervalMinutes.coerceAtLeast(15)
        val intervalMillis = safeIntervalMinutes * 60_000L
        val firstTrigger = (now + intervalMillis).coerceAtMost(untilEpoch)

        saveSchedule(context, safeIntervalMinutes, untilEpoch, title, message)

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = reminderPendingIntent(context, title, message, untilEpoch)
        alarmManager.cancel(pendingIntent)
        scheduleAlarm(alarmManager, firstTrigger, pendingIntent)
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = reminderPendingIntent(context, "", "", 0L)
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean("fasting_reminder_enabled", false)
            .apply()
    }

    fun showNow(context: Context, title: String, message: String) {
        if (!canPostNotifications(context)) return
        createChannel(context)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(context, title, message))
    }

    fun rescheduleFromPrefs(context: Context) {
        scheduleNextFromPrefs(context)
    }

    fun scheduleNextFromPrefs(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("fasting_reminder_enabled", false)) return

        val untilEpoch = prefs.getLong("fasting_reminder_until_epoch", 0L)
        if (untilEpoch <= System.currentTimeMillis()) {
            cancel(context)
            return
        }

        val intervalMinutes = prefs.getInt("fasting_reminder_interval", 60).coerceAtLeast(15)
        val intervalMillis = intervalMinutes * 60_000L
        val title = prefs.getString("fasting_reminder_title", "Drink water") ?: "Drink water"
        val message = prefs.getString(
            "fasting_reminder_message",
            "Stay zero-calorie until your fast ends."
        ) ?: "Stay zero-calorie until your fast ends."
        val nextTrigger = (System.currentTimeMillis() + intervalMillis).coerceAtMost(untilEpoch)

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = reminderPendingIntent(context, title, message, untilEpoch)
        alarmManager.cancel(pendingIntent)
        scheduleAlarm(alarmManager, nextTrigger, pendingIntent)
    }

    private fun saveSchedule(
        context: Context,
        intervalMinutes: Int,
        untilEpoch: Long,
        title: String,
        message: String
    ) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean("fasting_reminder_enabled", true)
            .putInt("fasting_reminder_interval", intervalMinutes)
            .putLong("fasting_reminder_until_epoch", untilEpoch)
            .putString("fasting_reminder_title", title)
            .putString("fasting_reminder_message", message)
            .apply()
    }

    private fun scheduleAlarm(
        alarmManager: AlarmManager,
        triggerAtMillis: Long,
        pendingIntent: PendingIntent
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        } else {
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        }
    }

    private fun reminderPendingIntent(
        context: Context,
        title: String,
        message: String,
        untilEpoch: Long
    ): PendingIntent {
        val intent = Intent(context, FastingReminderReceiver::class.java)
            .putExtra("title", title)
            .putExtra("message", message)
            .putExtra("until_epoch", untilEpoch)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Water and zero-calorie reminders during fasting"
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(
        context: Context,
        title: String,
        message: String
    ): Notification {
        val openIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        return builder
            .setSmallIcon(R.drawable.ic_stat_fitgo)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(Notification.BigTextStyle().bigText(message))
            .setContentIntent(openIntent)
            .setAutoCancel(true)
            .build()
    }

    private fun canPostNotifications(context: Context): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }
}
