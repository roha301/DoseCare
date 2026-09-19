class DoseOccurrenceModel {
  final int? id;
  final int medicineId;
  final int scheduleId;
  final String scheduledAt;
  final String status;
  final String? actionTime;
  final String? skipReason;

  const DoseOccurrenceModel({
    this.id,
    required this.medicineId,
    required this.scheduleId,
    required this.scheduledAt,
    this.status = 'PENDING',
    this.actionTime,
    this.skipReason,
  });

  factory DoseOccurrenceModel.fromMap(Map<String, dynamic> map) => DoseOccurrenceModel(
        id: map['id'] as int?,
        medicineId: map['medicine_id'] as int,
        scheduleId: map['schedule_id'] as int,
        scheduledAt: map['scheduled_at'] as String,
        status: map['status'] as String? ?? 'PENDING',
        actionTime: map['action_time'] as String?,
        skipReason: map['skip_reason'] as String?,
      );
}
