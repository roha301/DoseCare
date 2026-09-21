package com.medimate.medimate

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
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
import java.util.concurrent.ConcurrentHashMap
import java.util.Calendar

private const val channelId = "dosecare_active_alarm"
private const val individualChannelId = "dosecare_reminders"
private const val ringAction = "com.medimate.medimate.RING_DOSE"
private const val stopAction = "com.medimate.medimate.STOP_DOSE_ALARM"
private const val snoozeAction = "com.medimate.medimate.SNOOZE_DOSE_ALARM"
private const val stopAllAction = "com.medimate.medimate.STOP_ALL_DOSE_ALARMS"
private const val extraId = "occurrence_id"
private const val extraMedicine = "medicine_name"
private const val extraDosage = "dosage"
private const val extraTone = "tone_name"
private const val extraCustomToneUri = "custom_tone_uri"
private const val extraCaregiverPhone = "caregiver_phone"
private const val extraPatientName = "patient_name"
private const val caregiverSmsAction = "com.medimate.medimate.CAREGIVER_SMS"
private const val dailyReportAction = "com.medimate.medimate.DAILY_CAREGIVER_REPORT"
private const val dailyReportRequestCode = 2_000_000
private const val dailyReportPreferences = "dosecare_daily_report"

data class ActiveDose(
    val id: Int,
    val medicine: String,
    val dosage: String,
    val tone: String,
    val customToneUri: String?,
)

object DoseAlarmScheduler {
    fun scheduleDailyReport(
        context: Context,
        enabled: Boolean,
        caregiverPhone: String,
        patientName: String? = null,
    ) {
        context.getSharedPreferences(dailyReportPreferences, Context.MODE_PRIVATE)
            .edit()
            .putBoolean("enabled", enabled)
            .putString("phone", caregiverPhone)
            .putString("patient", patientName)
            .apply()
        val intent = Intent(context, DailyCaregiverReportReceiver::class.java).apply {
            action = dailyReportAction
            data = Uri.parse("dosecare://sms/daily-report")
            putExtra(extraCaregiverPhone, caregiverPhone)
            putExtra(extraPatientName, patientName ?: "The patient")
        }
        val pending = PendingIntent.getBroadcast(
            context, dailyReportRequestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarms.cancel(pending)
        if (!enabled || caregiverPhone.isBlank()) {
            pending.cancel()
            return
        }

        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 23)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.timeInMillis, pending)
        } else {
            alarms.setExact(AlarmManager.RTC_WAKEUP, next.timeInMillis, pending)
        }
    }

    fun schedule(
        context: Context,
        occurrenceId: Int,
        medicineName: String,
        dosage: String,
        triggerAtMillis: Long,
        toneName: String,
        customToneUri: String? = null,
        caregiverPhone: String? = null,
        patientName: String? = null
    ) {
        if (occurrenceId <= 0 || triggerAtMillis <= System.currentTimeMillis()) return

        val intent = Intent(context, DoseAlarmReceiver::class.java).apply {
            action = ringAction
            // Distinct data URI so Intent.filterEquals() treats each occurrence as unique
            data = Uri.parse("dosecare://alarm/$occurrenceId")
            putExtra(extraId, occurrenceId)
            putExtra(extraMedicine, medicineName)
            putExtra(extraDosage, dosage)
            putExtra(extraTone, toneName)
            putExtra(extraCustomToneUri, customToneUri)
        }
        val pending = PendingIntent.getBroadcast(
            context,
            occurrenceId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // Use setExactAndAllowWhileIdle so multiple alarms at the same timestamp do NOT cancel each other!
        // AlarmManager.setAlarmClock is limited to 1 clock per user and cancels earlier alarm clocks.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
        } else {
            alarms.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
        }

        // Caregiver SMS
        val existingSmsIntent = Intent(context, CaregiverSmsReceiver::class.java).apply {
            action = caregiverSmsAction
            data = Uri.parse("dosecare://sms/$occurrenceId")
        }
        val existingSmsPending = PendingIntent.getBroadcast(
            context,
            1_000_000 + occurrenceId,
            existingSmsIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarms.cancel(existingSmsPending)
        existingSmsPending.cancel()

        if (!caregiverPhone.isNullOrBlank()) {
            val smsIntent = Intent(context, CaregiverSmsReceiver::class.java).apply {
                action = caregiverSmsAction
                data = Uri.parse("dosecare://sms/$occurrenceId")
                putExtra(extraId, occurrenceId)
                putExtra(extraMedicine, medicineName)
                putExtra(extraDosage, dosage)
                putExtra(extraCaregiverPhone, caregiverPhone)
                putExtra(extraPatientName, patientName ?: "The patient")
            }
            val smsPending = PendingIntent.getBroadcast(
                context,
                1_000_000 + occurrenceId,
                smsIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis + 15 * 60 * 1000L, smsPending)
            } else {
                alarms.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis + 15 * 60 * 1000L, smsPending)
            }
        }
    }

    fun cancel(context: Context, occurrenceId: Int) {
        val intent = Intent(context, DoseAlarmReceiver::class.java).apply {
            action = ringAction
            data = Uri.parse("dosecare://alarm/$occurrenceId")
        }
        val pending = PendingIntent.getBroadcast(
            context,
            occurrenceId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pending)
        pending.cancel()

        val smsIntent = Intent(context, CaregiverSmsReceiver::class.java).apply {
            action = caregiverSmsAction
            data = Uri.parse("dosecare://sms/$occurrenceId")
        }
        val smsPending = PendingIntent.getBroadcast(
            context,
            1_000_000 + occurrenceId,
            smsIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(smsPending)
        smsPending.cancel()

        DoseAlarmService.dismissDose(context, occurrenceId)
    }

    fun cancelBatch(context: Context, occurrenceIds: List<Int>) {
        occurrenceIds.forEach { cancel(context, it) }
    }

    fun cancelCaregiverSms(context: Context, occurrenceId: Int) {
        val intent = Intent(context, CaregiverSmsReceiver::class.java).apply {
            action = caregiverSmsAction
            data = Uri.parse("dosecare://sms/$occurrenceId")
        }
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
        DoseAlarmService.stopAll(context)
        val notifications = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notifications.cancelAll()
    }
}

/** Sends a concise report using the persisted SQLite data, without needing to
 * start Flutter. It also queues tomorrow's report before returning. */
class DailyCaregiverReportReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!context.getSharedPreferences(dailyReportPreferences, Context.MODE_PRIVATE)
                .getBoolean("enabled", false)) return
        val phone = intent.getStringExtra(extraCaregiverPhone)?.trim().orEmpty()
        val patient = intent.getStringExtra(extraPatientName)?.trim().takeUnless { it.isNullOrEmpty() } ?: "The patient"
        if (phone.isNotEmpty()) {
            val report = buildReport(context, patient)
            try {
                SmsManager.getDefault().sendTextMessage(phone, null, report, null, null)
            } catch (_: SecurityException) {
            } catch (_: Exception) {
            }
            DoseAlarmScheduler.scheduleDailyReport(context, true, phone, patient)
        }
    }

    private fun buildReport(context: Context, patient: String): String {
        var total = 0
        var taken = 0
        var skipped = 0
        var pending = 0
        try {
            val databaseFile = context.getDatabasePath("medimate.db")
            if (databaseFile.exists()) {
                SQLiteDatabase.openDatabase(databaseFile.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                    db.rawQuery(
                        """SELECT status, COUNT(*) FROM dose_occurrences
                           WHERE date(scheduled_at) = date('now', 'localtime')
                           GROUP BY status""".trimIndent(), null,
                    ).use { cursor ->
                        while (cursor.moveToNext()) {
                            val count = cursor.getInt(1)
                            total += count
                            when (cursor.getString(0)) {
                                "TAKEN" -> taken += count
                                "SKIPPED", "MISSED", "NOT_TAKEN" -> skipped += count
                                else -> pending += count
                            }
                        }
                    }
                }
            }
        } catch (_: Exception) {
            return "DoseCare daily report for $patient: medication data could not be read. Please check in with them."
        }
        return if (total == 0) {
            "DoseCare daily report for $patient: no doses were scheduled today."
        } else {
            "DoseCare daily report for $patient: $taken of $total doses recorded taken; $skipped missed/skipped; $pending still unrecorded."
        }
    }
}

/** Restores the next report after Android clears exact alarms on a reboot. */
class DailyCaregiverReportBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val preferences = context.getSharedPreferences(dailyReportPreferences, Context.MODE_PRIVATE)
        DoseAlarmScheduler.scheduleDailyReport(
            context,
            preferences.getBoolean("enabled", false),
            preferences.getString("phone", "").orEmpty(),
            preferences.getString("patient", null),
        )
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
        } catch (_: Exception) {
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
        if (intent.action == stopAllAction) {
            DoseAlarmScheduler.cancelAll(context)
            return
        }

        if (id > 0) {
            DoseAlarmService.dismissDose(context, id)
            if (intent.action == snoozeAction) {
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
}

class DoseAlarmService : Service() {
    private var toneGenerator: ToneGenerator? = null
    private var deviceRingtone: Ringtone? = null
    private val toneHandler = Handler(Looper.getMainLooper())
    private var toneLoop: Runnable? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        instance = this
        val id = intent?.getIntExtra(extraId, 0) ?: 0
        if (id != 0) {
            val medicine = intent?.getStringExtra(extraMedicine) ?: "Medication"
            val dosage = intent?.getStringExtra(extraDosage) ?: ""
            val tone = intent?.getStringExtra(extraTone) ?: "Serene Bell"
            val customToneUri = intent?.getStringExtra(extraCustomToneUri)

            activeDoses[id] = ActiveDose(id, medicine, dosage, tone, customToneUri)

            createChannels()

            // 1. Post/update foreground notification summarizing all active medications
            val fgNotification = buildCombinedForegroundNotification()
            startForeground(FOREGROUND_NOTIFICATION_ID, fgNotification)

            // 2. Post individual notification for every active medication so the user sees all distinct medicine cards!
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            for (dose in activeDoses.values) {
                notificationManager.notify(500000 + dose.id, buildIndividualNotification(dose))
            }

            // 3. Start alarm tone
            startAlarmTone(tone, customToneUri)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopAlarmTone()
        instance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startAlarmTone(tone: String, customToneUri: String?) {
        if (deviceRingtone?.isPlaying == true || toneLoop != null) return
        stopAlarmTone()
        val uri = if (!customToneUri.isNullOrBlank()) {
            Uri.parse(customToneUri)
        } else {
            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        }
        if (uri != null) {
            deviceRingtone = RingtoneManager.getRingtone(this, uri)?.also {
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

    private fun updateForegroundNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val fgNotification = buildCombinedForegroundNotification()
        notificationManager.notify(FOREGROUND_NOTIFICATION_ID, fgNotification)
    }

    private fun buildCombinedForegroundNotification(): android.app.Notification {
        val count = activeDoses.size
        val launchIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = if (count == 1) {
            val dose = activeDoses.values.first()
            "Time for ${dose.medicine}"
        } else {
            "Time for $count Medications"
        }

        val shortSummary = activeDoses.values.joinToString(", ") { "${it.medicine} (${it.dosage})" }
        val bulletList = activeDoses.values.joinToString("\n") { "• ${it.medicine}: ${it.dosage}" }

        val stopAllIntent = Intent(this, DoseAlarmActionReceiver::class.java).apply {
            action = stopAllAction
        }
        val stopAllPending = PendingIntent.getBroadcast(
            this,
            999998,
            stopAllIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(shortSummary)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bulletList))
            .setContentIntent(launchIntent)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(NotificationCompat.Action(0, "Stop All", stopAllPending))

        return builder.build()
    }

    private fun buildIndividualNotification(dose: ActiveDose): android.app.Notification {
        fun action(action: String, title: String, requestCode: Int): NotificationCompat.Action {
            val intent = Intent(this, DoseAlarmActionReceiver::class.java).apply {
                this.action = action
                data = Uri.parse("dosecare://action/${dose.id}/$requestCode")
                putExtra(extraId, dose.id)
                putExtra(extraMedicine, dose.medicine)
                putExtra(extraDosage, dose.dosage)
                putExtra(extraTone, dose.tone)
                putExtra(extraCustomToneUri, dose.customToneUri)
            }
            val pending = PendingIntent.getBroadcast(
                this,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            return NotificationCompat.Action(0, title, pending)
        }

        val launchIntent = PendingIntent.getActivity(
            this,
            dose.id,
            Intent(this, MainActivity::class.java).apply {
                data = Uri.parse("dosecare://view/${dose.id}")
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, individualChannelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Time for ${dose.medicine}")
            .setContentText("Take ${dose.dosage} now.")
            .setContentIntent(launchIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .addAction(action(stopAction, "Dismiss", 100000 + dose.id))
            .addAction(action(snoozeAction, "Snooze 10m", 200000 + dose.id))
            .build()
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val alarmChannel = NotificationChannel(channelId, "Active dose alarms", NotificationManager.IMPORTANCE_HIGH).apply {
                setSound(null, null)
                enableVibration(true)
            }
            manager.createNotificationChannel(alarmChannel)

            val reminderChannel = NotificationChannel(individualChannelId, "Medication Reminders", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Time to take your scheduled medication"
                enableVibration(true)
            }
            manager.createNotificationChannel(reminderChannel)
        }
    }

    companion object {
        private const val FOREGROUND_NOTIFICATION_ID = 999999
        private val activeDoses = ConcurrentHashMap<Int, ActiveDose>()
        private var instance: DoseAlarmService? = null

        fun dismissDose(context: Context, occurrenceId: Int) {
            activeDoses.remove(occurrenceId)
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(500000 + occurrenceId)

            val currentService = instance
            if (currentService != null) {
                if (activeDoses.isEmpty()) {
                    currentService.stopAlarmTone()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        currentService.stopForeground(STOP_FOREGROUND_REMOVE)
                    } else {
                        @Suppress("DEPRECATION")
                        currentService.stopForeground(true)
                    }
                    currentService.stopSelf()
                } else {
                    currentService.updateForegroundNotification()
                }
            } else {
                if (activeDoses.isEmpty()) {
                    notificationManager.cancel(FOREGROUND_NOTIFICATION_ID)
                }
            }
        }

        fun stopAll(context: Context) {
            activeDoses.clear()
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(FOREGROUND_NOTIFICATION_ID)

            val currentService = instance
            if (currentService != null) {
                currentService.stopAlarmTone()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    currentService.stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    currentService.stopForeground(true)
                }
                currentService.stopSelf()
            }
            stopPreview()
        }

        private var previewTone: ToneGenerator? = null
        private var previewRingtone: Ringtone? = null

        fun preview(context: Context, tone: String, customToneUri: String?) {
            stopPreview()
            val uri = if (!customToneUri.isNullOrBlank()) {
                Uri.parse(customToneUri)
            } else {
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            }
            if (uri != null) {
                previewRingtone = RingtoneManager.getRingtone(context, uri)?.also {
                    it.audioAttributes = alarmAudioAttributes()
                    it.play()
                }
                Handler(Looper.getMainLooper()).postDelayed({ stopPreview() }, 3_000)
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
