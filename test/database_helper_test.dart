import 'package:flutter_test/flutter_test.dart';
import 'package:dosecare/core/database/database_helper.dart';

void main() {
  test('getOccurrencesInRange returns only occurrences within the window', () async {
    final db = await DatabaseHelper.instance.database;

    final medicineId = await db.insert('medicines', {
      'user_id': 1,
      'name': 'RangeTestMedicine',
      'type': 'Tablet',
      'dosage': '10mg',
      'pill_color': 'White',
      'total_quantity': 30,
      'remaining_quantity': 30,
      'low_stock_threshold': 5,
      'is_active': 1,
    });
    final scheduleId = await db.insert('schedules', {
      'medicine_id': medicineId,
      'time_of_day': '08:00 AM',
      'period_label': 'Morning',
    });

    final inRange = DateTime(2026, 1, 15, 8, 0);
    final outOfRange = DateTime(2026, 1, 20, 8, 0);

    await db.insert('dose_occurrences', {
      'medicine_id': medicineId,
      'schedule_id': scheduleId,
      'scheduled_at': inRange.toIso8601String(),
      'status': 'TAKEN',
    });
    await db.insert('dose_occurrences', {
      'medicine_id': medicineId,
      'schedule_id': scheduleId,
      'scheduled_at': outOfRange.toIso8601String(),
      'status': 'PENDING',
    });

    final results = await DatabaseHelper.instance.getOccurrencesInRange(
      DateTime(2026, 1, 14),
      DateTime(2026, 1, 16),
    );

    expect(results, hasLength(1));
    expect(results.single['name'], 'RangeTestMedicine');
    expect(results.single['status'], 'TAKEN');

    await db.delete('dose_occurrences', where: 'medicine_id = ?', whereArgs: [medicineId]);
    await db.delete('schedules', where: 'medicine_id = ?', whereArgs: [medicineId]);
    await db.delete('medicines', where: 'id = ?', whereArgs: [medicineId]);
  });
}
