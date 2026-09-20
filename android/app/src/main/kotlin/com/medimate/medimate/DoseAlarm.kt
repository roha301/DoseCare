package com.medimate.medimate

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Build
import android.telephony.SmsManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

private const val channelId = "dosecare_active_alarm"
private const val ringAction = "com.medimate.medimate.RING_DOSE"
private const val stopAction = "com.medimate.medimate.STOP_DOSE_ALARM"
private const val snoozeAction = "com.medimate.medimate.SNOOZE_DOSE_ALARM"
private const val extraId = "occurrence_id"
private const val extraMedicine = "medicine_name"
private const val extraDosage = "dosage"
private const val extraTone = "tone_name"
private const val extraCustomToneUri = "custom_tone_uri"
private const val extraCaregiverPhone = "caregiver_phone"
private const val extraPatientName = "patient_name"
private const val caregiverSmsAction = "com.medimate.medimate.CAREGIVER_SMS"

object DoseAlarmScheduler {
    fun schedule(context: Context, occurrenceId: Int, medicineName: String, dosage: String, triggerAtMillis: Long, toneName: String, customToneUri: String? = null, caregiverPhone: String? = null, patientName: String? = null) {
        if (occurrenceId <= 0 || triggerAtMillis <= System.currentTimeMillis()) return
        val intent = Intent(context, DoseAlarmReceiver::class.java).apply {
            action = ringAction
            putExtra(extraId, occurrenceId)
            putExtra(extraMedicine, medicineName)
            putExtra(extraDosage, dosage)
            putExtra(extraTone, toneName)
            putExtra(extraCustomToneUri, customToneUri)
        }
        val pending = PendingIntent.getBroadcast(context, occurrenceId, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // Alarm-clock alarms remain exact and can start the alert service even
        // when Android has restricted ordinary background work.
        val launchIntent = PendingIntent.getActivity(
            context,
            occurrenceId,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarms.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAtMillis, launchIntent), pending)
        // Re-syncing reminders must also remove a previously scheduled
        // escalation when the caregiver option has since been turned off.
        val existingSmsIntent = Intent(context, CaregiverSmsReceiver::class.java).setAction(caregiverSmsAction)
        val existingSmsPending = PendingIntent.getBroadcast(context, 1_000_000 + occurrenceId, existingSmsIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        alarms.cancel(existingSmsPending)
        existingSmsPending.cancel()
        if (!caregiverPhone.isNullOrBlank()) {
            val smsIntent = Intent(context, CaregiverSmsReceiver::class.java).apply {
                action = caregiverSmsAction
                putExtra(extraId, occurrenceId)
                putExtra(extraMedicine, medicineName)
                putExtra(extraDosage, dosage)
                putExtra(extraCaregiverPhone, caregiverPhone)
                putExtra(extraPatientName, patientName ?: "The patient")
            }
            val smsPending = PendingIntent.getBroadcast(context, 1_000_000 + occurrenceId, smsIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis + 15 * 60 * 1000L, smsPending)
        }
    }

    fun cancel(context: Context, occurrenceId: Int) {
        val intent = Intent(context, DoseAlarmReceiver::class.java).setAction(ringAction)
        val pending = PendingIntent.getBroadcast(context, occurrenceId, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pending)
        pending.cancel()
        val smsIntent = Intent(context, CaregiverSmsReceiver::class.java).setAction(caregiverSmsAction)
        val smsPending = PendingIntent.getBroadcast(context, 1_000_000 + occurrenceId, smsIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(smsPending)
        smsPending.cancel()
        context.stopService(Intent(context, DoseAlarmService::class.java).putExtra(extraId, occurrenceId))
    }

    fun cancelCaregiverSms(context: Context, occurrenceId: Int) {
        val intent = Intent(context, CaregiverSmsReceiver::class.java)
            .setAction(caregiverSmsAction)
        val pending = PendingIntent.getBroadcast(
            context,
            1_000_000 + occurrenceId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pending)
        pending.cancel()
    }

    fun cancelAll(context: Context) {
        // Exact alarms are cancelled from Flutter using the IDs in SQLite.
        // This also stops any alarm that is already ringing after a reset.
        context.stopService(Intent(context, DoseAlarmService::class.java))
        DoseAlarmService.stopPreview()
        val notifications = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notifications.cancelAll()
    }
}

class CaregiverSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val phone = intent.getStringExtra(extraCaregiverPhone)?.trim().orEmpty()
        if (phone.isEmpty()) return
        val patient = intent.getStringExtra(extraPatientName)?.trim().takeUnless { it.isNullOrEmpty() } ?: "The patient"
        val medicine = intent.getStringExtra(extraMedicine) ?: "medication"
        val dosage = intent.getStringExtra(extraDosage).orEmpty()
        val message = "$patient has not recorded their $medicine${if (dosage.isEmpty()) "" else " ($dosage)"} dose 15 minutes after its scheduled time. Please check in with them."
        try {
            SmsManager.getDefault().sendTextMessage(phone, null, message, null, null)
        } catch (_: SecurityException) {
            // The permission prompt is shown when caregiver SMS is enabled.
        } catch (_: Exception) {
            // Invalid numbers or carrier failures must not crash the alarm flow.
        }
    }
}

class DoseAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ContextCompat.startForegroundService(context, Intent(context, DoseAlarmService::class.java).apply { putExtras(intent) })
    }
}

class DoseAlarmActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(extraId, 0)
        context.stopService(Intent(context, DoseAlarmService::class.java).putExtra(extraId, id))
        if (intent.action == snoozeAction && id > 0) {
            DoseAlarmScheduler.schedule(
                context, id,
                intent.getStringExtra(extraMedicine) ?: "Medication",
                intent.getStringExtra(extraDosage) ?: "",
                System.currentTimeMillis() + 10 * 60 * 1000L,
                intent.getStringExtra(extraTone) ?: "Serene Bell",
                intent.getStringExtra(extraCustomToneUri),
            )
        }
    }
}

class DoseAlarmService : Service() {
    private var toneGenerator: ToneGenerator? = null
    private var deviceRingtone: Ringtone? = null
    private val toneHandler = Handler(Looper.getMainLooper())
    private var toneLoop: Runnable? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val id = intent?.getIntExtra(extraId, 0) ?: 0
        val medicine = intent?.getStringExtra(extraMedicine) ?: "Medication"
        val dosage = intent?.getStringExtra(extraDosage) ?: ""
        val tone = intent?.getStringExtra(extraTone) ?: "Serene Bell"
        val customToneUri = intent?.getStringExtra(extraCustomToneUri)
        createChannel()
        startForeground(900000 + id, notification(id, medicine, dosage, tone, customToneUri))
        startAlarmTone(tone, customToneUri)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopAlarmTone()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // Flutter has no bundled alarm-tone library. These generated Android
    // alarm tones are app-controlled and never read the phone owner's chosen
    // ringtone or notification sound.
    private fun startAlarmTone(tone: String, customToneUri: String?) {
        stopAlarmTone()
        if (!customToneUri.isNullOrBlank()) {
            deviceRingtone = RingtoneManager.getRingtone(this, Uri.parse(customToneUri))?.also {
                it.audioAttributes = alarmAudioAttributes()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) it.isLooping = true
                it.play()
            }
            if (deviceRingtone != null) return
        }
        val toneType = toneType(tone)
        toneGenerator = ToneGenerator(AudioManager.STREAM_ALARM, 100)
        toneLoop = object : Runnable {
            override fun run() {
                toneGenerator?.startTone(toneType, 28_000)
                toneHandler.postDelayed(this, 27_000)
            }
        }.also { it.run() }
    }

    private fun stopAlarmTone() {
        toneLoop?.let(toneHandler::removeCallbacks)
        toneLoop = null
        toneGenerator?.stopTone()
        toneGenerator?.release()
        toneGenerator = null
        deviceRingtone?.let { if (it.isPlaying) it.stop() }
        deviceRingtone = null
    }

    private fun notification(id: Int, medicine: String, dosage: String, tone: String, customToneUri: String?): android.app.Notification {
        fun action(action: String, title: String, requestCode: Int): NotificationCompat.Action {
            val intent = Intent(this, DoseAlarmActionReceiver::class.java).apply {
                this.action = action
                putExtra(extraId, id)
                putExtra(extraMedicine, medicine)
                putExtra(extraDosage, dosage)
                putExtra(extraTone, tone)
                putExtra(extraCustomToneUri, customToneUri)
            }
            val pending = PendingIntent.getBroadcast(this, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            return NotificationCompat.Action(0, title, pending)
        }
        return NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Time for $medicine")
            .setContentText("Take $dosage. Alarm continues until stopped or snoozed.")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(action(stopAction, "Stop alarm", 100000 + id))
            .addAction(action(snoozeAction, "Snooze 10 min", 200000 + id))
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Active dose alarms", NotificationManager.IMPORTANCE_HIGH)
            channel.setSound(null, null)
            channel.enableVibration(true)
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
        }
    }

    companion object {
        private var previewTone: ToneGenerator? = null
        private var previewRingtone: Ringtone? = null
        fun preview(context: Context, tone: String, customToneUri: String?) {
            stopPreview()
            if (!customToneUri.isNullOrBlank()) {
                previewRingtone = RingtoneManager.getRingtone(context, Uri.parse(customToneUri))?.also {
                    it.audioAttributes = alarmAudioAttributes()
                    it.play()
                }
                Handler(Looper.getMainLooper()).postDelayed({ stopPreview() }, 2_500)
                if (previewRingtone != null) return
            }
            previewTone = ToneGenerator(AudioManager.STREAM_ALARM, 100).also {
                it.startTone(toneType(tone), 2_500)
            }
        }

        fun stopPreview() {
            previewTone?.stopTone()
            previewTone?.release()
            previewTone = null
            previewRingtone?.let { if (it.isPlaying) it.stop() }
            previewRingtone = null
        }
    }
}

private fun toneType(tone: String): Int = when (tone) {
    "Gentle Chime" -> ToneGenerator.TONE_PROP_BEEP2
    "Clinic Pulse" -> ToneGenerator.TONE_SUP_RADIO_ACK
    "Harbor Chime" -> ToneGenerator.TONE_CDMA_ABBR_ALERT
    "Soft Pulse" -> ToneGenerator.TONE_CDMA_SOFT_ERROR_LITE
    else -> ToneGenerator.TONE_SUP_RINGTONE
}

private fun alarmAudioAttributes(): AudioAttributes = AudioAttributes.Builder()
    .setUsage(AudioAttributes.USAGE_ALARM)
    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
    .build()
