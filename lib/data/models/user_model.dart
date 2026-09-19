class UserModel {
  final int? id;
  final String name;
  final int age;
  final String gender;
  final String? caregiverEmail;
  final String? caregiverPhone;
  final String? appLockPin;
  final String createdAt;

  UserModel({
    this.id,
    required this.name,
    required this.age,
    required this.gender,
    this.caregiverEmail,
    this.caregiverPhone,
    this.appLockPin,
    required this.createdAt,
  });

  UserModel copyWith({
    int? id,
    String? name,
    int? age,
    String? gender,
    String? caregiverEmail,
    String? caregiverPhone,
    String? appLockPin,
    String? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      caregiverEmail: caregiverEmail ?? this.caregiverEmail,
      caregiverPhone: caregiverPhone ?? this.caregiverPhone,
      appLockPin: appLockPin ?? this.appLockPin,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'age': age,
      'gender': gender,
      'caregiver_email': caregiverEmail,
      'caregiver_phone': caregiverPhone,
      'app_lock_pin': appLockPin,
      'created_at': createdAt,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      age: map['age'] as int? ?? 0,
      gender: map['gender'] as String? ?? '',
      caregiverEmail: map['caregiver_email'] as String?,
      caregiverPhone: map['caregiver_phone'] as String?,
      appLockPin: map['app_lock_pin'] as String?,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}
