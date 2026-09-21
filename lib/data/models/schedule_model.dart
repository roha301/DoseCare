class ScheduleModel {
  final int? id;
  final int medicineId;
  final String timeOfDay; // e.g., '08:00', '13:00', '18:30', '22:00'
  final String periodLabel; // 'Morning', 'Afternoon', 'Evening', 'Bedtime', 'Custom'
  final int doseCount;
  final String daysOfWeek; // '1,2,3,4,5,6,7' (Mon-Sun)
  final String frequencyType; // 'daily', 'alternate', 'as_needed', 'specific_dates'
  final String? startDate; // 'YYYY-MM-DD'
  final String? endDate; // 'YYYY-MM-DD'

  ScheduleModel({
    this.id,
    required this.medicineId,
    required this.timeOfDay,
    this.periodLabel = 'Morning',
    this.doseCount = 1,
    this.daysOfWeek = '1,2,3,4,5,6,7',
    this.frequencyType = 'daily',
    this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'medicine_id': medicineId,
      'time_of_day': timeOfDay,
      'period_label': periodLabel,
      'dose_count': doseCount,
      'days_of_week': daysOfWeek,
      'frequency_type': frequencyType,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    };
  }

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    return ScheduleModel(
      id: map['id'] as int?,
      medicineId: map['medicine_id'] as int,
      timeOfDay: map['time_of_day'] as String,
      periodLabel: map['period_label'] as String? ?? 'Morning',
      doseCount: map['dose_count'] as int? ?? 1,
      daysOfWeek: map['days_of_week'] as String? ?? '1,2,3,4,5,6,7',
      frequencyType: map['frequency_type'] as String? ?? 'daily',
      startDate: map['start_date'] as String?,
      endDate: map['end_date'] as String?,
    );
  }
}
