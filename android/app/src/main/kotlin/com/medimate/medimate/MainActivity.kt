package com.medimate.medimate

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.RingtoneManager
import android.net.Uri
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var smsPermissionResult: MethodChannel.Result? = null
    private var tonePickerResult: MethodChannel.Result? = null

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
                            call.argument<String>("customToneUri"),
                            call.argument<String>("caregiverPhone"),
                            call.argument<String>("patientName"),
                        )
                        result.success(null)
                    }
                    "cancel" -> {
                        DoseAlarmScheduler.cancel(this, call.argument<Int>("occurrenceId") ?: 0)
                        result.success(null)
                    }
                    "cancelBatch" -> {
                        val ids = call.argument<List<Int>>("occurrenceIds") ?: emptyList()
                        DoseAlarmScheduler.cancelBatch(this, ids)
                        result.success(null)
                    }
                    "cancelCaregiverSms" -> {
                        DoseAlarmScheduler.cancelCaregiverSms(this, call.argument<Int>("occurrenceId") ?: 0)
                        result.success(null)
                    }
                    "cancelAll" -> {
                        DoseAlarmScheduler.cancelAll(this)
                        result.success(null)
                    }
                    "scheduleDailyReport" -> {
                        DoseAlarmScheduler.scheduleDailyReport(
                            this,
                            call.argument<Boolean>("enabled") ?: false,
                            call.argument<String>("caregiverPhone") ?: "",
                            call.argument<String>("patientName"),
                        )
                        result.success(null)
                    }
                    "preview" -> {
                        DoseAlarmService.preview(
                            this,
                            call.argument<String>("toneName") ?: "Serene Bell",
                            call.argument<String>("customToneUri"),
                        )
                        result.success(null)
                    }
                    "testAlarm" -> {
                        ContextCompat.startForegroundService(this, Intent(this, DoseAlarmService::class.java).apply {
                            putExtra("occurrence_id", -1)
                            putExtra("medicine_name", "DoseCare test alarm")
                            putExtra("dosage", "Check your alarm volume")
                            putExtra("tone_name", call.argument<String>("toneName") ?: "Serene Bell")
                            putExtra("custom_tone_uri", call.argument<String>("customToneUri"))
                        })
                        result.success(null)
                    }
                    "pickDeviceAlarmSound" -> {
                        tonePickerResult = result
                        startActivityForResult(Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_DEFAULT_URI, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                            call.argument<String>("existingUri")?.let {
                                putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(it))
                            }
                        }, tonePickerRequestCode)
                    }
                    "requestSmsPermission" -> {
                        if (checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) {
                            result.success(true)
                        } else {
                            smsPermissionResult = result
                            requestPermissions(arrayOf(Manifest.permission.SEND_SMS), smsPermissionRequestCode)
                        }
                    }
                    "isSmsPermissionGranted" -> {
                        result.success(checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED)
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

    @Deprecated("Deprecated in Android platform; retained for FlutterActivity compatibility.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == tonePickerRequestCode) {
            val uri = data?.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            tonePickerResult?.success(uri?.toString())
            tonePickerResult = null
        }
    }

    companion object {
        private const val smsPermissionRequestCode = 4051
        private const val tonePickerRequestCode = 4052
    }
}
