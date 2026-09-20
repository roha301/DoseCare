import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../data/models/user_model.dart';
import '../../data/models/medicine_model.dart';
import '../../data/models/schedule_model.dart';
import '../../data/models/dose_history_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('medimate.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        age INTEGER,
        gender TEXT,
        caregiver_email TEXT,
        caregiver_phone TEXT,
        app_lock_pin TEXT,
        created_at TEXT
      )
    ''');

    // 2. Medicines table
    await db.execute('''
      CREATE TABLE medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        name TEXT NOT NULL,
        brand_name TEXT,
        type TEXT NOT NULL,
        dosage TEXT NOT NULL,
        pill_color TEXT NOT NULL,
        imprint_code TEXT,
        total_quantity INTEGER NOT NULL,
        remaining_quantity INTEGER NOT NULL,
        low_stock_threshold INTEGER NOT NULL DEFAULT 5,
        food_instruction TEXT,
        notes TEXT,
        is_active INTEGER DEFAULT 1
      )
    ''');

    // 3. Schedules table
    await db.execute('''
      CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER NOT NULL,
        time_of_day TEXT NOT NULL,
        period_label TEXT NOT NULL,
        dose_count INTEGER DEFAULT 1,
        days_of_week TEXT DEFAULT '1,2,3,4,5,6,7',
        frequency_type TEXT DEFAULT 'daily'
      )
    ''');

    // 4. Dose History table
    await db.execute('''
      CREATE TABLE dose_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER NOT NULL,
        schedule_id INTEGER,
        scheduled_time TEXT NOT NULL,
        action_time TEXT,
        status TEXT NOT NULL,
        skip_reason TEXT
      )
    ''');

    await _createOccurrenceTables(db);

    // 5. Prescriptions table
    await db.execute('''
      CREATE TABLE prescriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER NOT NULL,
        doctor_name TEXT,
        clinic_hospital TEXT,
        date_issued TEXT,
        prescription_image_path TEXT,
        raw_ocr_text TEXT
      )
    ''');

    // Clean initial default user - empty, awaiting user setup
    await db.insert('users', {
      'name': '',
      'age': 0,
      'gender': '',
      'caregiver_email': '',
      'caregiver_phone': '',
      'app_lock_pin': '',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _createOccurrenceTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dose_occurrences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER NOT NULL,
        schedule_id INTEGER NOT NULL,
        scheduled_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        action_time TEXT,
        skip_reason TEXT,
        UNIQUE(schedule_id, scheduled_at)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_occurrences_day ON dose_occurrences(scheduled_at)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS refill_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'DRAFT',
        requested_at TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        channel TEXT NOT NULL DEFAULT 'manual'
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS caregiver_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER,
        occurrence_id INTEGER,
        event_type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        acknowledged_at TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createOccurrenceTables(db);
    if (oldVersion < 3) {
      // Rebuild the table so obsolete linked-dispensary/Rx fields are removed
      // from existing installations as well as new ones.
      await db.execute('''
        CREATE TABLE medicines_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER,
          name TEXT NOT NULL,
          brand_name TEXT,
          type TEXT NOT NULL,
          dosage TEXT NOT NULL,
          pill_color TEXT NOT NULL,
          imprint_code TEXT,
          total_quantity INTEGER NOT NULL,
          remaining_quantity INTEGER NOT NULL,
          low_stock_threshold INTEGER NOT NULL DEFAULT 5,
          food_instruction TEXT,
          notes TEXT,
          is_active INTEGER DEFAULT 1
        )
      ''');
      await db.execute('''
        INSERT INTO medicines_new (
          id, user_id, name, brand_name, type, dosage, pill_color,
          imprint_code, total_quantity, remaining_quantity,
          low_stock_threshold, food_instruction, notes, is_active
        )
        SELECT id, user_id, name, brand_name, type, dosage, pill_color,
          imprint_code, total_quantity, remaining_quantity,
          low_stock_threshold, food_instruction, notes, is_active
        FROM medicines
      ''');
      await db.execute('DROP TABLE medicines');
      await db.execute('ALTER TABLE medicines_new RENAME TO medicines');
    }
  }

  // ---------------- CRUD Operations ----------------

  // Medicines
  Future<List<MedicineModel>> getMedicines() async {
    final db = await instance.database;
    final maps = await db.query('medicines', where: 'is_active = 1', orderBy: 'id ASC');
    return maps.map((m) => MedicineModel.fromMap(m)).toList();
  }

  Future<int> insertMedicine(MedicineModel medicine) async {
    final db = await instance.database;
    return await db.insert('medicines', medicine.toMap());
  }

  Future<int> updateMedicine(MedicineModel medicine) async {
    final db = await instance.database;
    return await db.update(
      'medicines',
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  Future<int> deleteMedicine(int id) async {
    final db = await instance.database;
    // Soft delete
    return await db.update('medicines', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  // Schedules
  Future<List<ScheduleModel>> getSchedulesForMedicine(int medicineId) async {
    final db = await instance.database;
    final maps = await db.query('schedules', where: 'medicine_id = ?', whereArgs: [medicineId]);
    return maps.map((s) => ScheduleModel.fromMap(s)).toList();
  }

  Future<List<Map<String, dynamic>>> getAllSchedulesWithMedicines() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT s.*, m.name, m.brand_name, m.dosage, m.type, m.pill_color, m.imprint_code,
             m.remaining_quantity, m.low_stock_threshold, m.food_instruction
      FROM schedules s
      INNER JOIN medicines m ON s.medicine_id = m.id
      WHERE m.is_active = 1
      ORDER BY s.time_of_day ASC
    ''');
  }

  Future<int> insertSchedule(ScheduleModel schedule) async {
    final db = await instance.database;
    return await db.insert('schedules', schedule.toMap());
  }

  Future<int> insertPrescription({
    required int medicineId,
    String? imagePath,
    String? rawOcrText,
  }) async {
    final db = await instance.database;
    return db.insert('prescriptions', {
      'medicine_id': medicineId,
      'date_issued': DateTime.now().toIso8601String(),
      'prescription_image_path': imagePath,
      'raw_ocr_text': rawOcrText,
    });
  }

  // Dose History
  Future<List<DoseHistoryModel>> getDoseHistoryForToday() async {
    final db = await instance.database;
    final today = DateTime.now();
    final todayPrefix = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final maps = await db.query(
      'dose_history',
      where: "scheduled_time LIKE ?",
      whereArgs: ['$todayPrefix%'],
      orderBy: 'scheduled_time ASC',
    );
    return maps.map((h) => DoseHistoryModel.fromMap(h)).toList();
  }

  Future<int> recordDoseAction({
    required int medicineId,
    int? scheduleId,
    required String status, // TAKEN, SKIPPED, SNOOZED, MISSED
    String? skipReason,
    int doseCount = 1,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();

    // Insert history record
    final id = await db.insert('dose_history', {
      'medicine_id': medicineId,
      'schedule_id': scheduleId,
      'scheduled_time': now,
      'action_time': now,
      'status': status,
      'skip_reason': skipReason,
    });

    // If taken, decrement remaining pills in medicine inventory
    if (status == 'TAKEN') {
      await db.rawUpdate('''
        UPDATE medicines 
        SET remaining_quantity = MAX(0, remaining_quantity - ?)
        WHERE id = ?
      ''', [doseCount, medicineId]);
    }

    return id;
  }

  Future<void> ensureOccurrencesForDate(DateTime date) async {
    final db = await instance.database;
    final day = DateTime(date.year, date.month, date.day);
    final dayKey = day.toIso8601String().substring(0, 10);
    final schedules = await db.rawQuery('''
      SELECT s.id, s.medicine_id, s.time_of_day, s.days_of_week, s.frequency_type
      FROM schedules s INNER JOIN medicines m ON s.medicine_id = m.id
      WHERE m.is_active = 1
    ''');
    final batch = db.batch();
    for (final schedule in schedules) {
      final frequency = (schedule['frequency_type'] as String? ?? 'daily').toLowerCase();
      if (frequency == 'as_needed') continue;
      final days = (schedule['days_of_week'] as String? ?? '1,2,3,4,5,6,7')
          .split(',').map((value) => int.tryParse(value.trim())).whereType<int>().toSet();
      if (!days.contains(day.weekday)) continue;
      if (frequency == 'alternate' && day.difference(DateTime(2020, 1, 6)).inDays.isOdd) continue;
      final parsed = _parseTime(schedule['time_of_day'] as String);
      if (parsed == null) continue;
      final scheduledAt = DateTime(day.year, day.month, day.day, parsed.$1, parsed.$2).toIso8601String();
      batch.insert('dose_occurrences', {
        'medicine_id': schedule['medicine_id'],
        'schedule_id': schedule['id'],
        'scheduled_at': scheduledAt,
        'status': 'PENDING',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  /// Correct pending occurrences created by older locale-dependent time
  /// formatting. Completed history is deliberately never changed.
  Future<List<int>> repairPendingOccurrenceTimes() async {
    final db = await instance.database;
    final staleAlarmIds = <int>[];
    final rows = await db.rawQuery('''
      SELECT o.id, o.schedule_id, o.scheduled_at, s.time_of_day
      FROM dose_occurrences o
      INNER JOIN schedules s ON s.id = o.schedule_id
      WHERE o.status = 'PENDING'
    ''');
    await db.transaction((txn) async {
      for (final row in rows) {
        final scheduledAt = DateTime.tryParse(row['scheduled_at'] as String);
        final time = _parseTime(row['time_of_day'] as String);
        if (scheduledAt == null || time == null ||
            (scheduledAt.hour == time.$1 && scheduledAt.minute == time.$2)) continue;
        final corrected = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day, time.$1, time.$2).toIso8601String();
        final duplicate = await txn.query(
          'dose_occurrences', columns: ['id'],
          where: 'schedule_id = ? AND scheduled_at = ?',
          whereArgs: [row['schedule_id'], corrected], limit: 1,
        );
        if (duplicate.isNotEmpty) {
          await txn.delete('dose_occurrences', where: 'id = ?', whereArgs: [row['id']]);
          staleAlarmIds.add(row['id'] as int);
        } else {
          await txn.update('dose_occurrences', {'scheduled_at': corrected}, where: 'id = ?', whereArgs: [row['id']]);
        }
      }
    });
    return staleAlarmIds;
  }

  /// Creates dated doses in one database pass. Doing this as a single batch is
  /// important at launch: repeatedly querying schedules for every future day
  /// can make the Today screen appear to hang on slower phones.
  Future<void> ensureOccurrencesForNextDays(DateTime start, {int days = 30}) async {
    final db = await instance.database;
    final schedules = await db.rawQuery('''
      SELECT s.id, s.medicine_id, s.time_of_day, s.days_of_week, s.frequency_type
      FROM schedules s INNER JOIN medicines m ON s.medicine_id = m.id
      WHERE m.is_active = 1
    ''');
    final batch = db.batch();
    for (var offset = 0; offset <= days; offset++) {
      final day = DateTime(start.year, start.month, start.day).add(Duration(days: offset));
      for (final schedule in schedules) {
        final frequency = (schedule['frequency_type'] as String? ?? 'daily').toLowerCase();
        if (frequency == 'as_needed') continue;
        final weekdays = (schedule['days_of_week'] as String? ?? '1,2,3,4,5,6,7')
            .split(',')
            .map((value) => int.tryParse(value.trim()))
            .whereType<int>()
            .toSet();
        if (!weekdays.contains(day.weekday)) continue;
        if (frequency == 'alternate' && day.difference(DateTime(2020, 1, 6)).inDays.isOdd) continue;
        final parsed = _parseTime(schedule['time_of_day'] as String);
        if (parsed == null) continue;
        final scheduledAt = DateTime(day.year, day.month, day.day, parsed.$1, parsed.$2).toIso8601String();
        batch.insert('dose_occurrences', {
          'medicine_id': schedule['medicine_id'],
          'schedule_id': schedule['id'],
          'scheduled_at': scheduledAt,
          'status': 'PENDING',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
    await batch.commit(noResult: true);
  }

  /// A dose becomes missed only after a grace period, preserving the ability to
  /// record a late dose without silently penalising adherence.
  Future<void> markOverdueOccurrences({Duration gracePeriod = const Duration(hours: 2)}) async {
    final db = await instance.database;
    final cutoff = DateTime.now().subtract(gracePeriod).toIso8601String();
    await db.transaction((txn) async {
      final overdue = await txn.query(
        'dose_occurrences',
        where: "status = 'PENDING' AND scheduled_at < ?",
        whereArgs: [cutoff],
      );
      final now = DateTime.now().toIso8601String();
      for (final occurrence in overdue) {
        await txn.update('dose_occurrences', {'status': 'MISSED', 'action_time': now}, where: 'id = ?', whereArgs: [occurrence['id']]);
        await txn.insert('dose_history', {
          'medicine_id': occurrence['medicine_id'],
          'schedule_id': occurrence['schedule_id'],
          'scheduled_time': occurrence['scheduled_at'],
          'action_time': now,
          'status': 'MISSED',
        });
      }
    });
  }

  (int, int)? _parseTime(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?:\s*([AaPp][Mm]))?$').firstMatch(value.trim());
    if (match == null) return null;
    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || minute > 59) return null;
    final suffix = match.group(3)?.toUpperCase();
    if (suffix != null) {
      if (hour < 1 || hour > 12) return null;
      if (suffix == 'PM' && hour != 12) hour += 12;
      if (suffix == 'AM' && hour == 12) hour = 0;
    }
    return hour > 23 ? null : (hour, minute);
  }

  Future<List<Map<String, dynamic>>> getOccurrencesForDate(DateTime date) async {
    final db = await instance.database;
    final key = DateTime(date.year, date.month, date.day).toIso8601String().substring(0, 10);
    return db.rawQuery('''
      SELECT o.*, s.id AS schedule_row_id, m.id AS medicine_row_id,
             s.time_of_day, s.period_label, s.dose_count, s.days_of_week, s.frequency_type,
             m.name, m.brand_name, m.dosage, m.type, m.pill_color, m.imprint_code,
             m.remaining_quantity, m.low_stock_threshold, m.food_instruction
      FROM dose_occurrences o
      INNER JOIN schedules s ON o.schedule_id = s.id
      INNER JOIN medicines m ON o.medicine_id = m.id
      WHERE o.scheduled_at LIKE ? AND m.is_active = 1
      ORDER BY o.scheduled_at ASC
    ''', ['$key%']);
  }

  Future<List<Map<String, dynamic>>> getPendingOccurrencesUntil(DateTime end) async {
    final db = await instance.database;
    return db.rawQuery('''
      SELECT o.id, o.scheduled_at, m.name, m.dosage
      FROM dose_occurrences o
      INNER JOIN medicines m ON o.medicine_id = m.id
      WHERE o.status = 'PENDING' AND m.is_active = 1
        AND o.scheduled_at >= ? AND o.scheduled_at <= ?
      ORDER BY o.scheduled_at ASC
    ''', [DateTime.now().toIso8601String(), end.toIso8601String()]);
  }

  Future<bool> recordOccurrenceAction({
    required int occurrenceId,
    required String status,
    required int doseCount,
    String? skipReason,
  }) async {
    final db = await instance.database;
    return db.transaction((txn) async {
      final rows = await txn.query('dose_occurrences', where: 'id = ?', whereArgs: [occurrenceId], limit: 1);
      if (rows.isEmpty) return false;
      final occurrence = rows.first;
      final current = occurrence['status'] as String;
      if (current != 'PENDING' && current != 'SNOOZED') return false;
      final now = DateTime.now().toIso8601String();
      await txn.update('dose_occurrences', {
        'status': status,
        'action_time': now,
        'skip_reason': skipReason,
      }, where: 'id = ?', whereArgs: [occurrenceId]);
      await txn.insert('dose_history', {
        'medicine_id': occurrence['medicine_id'],
        'schedule_id': occurrence['schedule_id'],
        'scheduled_time': occurrence['scheduled_at'],
        'action_time': now,
        'status': status,
        'skip_reason': skipReason,
      });
      if (status == 'TAKEN') {
        await txn.rawUpdate('UPDATE medicines SET remaining_quantity = MAX(0, remaining_quantity - ?) WHERE id = ?',
            [doseCount, occurrence['medicine_id']]);
      }
      return true;
    });
  }

  Future<Map<String, dynamic>?> getOccurrenceWithMedicine(int occurrenceId) async {
    final db = await instance.database;
    final rows = await db.rawQuery('''
      SELECT o.*, s.dose_count, m.name, m.dosage
      FROM dose_occurrences o
      INNER JOIN schedules s ON s.id = o.schedule_id
      INNER JOIN medicines m ON m.id = o.medicine_id
      WHERE o.id = ?
    ''', [occurrenceId]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> refillMedicine(int medicineId, int quantityAdded) async {
    final db = await instance.database;
    await db.rawUpdate('''
      UPDATE medicines 
      SET remaining_quantity = remaining_quantity + ?
      WHERE id = ?
    ''', [quantityAdded, medicineId]);
  }

  /// Creates an auditable request; it deliberately does not change stock until
  /// the patient confirms that medication was actually received.
  Future<int> createRefillRequest({required int medicineId, required int quantity}) async {
    final db = await instance.database;
    return db.insert('refill_requests', {
      'medicine_id': medicineId,
      'quantity': quantity,
      'status': 'DRAFT',
      'channel': 'manual',
      'requested_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> createCaregiverEvent({
    required int medicineId,
    required int occurrenceId,
    required String eventType,
  }) async {
    final db = await instance.database;
    return db.insert('caregiver_events', {
      'medicine_id': medicineId,
      'occurrence_id': occurrenceId,
      'event_type': eventType,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Wipe all local app data only after the explicit confirmation in Profile.
  /// IDs are needed before a wipe so the platform alarm manager can cancel
  /// reminders which are stored outside SQLite.
  Future<List<int>> getOccurrenceIdsForAlarmCancellation() async {
    final db = await instance.database;
    final rows = await db.query('dose_occurrences', columns: ['id']);
    final activeIds = rows
        .map((row) => row['id'])
        .whereType<int>()
        .toList(growable: false);

    // Deleting SQLite rows does not reset AUTOINCREMENT. Include every ID up
    // to the sequence value so a reminder left behind by an older reset can
    // still be cancelled, even though its row no longer exists.
    final sequence = await db.rawQuery(
      "SELECT seq FROM sqlite_sequence WHERE name = 'dose_occurrences'",
    );
    final lastId = sequence.isEmpty ? 0 : (sequence.first['seq'] as int? ?? 0);
    if (lastId <= 0) return activeIds;
    return List<int>.generate(lastId, (index) => index + 1, growable: false);
  }

  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Keep this list complete: stale occurrences after a reset can otherwise
      // be mistaken for missing or deleted history on a later restart.
      await txn.delete('caregiver_events');
      await txn.delete('refill_requests');
      await txn.delete('dose_history');
      await txn.delete('dose_occurrences');
      await txn.delete('prescriptions');
      await txn.delete('schedules');
      await txn.delete('medicines');
      await txn.delete('users');
      await txn.insert('users', {
        'name': '',
        'age': 0,
        'gender': '',
        'caregiver_email': '',
        'caregiver_phone': '',
        'app_lock_pin': '',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  // Get full dose history with joined medicine info
  /// Returns a substantial local history window so older records do not appear
  /// to vanish simply because the app was reopened after a busy period.
  Future<List<Map<String, dynamic>>> getAllDoseHistoryWithMedicines({int limit = 500}) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT h.*, m.name as medicine_name, m.dosage, m.type as medicine_type, m.pill_color
      FROM dose_history h
      LEFT JOIN medicines m ON h.medicine_id = m.id
      ORDER BY h.scheduled_time DESC
      LIMIT ?
    ''', [limit]);
  }

  // Adherence Calculations
  Future<Map<String, dynamic>> calculateAdherenceStats() async {
    final db = await instance.database;
    final totalTaken = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM dose_occurrences WHERE status = 'TAKEN'",
    )) ?? 0;

    final totalLogged = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM dose_occurrences WHERE status IN ('TAKEN', 'SKIPPED', 'MISSED')",
    )) ?? 0;

    final adherenceRate = totalLogged > 0 ? ((totalTaken / totalLogged) * 100).round() : 0;
    final streakDays = await _calculateStreak(db);

    return {
      'adherenceRate': adherenceRate,
      'dosesTaken': totalTaken,
      'totalLogged': totalLogged,
      'streakDays': streakDays,
    };
  }

  Future<int> _calculateStreak(Database db) async {
    final now = DateTime.now();
    int streak = 0;
    for (int i = 0; i < 365; i++) {
      final d = now.subtract(Duration(days: i));
      final datePrefix = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final count = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM dose_occurrences WHERE status = 'TAKEN' AND scheduled_at LIKE ?",
        ['$datePrefix%'],
      )) ?? 0;
      if (count > 0) {
        streak++;
      } else {
        if (i == 0) continue; // Today may not have had a dose yet
        break;
      }
    }
    return streak;
  }

  // User profile
  Future<UserModel> getUserProfile() async {
    final db = await instance.database;
    final maps = await db.query('users', limit: 1);
    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return UserModel(
      name: '',
      age: 0,
      gender: '',
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  Future<void> updateUserProfile(UserModel user) async {
    final db = await instance.database;
    final count = await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id ?? 1]);
    if (count == 0) {
      await db.insert('users', user.toMap());
    }
  }
}
