package com.fitgo.fitgo

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fitgo/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> requestNotificationPermission(result)
                    "scheduleMonthlyCalorieAlert" -> {
                        CalorieNotificationHelper.scheduleDailyAlert(
                            context = this,
                            title = call.argument<String>("title") ?: "Monthly calorie warning",
                            message = call.argument<String>("message")
                                ?: "Your calories are going out of bound.",
                            hour = call.argument<Int>("hour") ?: 21,
                            minute = call.argument<Int>("minute") ?: 0
                        )
                        result.success(true)
                    }
                    "showMonthlyCalorieAlertNow" -> {
                        CalorieNotificationHelper.showNow(
                            context = this,
                            title = call.argument<String>("title") ?: "Monthly calorie warning",
                            message = call.argument<String>("message")
                                ?: "Your calories are going out of bound."
                        )
                        result.success(true)
                    }
                    "cancelMonthlyCalorieAlert" -> {
                        CalorieNotificationHelper.cancelDailyAlert(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }

        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }

        permissionResult = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4001)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4001) {
            val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            permissionResult?.success(granted)
            permissionResult = null
        }
    }
}
