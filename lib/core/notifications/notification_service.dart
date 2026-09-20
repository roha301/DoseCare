import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  void Function(NotificationResponse response)? onNotificationResponse;
  static const MethodChannel _alarmChannel = MethodChannel('medimate/dose_alarm');

  NotificationService._init();

  // Channel IDs
  static const String _reminderChannelId = 'dosecare_reminders';
  static const String _doseTakenChannelId = 'dosecare_dose_taken';
  static const String _lowStockChannelId = 'dosecare_low_stock';

  Future<void> init() async {
    try {
      tz.initializeTimeZones();
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('DoseCare notification tapped: ${response.payload}');
          onNotificationResponse?.call(response);
        },
      );

      // Create all 3 Android Notification Channels
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        // 1. Medication Reminders (highest priority)
        await androidImpl.createNotificationChannel(const AndroidNotificationChannel(
          _reminderChannelId,
          'Medication Reminders',
          description: 'Time to take your scheduled medication',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ));
        // 2. Dose Taken Confirmations
        await androidImpl.createNotificationChannel(const AndroidNotificationChannel(
          _doseTakenChannelId,
          'Dose Taken Alerts',
          description: 'Confirmation when a dose is recorded as taken',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ));
        // 3. Low Stock / Refill Alerts
        await androidImpl.createNotificationChannel(const AndroidNotificationChannel(
          _lowStockChannelId,
          'Low Stock Alerts',
          description: 'Notify when medication supply is running low',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ));
        await androidImpl.requestNotificationsPermission();
        await androidImpl.requestExactAlarmsPermission();
      }
    } catch (e) {
      debugPrint('Notification init exception: $e');
    }
  }

  /// Schedules a durable, OS-owned reminder for a dated dose occurrence.
  Future<void> scheduleDoseReminder({
    required int occurrenceId,
    required String medicineName,
    required String dosage,
    required DateTime scheduledAt,
    String? caregiverPhone,
    String? patientName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_enabled') ?? true) || !(prefs.getBool('reminders_enabled') ?? true) || !scheduledAt.isAfter(DateTime.now())) return;
    try {
      // Android's normal notification audio is one-shot. Use a native exact
      // alarm service there so the selected tone keeps playing until stopped.
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _alarmChannel.invokeMethod<void>('schedule', {
          'occurrenceId': occurrenceId,
          'medicineName': medicineName,
          'dosage': dosage,
          'triggerAtMillis': scheduledAt.millisecondsSinceEpoch,
          'toneName': prefs.getString('alarm_sound') ?? 'Serene Bell',
          'customToneUri': prefs.getString('device_alarm_sound_uri'),
          'caregiverPhone': caregiverPhone,
          'patientName': patientName,
        });
        return;
      }
      await _notificationsPlugin.zonedSchedule(
        id: 500000 + occurrenceId,
        title: 'Time for $medicineName',
        body: 'Take $dosage now.',
        scheduledDate: tz.TZDateTime.from(scheduledAt.toUtc(), tz.UTC),
        notificationDetails: NotificationDetails(android: AndroidNotificationDetails(
          _reminderChannelId, 'Medication Reminders',
          channelDescription: 'Time to take your scheduled medication',
          importance: Importance.max,
          priority: Priority.high,
          actions: const [
            AndroidNotificationAction('taken', 'Taken'),
            AndroidNotificationAction('snooze', 'Snooze 15 min'),
          ],
        )),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'occurrence:$occurrenceId',
      );
    } catch (e) {
      debugPrint('Unable to schedule medication reminder: $e');
    }
  }

  Future<bool> requestPermission() async {
    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        await androidImpl.requestExactAlarmsPermission();
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Automatic SMS requires Android's SEND_SMS permission. iOS does not allow
  /// an app to send an SMS in the background.
  Future<bool> requestCaregiverSmsPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _alarmChannel.invokeMethod<bool>('requestSmsPermission') ?? false;
    } catch (e) {
      debugPrint('Unable to request SMS permission: $e');
      return false;
    }
  }

  Future<bool> hasCaregiverSmsPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _alarmChannel.invokeMethod<bool>('isSmsPermissionGranted') ?? false;
    } catch (e) {
      debugPrint('Unable to check SMS permission: $e');
      return false;
    }
  }

  Future<void> cancelDoseReminder(int occurrenceId) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _alarmChannel.invokeMethod<void>('cancel', {'occurrenceId': occurrenceId});
      }
      await _notificationsPlugin.cancel(id: 500000 + occurrenceId);
    } catch (e) {
      debugPrint('Unable to cancel medication reminder: $e');
    }
  }

  /// Removes only the queued caretaker text, leaving the medication alarm in
  /// place. This is used when the caretaker number or consent changes.
  Future<void> cancelCaregiverSms(int occurrenceId) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _alarmChannel.invokeMethod<void>(
        'cancelCaregiverSms',
        {'occurrenceId': occurrenceId},
      );
    } catch (e) {
      debugPrint('Unable to cancel caregiver SMS: $e');
    }
  }

  /// Removes every user-visible notification and stops an alarm that is
  /// currently playing. Dated reminders are cancelled individually by the
  /// controller because Android exact alarms are keyed by occurrence ID.
  Future<void> clearAllNotifications() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _alarmChannel.invokeMethod<void>('cancelAll');
      }
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Unable to clear notifications: $e');
    }
  }

  Future<String?> pickDeviceAlarmSound(String? existingUri) async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _alarmChannel.invokeMethod<String>(
        'pickDeviceAlarmSound',
        {'existingUri': existingUri},
      );
    } catch (e) {
      debugPrint('Unable to choose device alarm sound: $e');
      return null;
    }
  }

  /// Plays the currently selected app or device alarm sound briefly.
  Future<void> previewAlarmSound(String toneName, {String? customToneUri}) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _alarmChannel.invokeMethod<void>('preview', {
        'toneName': toneName,
        'customToneUri': customToneUri,
      });
    } catch (e) {
      debugPrint('Unable to preview alarm sound: $e');
    }
  }

  Future<void> testAlarm(String toneName, {String? customToneUri}) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _alarmChannel.invokeMethod<void>('testAlarm', {
        'toneName': toneName,
        'customToneUri': customToneUri,
      });
    } catch (e) {
      debugPrint('Unable to start test alarm: $e');
    }
  }

  // Generic instant notification
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String channelId = _reminderChannelId,
    String? payload,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == _reminderChannelId
            ? 'Medication Reminders'
            : channelId == _doseTakenChannelId
                ? 'Dose Taken Alerts'
                : 'Low Stock Alerts',
        channelDescription: 'DoseCare medication management alert',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'DoseCare',
        enableVibration: true,
        playSound: true,
        fullScreenIntent: channelId == _reminderChannelId,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: androidDetails),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  /// Send a REMINDER notification (time to take medicine)
  Future<void> sendReminderNotification({
    required int id,
    required String medicineName,
    required String dosage,
    required String scheduledTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final remindersEnabled = prefs.getBool('reminders_enabled') ?? true;
    final masterEnabled = prefs.getBool('notifications_enabled') ?? true;
    if (!masterEnabled || !remindersEnabled) return;

    await showInstantNotification(
      id: id,
      title: '⏰ Time for $medicineName',
      body: 'Take $dosage at $scheduledTime. Stay consistent with your routine!',
      channelId: _reminderChannelId,
      payload: 'reminder:$id',
    );
  }

  /// Send a DOSE TAKEN confirmation notification
  Future<void> sendDoseTakenNotification({
    required int id,
    required String medicineName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final doseTakenEnabled = prefs.getBool('dose_taken_alerts') ?? true;
    final masterEnabled = prefs.getBool('notifications_enabled') ?? true;
    if (!masterEnabled || !doseTakenEnabled) return;

    await showInstantNotification(
      id: id + 10000,
      title: '✅ Dose Recorded',
      body: 'Great job! $medicineName dose marked as taken. Keep it up!',
      channelId: _doseTakenChannelId,
      payload: 'taken:$id',
    );
  }

  /// Send a LOW STOCK alert notification
  Future<void> sendLowStockNotification({
    required int id,
    required String medicineName,
    required int remaining,
    required int daysLeft,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lowStockEnabled = prefs.getBool('low_stock_alerts') ?? true;
    final masterEnabled = prefs.getBool('notifications_enabled') ?? true;
    if (!masterEnabled || !lowStockEnabled) return;

    await showInstantNotification(
      id: id + 20000,
      title: '⚠️ Low Stock: $medicineName',
      body: 'Only $remaining doses left (~$daysLeft days). Time to request a refill!',
      channelId: _lowStockChannelId,
      payload: 'lowstock:$id',
    );
  }

  /// Snooze notification.
  Future<void> scheduleSnoozeNotification({
    required int id,
    required String medicineName,
    required String dosage,
    int minutes = 15,
  }) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final prefs = await SharedPreferences.getInstance();
        await _alarmChannel.invokeMethod<void>('schedule', {
          'occurrenceId': id,
          'medicineName': medicineName,
          'dosage': dosage,
          'triggerAtMillis': DateTime.now().add(Duration(minutes: minutes)).millisecondsSinceEpoch,
          'toneName': prefs.getString('alarm_sound') ?? 'Serene Bell',
          'customToneUri': prefs.getString('device_alarm_sound_uri'),
        });
        return;
      }
      await _notificationsPlugin.zonedSchedule(
        id: 700000 + id,
        title: 'Snoozed: $medicineName',
        body: 'Take $dosage now.',
        scheduledDate: tz.TZDateTime.from(DateTime.now().add(Duration(minutes: minutes)).toUtc(), tz.UTC),
        notificationDetails: NotificationDetails(android: AndroidNotificationDetails(
          _reminderChannelId, 'Medication Reminders',
          channelDescription: 'Time to take your scheduled medication', importance: Importance.max, priority: Priority.high,
        )),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'snooze:$id',
      );
    } catch (e) {
      debugPrint('Unable to schedule snooze: $e');
    }
  }
}
