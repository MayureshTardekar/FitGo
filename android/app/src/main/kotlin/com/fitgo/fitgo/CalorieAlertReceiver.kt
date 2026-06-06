package com.fitgo.fitgo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class CalorieAlertReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: "Monthly calorie warning"
        val message = intent.getStringExtra("message")
            ?: "Your calories are going out of bound."
        CalorieNotificationHelper.showNow(context, title, message)
    }
}
