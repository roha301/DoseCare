package com.medimate.medimate

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
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
private const val extraCaregiverPhone = "caregiver_phone"
private const val extraPatientName = "patient_name"
private const val caregiverSmsAction = "com.medimate.medimate.CAREGIVER_SMS"

object DoseAlarmScheduler {
    fun schedule(context: Context, occurrenceId: Int, medicineName: String, dosage: String, triggerAtMillis: Long, toneName: String, caregiverPhone: String? = null, patientName: String? = null) {
        if (occurrenceId <= 0 || triggerAtMillis <= System.currentTimeMillis()) return
        val intent = Intent(context, DoseAlarmReceiver::class.java).apply {
            action = ringAction
            putExtra(extraId, occurrenceId)
            putExtra(extraMedicine, medicineName)
            putExtra(extraDosage, dosage)
            putExtra(extraTone, toneName)
        }
        val pending = PendingIntent.getBroadcast(context, occurrenceId, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
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
        val smsIntent = Intent(context, CaregiverSmsReceiver::class.java).setAction(caregiverSmsAction)
        val smsPending = PendingIntent.getBroadcast(context, 1_000_000 + occurrenceId, smsIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(smsPending)
        smsPending.cancel()
        context.stopService(Intent(context, DoseAlarmService::class.java).putExtra(extraId, occurrenceId))
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
            )
        }
    }
}

class DoseAlarmService : Service() {
    private var ringtone: Ringtone? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val id = intent?.getIntExtra(extraId, 0) ?: 0
        val medicine = intent?.getStringExtra(extraMedicine) ?: "Medication"
        val dosage = intent?.getStringExtra(extraDosage) ?: ""
        val tone = intent?.getStringExtra(extraTone) ?: "Serene Bell"
        createChannel()
        startForeground(900000 + id, notification(id, medicine, dosage, tone))
        ringtone?.let { if (it.isPlaying) it.stop() }
        ringtone = RingtoneManager.getRingtone(this, toneUri(tone))?.also {
            it.audioAttributes = alarmAudioAttributes()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) it.isLooping = true
            it.play()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        ringtone?.let { if (it.isPlaying) it.stop() }
        ringtone = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun notification(id: Int, medicine: String, dosage: String, tone: String): android.app.Notification {
        fun action(action: String, title: String, requestCode: Int): NotificationCompat.Action {
            val intent = Intent(this, DoseAlarmActionReceiver::class.java).apply {
                this.action = action
                putExtra(extraId, id)
                putExtra(extraMedicine, medicine)
                putExtra(extraDosage, dosage)
                putExtra(extraTone, tone)
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
        private var preview: Ringtone? = null
        fun preview(context: Context, tone: String) {
            preview?.let { if (it.isPlaying) it.stop() }
            preview = RingtoneManager.getRingtone(context, toneUri(tone))?.also {
                it.audioAttributes = alarmAudioAttributes()
                it.play()
            }
        }
    }
}

private fun toneUri(tone: String): Uri {
    // Playback uses the alarm stream below, so these tone choices remain
    // audible even when ordinary notification sounds are muted.
    val type = when (tone) {
        "Gentle Chime" -> RingtoneManager.TYPE_RINGTONE
        "Clinic Pulse" -> RingtoneManager.TYPE_ALARM
        else -> RingtoneManager.TYPE_NOTIFICATION
    }
    return RingtoneManager.getDefaultUri(type)
        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
}

private fun alarmAudioAttributes(): AudioAttributes = AudioAttributes.Builder()
    .setUsage(AudioAttributes.USAGE_ALARM)
    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
    .build()
