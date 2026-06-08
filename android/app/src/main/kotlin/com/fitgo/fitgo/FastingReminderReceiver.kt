package com.fitgo.fitgo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class FastingReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val untilEpoch = intent.getLongExtra("until_epoch", 0L)
        if (untilEpoch > 0L && System.currentTimeMillis() >= untilEpoch) {
            FastingNotificationHelper.cancel(context)
            return
        }

        val title = intent.getStringExtra("title") ?: "Drink water"
        val message = intent.getStringExtra("message")
            ?: "Stay zero-calorie until your fast ends."
        FastingNotificationHelper.showNow(context, title, message)
        FastingNotificationHelper.scheduleNextFromPrefs(context)
    }
}
