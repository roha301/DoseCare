class MedicineModel {
  final int? id;
  final int userId;
  final String name;
  final String brandName;
  final String type; // capsule, round, oval, liquid, inhaler, injection
  final String dosage; // e.g. 500 mg, 10 mg
  final String pillColor; // teal, yellow, amber, white, purple, blue
  final String imprintCode;
  final int totalQuantity;
  final int remainingQuantity;
  final int lowStockThreshold;
  final String foodInstruction; // With food, Before meal, After meal, Empty stomach, Anytime
  final String pharmacyName;
  final String rxNumber;
  final int refillsAvailable;
  final String notes;
  final bool isActive;

  MedicineModel({
    this.id,
    this.userId = 1,
    required this.name,
    this.brandName = '',
    this.type = 'capsule',
    required this.dosage,
    this.pillColor = 'teal',
    this.imprintCode = '',
    required this.totalQuantity,
    required this.remainingQuantity,
    this.lowStockThreshold = 5,
    this.foodInstruction = 'With food',
    this.pharmacyName = 'Walgreens Pharmacy',
    this.rxNumber = '',
    this.refillsAvailable = 1,
    this.notes = '',
    this.isActive = true,
  });

  bool get isLowStock => remainingQuantity <= lowStockThreshold;

  double get stockPercentage {
    if (totalQuantity <= 0) return 0;
    return (remainingQuantity / totalQuantity).clamp(0.0, 1.0);
  }

  String get unitLabel {
    switch (type.toLowerCase()) {
      case 'liquid':
        return 'ml';
      case 'inhaler':
        return 'puffs';
      case 'injection':
        return 'doses';
      case 'capsule':
        return 'capsules';
      default:
        return 'pills';
    }
  }

  // Estimated days remaining based on a daily frequency assumption
  int estimatedDaysRemaining(int dosesPerDay) {
    if (dosesPerDay <= 0) return remainingQuantity;
    return (remainingQuantity / dosesPerDay).floor();
  }

  MedicineModel copyWith({
    int? id,
    int? userId,
    String? name,
    String? brandName,
    String? type,
    String? dosage,
    String? pillColor,
    String? imprintCode,
    int? totalQuantity,
    int? remainingQuantity,
    int? lowStockThreshold,
    String? foodInstruction,
    String? pharmacyName,
    String? rxNumber,
    int? refillsAvailable,
    String? notes,
    bool? isActive,
  }) {
    return MedicineModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      brandName: brandName ?? this.brandName,
      type: type ?? this.type,
      dosage: dosage ?? this.dosage,
      pillColor: pillColor ?? this.pillColor,
      imprintCode: imprintCode ?? this.imprintCode,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      foodInstruction: foodInstruction ?? this.foodInstruction,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      rxNumber: rxNumber ?? this.rxNumber,
      refillsAvailable: refillsAvailable ?? this.refillsAvailable,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name,
      'brand_name': brandName,
      'type': type,
      'dosage': dosage,
      'pill_color': pillColor,
      'imprint_code': imprintCode,
      'total_quantity': totalQuantity,
      'remaining_quantity': remainingQuantity,
      'low_stock_threshold': lowStockThreshold,
      'food_instruction': foodInstruction,
      'pharmacy_name': pharmacyName,
      'rx_number': rxNumber,
      'refills_available': refillsAvailable,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory MedicineModel.fromMap(Map<String, dynamic> map) {
    return MedicineModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int? ?? 1,
      name: map['name'] as String,
      brandName: map['brand_name'] as String? ?? '',
      type: map['type'] as String? ?? 'capsule',
      dosage: map['dosage'] as String? ?? '500 mg',
      pillColor: map['pill_color'] as String? ?? 'teal',
      imprintCode: map['imprint_code'] as String? ?? '',
      totalQuantity: map['total_quantity'] as int? ?? 30,
      remainingQuantity: map['remaining_quantity'] as int? ?? 30,
      lowStockThreshold: map['low_stock_threshold'] as int? ?? 5,
      foodInstruction: map['food_instruction'] as String? ?? 'With food',
      pharmacyName: map['pharmacy_name'] as String? ?? 'Walgreens Pharmacy',
      rxNumber: map['rx_number'] as String? ?? '',
      refillsAvailable: map['refills_available'] as int? ?? 1,
      notes: map['notes'] as String? ?? '',
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }
}
