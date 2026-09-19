package com.medimate.medimate

import android.Manifest
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var smsPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "medimate/dose_alarm")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> {
                        DoseAlarmScheduler.schedule(
                            this,
                            call.argument<Int>("occurrenceId") ?: 0,
                            call.argument<String>("medicineName") ?: "Medication",
                            call.argument<String>("dosage") ?: "",
                            call.argument<Long>("triggerAtMillis") ?: 0L,
                            call.argument<String>("toneName") ?: "Serene Bell",
                            call.argument<String>("caregiverPhone"),
                            call.argument<String>("patientName"),
                        )
                        result.success(null)
                    }
                    "cancel" -> {
                        DoseAlarmScheduler.cancel(this, call.argument<Int>("occurrenceId") ?: 0)
                        result.success(null)
                    }
                    "preview" -> {
                        DoseAlarmService.preview(this, call.argument<String>("toneName") ?: "Serene Bell")
                        result.success(null)
                    }
                    "requestSmsPermission" -> {
                        if (checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) {
                            result.success(true)
                        } else {
                            smsPermissionResult = result
                            requestPermissions(arrayOf(Manifest.permission.SEND_SMS), smsPermissionRequestCode)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == smsPermissionRequestCode) {
            smsPermissionResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            smsPermissionResult = null
        }
    }

    companion object {
        private const val smsPermissionRequestCode = 4051
    }
}
