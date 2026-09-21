import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/database/database_helper.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/safety/drug_interactions.dart';
import '../../data/models/user_model.dart';
import '../../data/models/medicine_model.dart';
import '../../data/models/schedule_model.dart';
import '../../data/models/dose_history_model.dart';
import '../../data/models/dose_occurrence_model.dart';

class ScheduledDoseItem {
  final ScheduleModel schedule;
  final MedicineModel medicine;
  final DoseOccurrenceModel occurrence;

  ScheduledDoseItem({
    required this.schedule,
    required this.medicine,
    required this.occurrence,
  });

  DoseOccurrenceModel get todayLog => occurrence;
  bool get isTaken => occurrence.status == 'TAKEN';
  bool get isSkipped => occurrence.status == 'SKIPPED';
  bool get isSnoozed => occurrence.status == 'SNOOZED';
  bool get isPending => occurrence.status == 'PENDING';
  bool get isMissed => occurrence.status == 'MISSED' || occurrence.status == 'NOT_TAKEN';
}

class AppController extends ChangeNotifier {
  static final AppController instance = AppController._init();
  AppController._init();

  bool isLoading = true;
  String? loadError;
  UserModel? user;
  List<MedicineModel> medicines = [];
  List<ScheduledDoseItem> todayTimeline = [];
  List<DoseHistoryModel> todayLogs = [];
  List<Map<String, dynamic>> allHistoryLogs = [];
  Map<String, dynamic> adherenceStats = {
    'adherenceRate': 0,
    'dosesTaken': 0,
    'totalLogged': 0,
    'streakDays': 0,
  };

  // Refreshes the foreground view; reminders themselves are scheduled by the OS.
  Timer? _reminderTimer;
  bool _isSyncingReminders = false;
  bool _isResetting = false;

  List<Map<String, dynamic>> get doseHistory => allHistoryLogs;

  Future<void> initialize() async {
    isLoading = true;
    loadError = null;
    notifyListeners();

    try {
      NotificationService.instance.onNotificationResponse = _handleNotificationResponse;
      // Notification setup is best-effort. A device permission or alarm service
      // must never prevent the medication record from opening.
      await NotificationService.instance.init();
      await refreshData(syncReminders: false);
      _startReminderTimer();
      unawaited(syncReminderSchedule());
      unawaited(_repairPendingOccurrencesInBackground());
    } catch (error) {
      loadError = 'Your medication data could not be loaded. Please try again.';
      debugPrint('DoseCare startup error: $error');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || !payload.startsWith('occurrence:')) return;
    final occurrenceId = int.tryParse(payload.split(':').last);
    if (occurrenceId == null) return;
    unawaited(_applyNotificationAction(occurrenceId, response.actionId));
  }

  Future<void> _applyNotificationAction(int occurrenceId, String? actionId) async {
    final occurrence = await DatabaseHelper.instance.getOccurrenceWithMedicine(occurrenceId);
    if (occurrence == null) return;
    if (actionId == 'taken') {
      await DatabaseHelper.instance.recordOccurrenceAction(
        occurrenceId: occurrenceId,
        status: 'TAKEN',
        doseCount: occurrence['dose_count'] as int? ?? 1,
      );
    } else if (actionId == 'snooze') {
      final updated = await DatabaseHelper.instance.recordOccurrenceAction(
        occurrenceId: occurrenceId, status: 'SNOOZED', doseCount: 0,
      );
      if (updated) {
        await NotificationService.instance.scheduleSnoozeNotification(
          id: occurrenceId,
          medicineName: occurrence['name'] as String,
          dosage: occurrence['dosage'] as String,
        );
      }
    }
    await refreshData();
  }

  void _startReminderTimer() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(refreshData());
    });
  }

  /// Legacy occurrence repair can touch many rows on established installs.
  /// It must not keep the Today screen behind its initial loading indicator.
  Future<void> _repairPendingOccurrencesInBackground() async {
    try {
      final staleAlarmIds =
          await DatabaseHelper.instance.repairPendingOccurrenceTimes();
      for (final occurrenceId in staleAlarmIds) {
        await NotificationService.instance.cancelDoseReminder(occurrenceId);
      }
      if (staleAlarmIds.isNotEmpty) {
        await refreshData();
      }
    } catch (error) {
      debugPrint('DoseCare occurrence repair error: $error');
    }
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  Future<void> refreshData({bool syncReminders = true}) async {
    user = await DatabaseHelper.instance.getUserProfile();
    medicines = await DatabaseHelper.instance.getMedicines();
    final now = DateTime.now();
    await DatabaseHelper.instance.ensureOccurrencesForNextDays(now, days: 30);
    await DatabaseHelper.instance.markOverdueOccurrences();
    todayLogs = await DatabaseHelper.instance.getDoseHistoryForToday();
    allHistoryLogs = await DatabaseHelper.instance.getAllDoseHistoryWithMedicines();
    adherenceStats = await DatabaseHelper.instance.calculateAdherenceStats();

    // Build timeline items
    final rawSchedules = await DatabaseHelper.instance.getOccurrencesForDate(DateTime.now());
    final List<ScheduledDoseItem> items = [];

    for (final row in rawSchedules) {
      final schedule = ScheduleModel(
        id: row['schedule_row_id'] as int,
        medicineId: row['medicine_id'] as int,
        timeOfDay: row['time_of_day'] as String,
        periodLabel: row['period_label'] as String? ?? 'Custom',
        doseCount: row['dose_count'] as int? ?? 1,
        daysOfWeek: row['days_of_week'] as String? ?? '1,2,3,4,5,6,7',
        frequencyType: row['frequency_type'] as String? ?? 'daily',
        startDate: row['start_date'] as String?,
        endDate: row['end_date'] as String?,
      );
      final matchingMedicines = medicines.where((m) => m.id == row['medicine_row_id']);
      if (matchingMedicines.isEmpty) continue;
      final med = matchingMedicines.first;

      items.add(ScheduledDoseItem(
        schedule: schedule,
        medicine: med,
        occurrence: DoseOccurrenceModel.fromMap(row),
      ));
    }

    todayTimeline = items;
    notifyListeners();
    unawaited(_evaluateLowStockAlerts());
    // These calls invoke platform code and may be slow on some devices. Keep
    // the patient's schedule responsive while the OS reminders are updated.
    if (syncReminders) unawaited(syncReminderSchedule());
  }

  /// Posts one alert when a medicine first crosses its configured low-stock
  /// threshold. The state resets after it is restocked, ready for the next
  /// genuine low-supply event.
  Future<void> _evaluateLowStockAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final alertsEnabled = (prefs.getBool('notifications_enabled') ?? true) &&
        (prefs.getBool('low_stock_alerts') ?? true);
    for (final medicine in medicines) {
      if (medicine.id == null) continue;
      final key = 'low_stock_notified_${medicine.id}';
      final alreadyAlerted = prefs.getBool(key) ?? false;
      if (!medicine.isLowStock) {
        if (alreadyAlerted) await prefs.setBool(key, false);
        continue;
      }
      // Do not consume the alert while notifications are turned off. It will
      // be delivered as soon as the patient enables low-stock alerts again.
      if (!alertsEnabled) continue;
      if (alreadyAlerted) continue;
      // Mark first so refreshes cannot duplicate the same alert.
      await prefs.setBool(key, true);
      await NotificationService.instance.sendLowStockNotification(
        id: medicine.id!,
        medicineName: medicine.name,
        remaining: medicine.remainingQuantity,
        daysLeft: medicine.estimatedDaysRemaining(1),
      );
    }
  }

  /// Schedules the next 30 days with the operating system, so alarms keep
  /// working when the app itself is closed.
  Future<void> syncReminderSchedule() async {
    if (_isSyncingReminders || _isResetting) return;
    _isSyncingReminders = true;
    try {
      final pending = await DatabaseHelper.instance.getPendingOccurrencesUntil(
        DateTime.now().add(const Duration(days: 30)),
      );
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          (prefs.getBool('notifications_enabled') ?? true) &&
          (prefs.getBool('reminders_enabled') ?? true);
      final caregiverAlertsEnabled =
          prefs.getBool('caregiver_alerts_enabled') ?? false;
      final canSendCaregiverSms =
          await NotificationService.instance.hasCaregiverSmsPermission();
      final caregiverPhone = user?.caregiverPhone?.trim();
      await NotificationService.instance.scheduleDailyCaregiverReport(
        enabled: (prefs.getBool('daily_caregiver_report_enabled') ?? false) &&
            canSendCaregiverSms,
        caregiverPhone: caregiverPhone ?? '',
        patientName: user?.name,
      );
      for (final row in pending) {
        // A reset can begin while this asynchronous loop is in progress. Do
        // not register any further OS alarms after that point.
        if (_isResetting) break;
        final occurrenceId = row['id'] as int;
        if (!enabled) {
          await NotificationService.instance.cancelDoseReminder(occurrenceId);
          continue;
        }
        final scheduledAt = DateTime.tryParse(row['scheduled_at'] as String);
        if (scheduledAt != null) {
          await NotificationService.instance.scheduleDoseReminder(
            occurrenceId: occurrenceId,
            medicineName: row['name'] as String,
            dosage: row['dosage'] as String,
            scheduledAt: scheduledAt,
            caregiverPhone: caregiverAlertsEnabled &&
                    canSendCaregiverSms &&
                    caregiverPhone != null && caregiverPhone.isNotEmpty
                ? caregiverPhone
                : null,
            patientName: user?.name,
          );
        }
      }
    } catch (error) {
      debugPrint('DoseCare reminder sync error: $error');
    } finally {
      _isSyncingReminders = false;
    }
  }

  // Dose Actions
  Future<void> takeDose({
    required int medicineId,
    required int scheduleId,
    int doseCount = 1,
  }) async {
    if (scheduleId == 0) {
      // PRN/manual doses have no scheduled occurrence but remain auditable.
      await DatabaseHelper.instance.recordDoseAction(
        medicineId: medicineId, status: 'TAKEN', doseCount: doseCount,
      );
      await refreshData();
      return;
    }
    final matchingOccurrence = todayTimeline.where((item) => item.schedule.id == scheduleId && item.medicine.id == medicineId).firstOrNull;
    if (matchingOccurrence == null) return;
    final occurrence = matchingOccurrence.occurrence;
    final recorded = await DatabaseHelper.instance.recordOccurrenceAction(
      occurrenceId: occurrence.id!, status: 'TAKEN', doseCount: doseCount,
    );
    if (!recorded) return;
    await NotificationService.instance.cancelDoseReminder(occurrence.id!);

    final med = medicines.where((m) => m.id == medicineId).firstOrNull;

    // Dose taken notification (respects dose_taken_alerts toggle)
    await NotificationService.instance.sendDoseTakenNotification(
      id: medicineId,
      medicineName: med?.name ?? matchingOccurrence.medicine.name,
    );

    // Refresh data first to get updated remaining quantity
    await refreshData();

  }

  Future<void> skipDose({
    required int medicineId,
    required int scheduleId,
    required String reason,
  }) async {
    final matchingOccurrence = todayTimeline.where((item) => item.schedule.id == scheduleId && item.medicine.id == medicineId).firstOrNull;
    if (matchingOccurrence == null) return;
    final occurrence = matchingOccurrence.occurrence;
    final recorded = await DatabaseHelper.instance.recordOccurrenceAction(
      occurrenceId: occurrence.id!, status: 'SKIPPED', doseCount: 0, skipReason: reason,
    );
    if (!recorded) return;
    await NotificationService.instance.cancelDoseReminder(occurrence.id!);

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('caregiver_alerts_enabled') ?? false) {
      await DatabaseHelper.instance.createCaregiverEvent(
        medicineId: medicineId,
        occurrenceId: occurrence.id!,
        eventType: 'DOSE_SKIPPED',
      );
    }
    await refreshData();
  }

  Future<void> snoozeDose({
    required int medicineId,
    int? scheduleId,
    required String medicineName,
    required String dosage,
    int minutes = 15,
  }) async {
    if (scheduleId != null) {
      final matching = todayTimeline.where((item) => item.schedule.id == scheduleId && item.medicine.id == medicineId);
      if (matching.isNotEmpty) {
        await NotificationService.instance.cancelDoseReminder(matching.first.occurrence.id!);
        await DatabaseHelper.instance.recordOccurrenceAction(
          occurrenceId: matching.first.occurrence.id!, status: 'SNOOZED', doseCount: 0,
        );
      }
    }
    await NotificationService.instance.scheduleSnoozeNotification(
      id: medicineId,
      medicineName: medicineName,
      dosage: dosage,
      minutes: minutes,
    );
    await refreshData();
  }

  // Refill
  Future<void> refillMedicine(int medicineId, int quantity) async {
    await DatabaseHelper.instance.refillMedicine(medicineId, quantity);
    await refreshData();
  }

  Future<void> bulkReorderLowStock() async {
    final lowStockMeds = medicines.where((m) => m.isLowStock).toList();
    for (final med in lowStockMeds) {
      if (med.id != null) {
        await DatabaseHelper.instance.createRefillRequest(medicineId: med.id!, quantity: 30);
      }
    }
    await refreshData();
  }

  // Add Medicine with safety checks
  List<InteractionResult> checkSafety(String newMedicineName) {
    final currentNames = medicines.map((m) => m.name).toList();
    return DrugSafetyEngine.checkInteractions(newMedicineName, currentNames);
  }

  Future<int> addMedicineWithSchedule({
    required MedicineModel medicine,
    required String timeOfDay,
    required String periodLabel,
    String frequencyType = 'daily',
    String? daysOfWeek,
    String? startDate,
    String? endDate,
  }) async {
    final medId = await DatabaseHelper.instance.insertMedicine(medicine);
    final schedule = ScheduleModel(
      medicineId: medId,
      timeOfDay: timeOfDay,
      periodLabel: periodLabel,
      doseCount: 1,
      daysOfWeek: daysOfWeek ?? '1,2,3,4,5,6,7',
      frequencyType: frequencyType,
      startDate: startDate,
      endDate: endDate,
    );
    await DatabaseHelper.instance.insertSchedule(schedule);
    await refreshData();
    return medId;
  }

  Future<int> addMedicineWithoutSchedule(MedicineModel medicine) async {
    final medId = await DatabaseHelper.instance.insertMedicine(medicine);
    await refreshData();
    return medId;
  }

  Future<void> updateMedicine(MedicineModel medicine) async {
    await DatabaseHelper.instance.updateMedicine(medicine);
    await refreshData();
  }

  Future<void> updateUserProfile(UserModel updatedUser) async {
    await DatabaseHelper.instance.updateUserProfile(updatedUser);
    await refreshData(syncReminders: false);
    await resyncCaregiverAlerts();
  }

  /// Replaces queued caretaker messages without disturbing dose alarms. This
  /// makes contact-number and consent changes take effect immediately.
  Future<void> resyncCaregiverAlerts() async {
    final pending = await DatabaseHelper.instance.getPendingOccurrencesUntil(
      DateTime.now().add(const Duration(days: 30)),
    );
    for (final row in pending) {
      await NotificationService.instance.cancelCaregiverSms(row['id'] as int);
    }
    await syncReminderSchedule();
  }

  Future<void> clearAllData() async {
    isLoading = true;
    _isResetting = true;
    notifyListeners();
    try {
      final occurrenceIds = await DatabaseHelper.instance
          .getOccurrenceIdsForAlarmCancellation();

      // Stop a ringing alarm immediately and cancel every OS-owned reminder
      // before their occurrence records disappear from SQLite.
      await NotificationService.instance.clearAllNotifications();
      await NotificationService.instance.cancelDoseReminders(occurrenceIds);

      // Wait for a pre-existing reminder sync to finish. The reset flag makes
      // it exit without scheduling any more alarms; a second cancellation
      // closes the small race window around an in-flight platform call.
      while (_isSyncingReminders) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      await NotificationService.instance.cancelDoseReminders(occurrenceIds);

      await DatabaseHelper.instance.clearAllData();
      await (await SharedPreferences.getInstance()).clear();
      await NotificationService.instance.clearAllNotifications();
      await refreshData(syncReminders: false);
    } finally {
      _isResetting = false;
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteMedicine(int id) async {
    await DatabaseHelper.instance.deleteMedicine(id);
    await refreshData();
  }
}
