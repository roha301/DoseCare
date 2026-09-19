class PrescriptionModel {
  final int? id;
  final int medicineId;
  final String doctorName;
  final String clinicHospital;
  final String dateIssued;
  final String? prescriptionImagePath;
  final String? rawOcrText;

  PrescriptionModel({
    this.id,
    required this.medicineId,
    this.doctorName = 'Dr. Sarah Jenkins, MD',
    this.clinicHospital = 'Metro Cardiology Clinic',
    required this.dateIssued,
    this.prescriptionImagePath,
    this.rawOcrText,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'medicine_id': medicineId,
      'doctor_name': doctorName,
      'clinic_hospital': clinicHospital,
      'date_issued': dateIssued,
      'prescription_image_path': prescriptionImagePath,
      'raw_ocr_text': rawOcrText,
    };
  }

  factory PrescriptionModel.fromMap(Map<String, dynamic> map) {
    return PrescriptionModel(
      id: map['id'] as int?,
      medicineId: map['medicine_id'] as int,
      doctorName: map['doctor_name'] as String? ?? 'Dr. Sarah Jenkins, MD',
      clinicHospital: map['clinic_hospital'] as String? ?? 'Metro Cardiology Clinic',
      dateIssued: map['date_issued'] as String? ?? DateTime.now().toIso8601String(),
      prescriptionImagePath: map['prescription_image_path'] as String?,
      rawOcrText: map['raw_ocr_text'] as String?,
    );
  }
}
