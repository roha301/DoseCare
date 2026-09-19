class DoseHistoryModel {
  final int? id;
  final int medicineId;
  final int? scheduleId;
  final String scheduledTime; // ISO timestamp
  final String? actionTime; // ISO timestamp when taken/skipped
  final String status; // 'TAKEN', 'SKIPPED', 'MISSED', 'SNOOZED'
  final String? skipReason; // e.g. 'Nausea / Sick', 'Forgot Meal', 'Physician Order'

  DoseHistoryModel({
    this.id,
    required this.medicineId,
    this.scheduleId,
    required this.scheduledTime,
    this.actionTime,
    required this.status,
    this.skipReason,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'medicine_id': medicineId,
      'schedule_id': scheduleId,
      'scheduled_time': scheduledTime,
      'action_time': actionTime,
      'status': status,
      'skip_reason': skipReason,
    };
  }

  factory DoseHistoryModel.fromMap(Map<String, dynamic> map) {
    return DoseHistoryModel(
      id: map['id'] as int?,
      medicineId: map['medicine_id'] as int,
      scheduleId: map['schedule_id'] as int?,
      scheduledTime: map['scheduled_time'] as String,
      actionTime: map['action_time'] as String?,
      status: map['status'] as String,
      skipReason: map['skip_reason'] as String?,
    );
  }
}
