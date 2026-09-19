import 'package:flutter_test/flutter_test.dart';
import 'package:medimate/core/safety/drug_interactions.dart';
import 'package:medimate/data/models/dose_occurrence_model.dart';
import 'package:medimate/data/models/schedule_model.dart';

void main() {
  test('schedule preserves cadence fields', () {
    final schedule = ScheduleModel(
      id: 4,
      medicineId: 2,
      timeOfDay: '08:30 PM',
      daysOfWeek: '1,3,5',
      frequencyType: 'alternate',
    );

    final restored = ScheduleModel.fromMap(schedule.toMap());
    expect(restored.timeOfDay, '08:30 PM');
    expect(restored.daysOfWeek, '1,3,5');
    expect(restored.frequencyType, 'alternate');
  });

  test('occurrence defaults to a pending, dated dose', () {
    final occurrence = DoseOccurrenceModel.fromMap({
      'id': 9,
      'medicine_id': 2,
      'schedule_id': 4,
      'scheduled_at': '2026-09-18T20:30:00.000',
    });
    expect(occurrence.status, 'PENDING');
    expect(occurrence.scheduledAt, contains('2026-09-18'));
  });

  test('known high-risk interaction is surfaced', () {
    final results = DrugSafetyEngine.checkInteractions('Warfarin', ['Aspirin']);
    expect(results, hasLength(1));
    expect(results.single.severity, 'High');
  });
}
