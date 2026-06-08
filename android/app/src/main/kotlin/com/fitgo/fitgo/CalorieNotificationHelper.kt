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
import java.util.Calendar

object CalorieNotificationHelper {
    private const val CHANNEL_ID = "fitgo_calorie_guard"
    private const val CHANNEL_NAME = "Calorie guard"
    private const val NOTIFICATION_ID = 4001
    private const val REQUEST_CODE = 4001

    fun scheduleDailyAlert(
        context: Context,
        title: String,
        message: String,
        hour: Int,
        minute: Int
    ) {
        createChannel(context)
        saveSchedule(context, title, message, hour, minute)

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = alertPendingIntent(context, title, message)
        alarmManager.cancel(pendingIntent)
        alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            nextTriggerAt(hour, minute),
            AlarmManager.INTERVAL_DAY,
            pendingIntent
        )
    }

    fun cancelDailyAlert(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = alertPendingIntent(context, "", "")
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
        context.getSharedPreferences("fitgo_notifications", Context.MODE_PRIVATE)
            .edit()
            .putBoolean("monthly_calorie_enabled", false)
            .apply()
    }

    fun showNow(context: Context, title: String, message: String) {
        if (!canPostNotifications(context)) return
        createChannel(context)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(context, title, message))
    }

    fun rescheduleFromPrefs(context: Context) {
        val prefs = context.getSharedPreferences("fitgo_notifications", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("monthly_calorie_enabled", false)) return
        scheduleDailyAlert(
            context = context,
            title = prefs.getString("monthly_calorie_title", "Monthly calorie warning")
                ?: "Monthly calorie warning",
            message = prefs.getString("monthly_calorie_message", "") ?: "",
            hour = prefs.getInt("monthly_calorie_hour", 21),
            minute = prefs.getInt("monthly_calorie_minute", 0)
        )
    }

    private fun saveSchedule(
        context: Context,
        title: String,
        message: String,
        hour: Int,
        minute: Int
    ) {
        context.getSharedPreferences("fitgo_notifications", Context.MODE_PRIVATE)
            .edit()
            .putBoolean("monthly_calorie_enabled", true)
            .putString("monthly_calorie_title", title)
            .putString("monthly_calorie_message", message)
            .putInt("monthly_calorie_hour", hour)
            .putInt("monthly_calorie_minute", minute)
            .apply()
    }

    private fun alertPendingIntent(
        context: Context,
        title: String,
        message: String
    ): PendingIntent {
        val intent = Intent(context, CalorieAlertReceiver::class.java)
            .putExtra("title", title)
            .putExtra("message", message)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun nextTriggerAt(hour: Int, minute: Int): Long {
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (calendar.timeInMillis <= System.currentTimeMillis()) {
            calendar.add(Calendar.DAY_OF_MONTH, 1)
        }
        return calendar.timeInMillis
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Warnings when monthly calories approach your limit"
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
