package com.dosecare.dosecare

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
private const val ringAction = "com.dosecare.dosecare.RING_DOSE"
private const val takeAction = "com.dosecare.dosecare.TAKE_DOSE_ALARM"
private const val stopAction = "com.dosecare.dosecare.STOP_DOSE_ALARM"
private const val snoozeAction = "com.dosecare.dosecare.SNOOZE_DOSE_ALARM"
private const val stopAllAction = "com.dosecare.dosecare.STOP_ALL_DOSE_ALARMS"
private const val extraId = "occurrence_id"
private const val extraMedicine = "medicine_name"
private const val extraDosage = "dosage"
private const val extraTone = "tone_name"
private const val extraCustomToneUri = "custom_tone_uri"
private const val extraCaregiverPhone = "caregiver_phone"
private const val extraPatientName = "patient_name"
private const val extraScheduledAtMillis = "scheduled_at_millis"
private const val caregiverSmsAction = "com.dosecare.dosecare.CAREGIVER_SMS"
private const val dailyReportAction = "com.dosecare.dosecare.DAILY_CAREGIVER_REPORT"
private const val dailyReportRequestCode = 2_000_000
private const val dailyReportPreferences = "dosecare_daily_report"

data class ActiveDose(
    val id: Int,
    val medicine: String,
    val dosage: String,
    val tone: String,
    val customToneUri: String?,
    val caregiverPhone: String?,
    val patientName: String?,
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
            putExtra(extraCaregiverPhone, caregiverPhone)
            putExtra(extraPatientName, patientName)
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
                putExtra(extraScheduledAtMillis, triggerAtMillis)
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
                insertCaregiverEvent(context, null, null, "DAILY_REPORT_SMS")
            } catch (_: SecurityException) {
            } catch (_: Exception) {
            }
            DoseAlarmScheduler.scheduleDailyReport(context, true, phone, patient)
        }
    }

    private fun statusLabel(status: String?): String = when (status) {
        "TAKEN" -> "Taken"
        "SKIPPED", "MISSED", "NOT_TAKEN" -> "Not Taken"
        else -> "Pending"
    }

    private fun buildReport(context: Context, patient: String): String {
        data class DoseRow(val scheduledAt: String, val medicine: String, val dosage: String, val status: String)
        val rows = mutableListOf<DoseRow>()
        var taken = 0
        try {
            val databaseFile = context.getDatabasePath("dosecare.db")
            if (databaseFile.exists()) {
                SQLiteDatabase.openDatabase(databaseFile.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                    db.rawQuery(
                        """SELECT o.scheduled_at, m.name, m.dosage, o.status
                           FROM dose_occurrences o
                           INNER JOIN medicines m ON o.medicine_id = m.id
                           WHERE date(o.scheduled_at) = date('now', 'localtime')
                           ORDER BY o.scheduled_at ASC""".trimIndent(), null,
                    ).use { cursor ->
                        while (cursor.moveToNext()) {
                            val status = cursor.getString(3)
                            if (status == "TAKEN") taken++
                            rows.add(DoseRow(cursor.getString(0), cursor.getString(1), cursor.getString(2), status))
                        }
                    }
                }
            }
        } catch (_: Exception) {
            return "DoseCare: medication data for $patient could not be read. Please check in with them."
        }
        val dateLabel = java.text.SimpleDateFormat("MMM d", java.util.Locale.US).format(java.util.Date())
        if (rows.isEmpty()) {
            return "DoseCare: Daily report for $patient ($dateLabel) — no doses were scheduled today."
        }
        val maxLines = 12
        val lines = rows.take(maxLines).joinToString("\n") { row ->
            val time = parseIsoToMillis(row.scheduledAt)?.let {
                java.text.SimpleDateFormat("h:mm a", java.util.Locale.US).format(java.util.Date(it))
            } ?: row.scheduledAt
            val dosagePart = if (row.dosage.isBlank()) "" else " (${row.dosage})"
            "$time ${row.medicine}$dosagePart — ${statusLabel(row.status)}"
        }
        val extra = if (rows.size > maxLines) "\n+ ${rows.size - maxLines} more" else ""
        return "DoseCare: Daily report for $patient ($dateLabel)\n$lines$extra\n\n$taken of ${rows.size} doses taken today."
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

private fun isoFormat(millis: Long): String {
    val sdf = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", java.util.Locale.US)
    sdf.timeZone = java.util.TimeZone.getDefault()
    return sdf.format(java.util.Date(millis))
}

/** Parses the ISO-8601 local-time strings produced by Dart's
 * `DateTime.toIso8601String()` (no timezone suffix; the app always stores
 * local wall-clock times) back into epoch millis. */
private fun parseIsoToMillis(iso: String): Long? {
    return try {
        val cleaned = iso.trim()
        if (cleaned.length < 19) return null
        val datePart = cleaned.substring(0, 19)
        var millisPart = 0
        val dotIdx = cleaned.indexOf('.')
        if (dotIdx in 0 until cleaned.length) {
            val frac = cleaned.substring(dotIdx + 1).takeWhile { it.isDigit() }
            millisPart = (frac.padEnd(3, '0').take(3)).toIntOrNull() ?: 0
        }
        val sdf = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US)
        sdf.timeZone = java.util.TimeZone.getDefault()
        val base = sdf.parse(datePart)?.time ?: return null
        base + millisPart
    } catch (_: Exception) {
        null
    }
}

/** Writes a durable record of an automatic caregiver notification so the app
 * can show an "alert history" and let the patient mark it acknowledged. */
private fun insertCaregiverEvent(context: Context, medicineId: Int?, occurrenceId: Int?, eventType: String) {
    try {
        val databaseFile = context.getDatabasePath("dosecare.db")
        if (!databaseFile.exists()) return
        SQLiteDatabase.openDatabase(databaseFile.path, null, SQLiteDatabase.OPEN_READWRITE).use { db ->
            val values = android.content.ContentValues().apply {
                if (medicineId != null) put("medicine_id", medicineId) else putNull("medicine_id")
                if (occurrenceId != null) put("occurrence_id", occurrenceId) else putNull("occurrence_id")
                put("event_type", eventType)
                put("created_at", isoFormat(System.currentTimeMillis()))
            }
            db.insert("caregiver_events", null, values)
        }
    } catch (_: Exception) {
    }
}

private fun medicineIdForOccurrence(context: Context, occurrenceId: Int): Int? {
    return try {
        val databaseFile = context.getDatabasePath("dosecare.db")
        if (!databaseFile.exists()) return null
        SQLiteDatabase.openDatabase(databaseFile.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
            db.rawQuery("SELECT medicine_id FROM dose_occurrences WHERE id = ?", arrayOf(occurrenceId.toString())).use { cursor ->
                if (cursor.moveToNext()) cursor.getInt(0) else null
            }
        }
    } catch (_: Exception) {
        null
    }
}

/** Android wipes every AlarmManager alarm on reboot (and on app update). This
 * receiver re-arms every still-pending dose alarm directly from the SQLite
 * database, without needing a running Flutter engine, mirroring
 * AppController.syncReminderSchedule()'s query window and rules. */
class DoseAlarmBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val notificationsEnabled = prefs.getBoolean("flutter.notifications_enabled", true)
        val remindersEnabled = prefs.getBoolean("flutter.reminders_enabled", true)
        if (!notificationsEnabled || !remindersEnabled) return

        val caregiverAlertsEnabled = prefs.getBoolean("flutter.caregiver_alerts_enabled", false)
        val toneName = prefs.getString("flutter.alarm_sound", null) ?: "Serene Bell"
        val customToneUri = prefs.getString("flutter.device_alarm_sound_uri", null)?.takeUnless { it.isBlank() }
        val canSendSms = ContextCompat.checkSelfPermission(
            context, android.Manifest.permission.SEND_SMS,
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED

        try {
            val databaseFile = context.getDatabasePath("dosecare.db")
            if (!databaseFile.exists()) return

            var caregiverPhone: String? = null
            var patientName: String? = null
            val nowIso = isoFormat(System.currentTimeMillis())
            val endIso = isoFormat(System.currentTimeMillis() + 30L * 24 * 60 * 60 * 1000)

            SQLiteDatabase.openDatabase(databaseFile.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                db.rawQuery("SELECT caregiver_phone, name FROM users LIMIT 1", null).use { cursor ->
                    if (cursor.moveToNext()) {
                        caregiverPhone = cursor.getString(0)
                        patientName = cursor.getString(1)
                    }
                }
                db.rawQuery(
                    """SELECT o.id, o.scheduled_at, m.name, m.dosage
                       FROM dose_occurrences o
                       INNER JOIN medicines m ON o.medicine_id = m.id
                       WHERE o.status = 'PENDING' AND m.is_active = 1
                         AND o.scheduled_at >= ? AND o.scheduled_at <= ?
                       ORDER BY o.scheduled_at ASC""".trimIndent(),
                    arrayOf(nowIso, endIso),
                ).use { cursor ->
                    while (cursor.moveToNext()) {
                        val occurrenceId = cursor.getInt(0)
                        val scheduledAt = cursor.getString(1)
                        val medicineName = cursor.getString(2)
                        val dosage = cursor.getString(3)
                        val triggerAtMillis = parseIsoToMillis(scheduledAt) ?: continue
                        val phone = if (caregiverAlertsEnabled && canSendSms && !caregiverPhone.isNullOrBlank()) {
                            caregiverPhone
                        } else null
                        DoseAlarmScheduler.schedule(
                            context, occurrenceId, medicineName, dosage, triggerAtMillis,
                            toneName, customToneUri, phone, patientName,
                        )
                    }
                }
            }
        } catch (_: Exception) {
        }
    }
}

private fun isOccurrenceInactiveOrCancelled(context: Context, occurrenceId: Int): Boolean {
    try {
        val databaseFile = context.getDatabasePath("dosecare.db")
        if (!databaseFile.exists()) return false
        SQLiteDatabase.openDatabase(databaseFile.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
            db.rawQuery(
                """SELECT o.status, m.is_active
                   FROM dose_occurrences o
                   INNER JOIN medicines m ON o.medicine_id = m.id
                   WHERE o.id = ?""".trimIndent(),
                arrayOf(occurrenceId.toString())
            ).use { cursor ->
                if (!cursor.moveToNext()) {
                    // No active occurrence row in database (medication or occurrence was deleted)
                    return true
                }
                val status = cursor.getString(0)
                val isActive = cursor.getInt(1)
                if (isActive == 0 || (status != "PENDING" && status != "SNOOZED")) {
                    return true
                }
            }
        }
    } catch (_: Exception) {
        return false
    }
    return false
}

class CaregiverSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val occurrenceId = intent.getIntExtra(extraId, 0)
        if (occurrenceId > 0 && isOccurrenceInactiveOrCancelled(context, occurrenceId)) {
            DoseAlarmScheduler.cancelCaregiverSms(context, occurrenceId)
            return
        }
        val phone = intent.getStringExtra(extraCaregiverPhone)?.trim().orEmpty()
        if (phone.isEmpty()) return
        val patient = intent.getStringExtra(extraPatientName)?.trim().takeUnless { it.isNullOrEmpty() } ?: "The patient"
        val medicine = intent.getStringExtra(extraMedicine) ?: "medication"
        val dosage = intent.getStringExtra(extraDosage).orEmpty()
        val scheduledAtMillis = intent.getLongExtra(extraScheduledAtMillis, 0L)
        val timeLabel = if (scheduledAtMillis > 0) {
            " expected at " + java.text.SimpleDateFormat("h:mm a", java.util.Locale.US).format(java.util.Date(scheduledAtMillis))
        } else ""
        val dosagePart = if (dosage.isEmpty()) "" else " ($dosage)"
        val message = "DoseCare: $patient has not recorded their $medicine$dosagePart dose$timeLabel. Status: NOT TAKEN. Please check in with them."
        try {
            SmsManager.getDefault().sendTextMessage(phone, null, message, null, null)
            val medicineId = if (occurrenceId > 0) medicineIdForOccurrence(context, occurrenceId) else null
            insertCaregiverEvent(context, medicineId, occurrenceId.takeIf { it > 0 }, "DOSE_ALERT_SMS")
        } catch (_: SecurityException) {
        } catch (_: Exception) {
        }
    }
}

class DoseAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val occurrenceId = intent.getIntExtra(extraId, 0)
        if (occurrenceId > 0 && isOccurrenceInactiveOrCancelled(context, occurrenceId)) {
            DoseAlarmScheduler.cancel(context, occurrenceId)
            return
        }
        ContextCompat.startForegroundService(context, Intent(context, DoseAlarmService::class.java).apply { putExtras(intent) })
    }
}

/** Records notification actions directly in SQLite so they work while Flutter
 * is closed. This mirrors DatabaseHelper.recordOccurrenceAction(). */
private fun recordOccurrenceActionFromAlarm(
    context: Context,
    occurrenceId: Int,
    status: String,
): Boolean {
    if (occurrenceId <= 0) return false
    try {
        val databaseFile = context.getDatabasePath("dosecare.db")
        if (!databaseFile.exists()) return false
        SQLiteDatabase.openDatabase(databaseFile.path, null, SQLiteDatabase.OPEN_READWRITE).use { db ->
            db.beginTransaction()
            try {
                var medicineId = 0
                var scheduleId = 0
                var scheduledAt = ""
                var doseCount = 1
                db.rawQuery(
                    """SELECT o.medicine_id, o.schedule_id, o.scheduled_at, s.dose_count
                       FROM dose_occurrences o
                       INNER JOIN schedules s ON s.id = o.schedule_id
                       WHERE o.id = ? AND o.status IN ('PENDING', 'SNOOZED', 'MISSED')""".trimIndent(),
                    arrayOf(occurrenceId.toString()),
                ).use { cursor ->
                    if (!cursor.moveToFirst()) return false
                    medicineId = cursor.getInt(0)
                    scheduleId = cursor.getInt(1)
                    scheduledAt = cursor.getString(2)
                    doseCount = cursor.getInt(3).coerceAtLeast(1)
                }
                val now = isoFormat(System.currentTimeMillis())
                val values = android.content.ContentValues().apply {
                    put("status", status)
                    put("action_time", now)
                }
                if (db.update("dose_occurrences", values, "id = ?", arrayOf(occurrenceId.toString())) != 1) {
                    return false
                }
                db.insert("dose_history", null, android.content.ContentValues().apply {
                    put("medicine_id", medicineId)
                    put("schedule_id", scheduleId)
                    put("scheduled_time", scheduledAt)
                    put("action_time", now)
                    put("status", status)
                })
                if (status == "TAKEN") {
                    db.execSQL(
                        "UPDATE medicines SET remaining_quantity = MAX(0, remaining_quantity - ?) WHERE id = ?",
                        arrayOf(doseCount, medicineId),
                    )
                }
                db.setTransactionSuccessful()
                return true
            } finally {
                db.endTransaction()
            }
        }
    } catch (_: Exception) {
        return false
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
            when (intent.action) {
                takeAction -> {
                    if (!recordOccurrenceActionFromAlarm(context, id, "TAKEN")) return
                    DoseAlarmScheduler.cancelCaregiverSms(context, id)
                    DoseAlarmService.dismissDose(context, id)
                }
                snoozeAction -> {
                    if (!recordOccurrenceActionFromAlarm(context, id, "SNOOZED")) return
                    DoseAlarmService.dismissDose(context, id)
                    DoseAlarmScheduler.schedule(
                        context, id,
                        intent.getStringExtra(extraMedicine) ?: "Medication",
                        intent.getStringExtra(extraDosage) ?: "",
                        System.currentTimeMillis() + 5 * 60 * 1000L,
                        intent.getStringExtra(extraTone) ?: "Serene Bell",
                        intent.getStringExtra(extraCustomToneUri),
                        intent.getStringExtra(extraCaregiverPhone),
                        intent.getStringExtra(extraPatientName),
                    )
                }
                stopAction -> DoseAlarmService.dismissDose(context, id)
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
            val caregiverPhone = intent?.getStringExtra(extraCaregiverPhone)
            val patientName = intent?.getStringExtra(extraPatientName)

            activeDoses[id] = ActiveDose(id, medicine, dosage, tone, customToneUri, caregiverPhone, patientName)

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

        val activeDose = activeDoses.values.first()
        fun action(action: String, title: String, requestCode: Int): NotificationCompat.Action {
            val intent = Intent(this, DoseAlarmActionReceiver::class.java).apply {
                this.action = action
                data = Uri.parse("dosecare://foreground-action/${activeDose.id}/$requestCode")
                putExtra(extraId, activeDose.id)
                putExtra(extraMedicine, activeDose.medicine)
                putExtra(extraDosage, activeDose.dosage)
                putExtra(extraTone, activeDose.tone)
                putExtra(extraCustomToneUri, activeDose.customToneUri)
                putExtra(extraCaregiverPhone, activeDose.caregiverPhone)
                putExtra(extraPatientName, activeDose.patientName)
            }
            val pending = PendingIntent.getBroadcast(
                this, requestCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            return NotificationCompat.Action(0, title, pending)
        }

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
            .addAction(action(takeAction, "Take", 300000 + activeDose.id))
            .addAction(action(snoozeAction, "Snooze 5 min", 400000 + activeDose.id))
            .addAction(action(stopAction, "Stop", 500000 + activeDose.id))

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
                putExtra(extraCaregiverPhone, dose.caregiverPhone)
                putExtra(extraPatientName, dose.patientName)
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
            .addAction(action(takeAction, "Take", 100000 + dose.id))
            .addAction(action(snoozeAction, "Snooze 5 min", 200000 + dose.id))
            .addAction(action(stopAction, "Stop", 300000 + dose.id))
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
