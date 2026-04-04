class VehicleModel {
  final String vehicleId;
  final String userId;
  final String brand;
  final String model;
  final String trim;
  final String batteryCapacity;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isDefault;
  final String? licensePlate;
  final String? color;
  final int? year;
  final String? vin;

  VehicleModel({
    required this.vehicleId,
    required this.userId,
    required this.brand,
    required this.model,
    required this.trim,
    required this.batteryCapacity,
    this.createdAt,
    this.updatedAt,
    this.isDefault = false,
    this.licensePlate,
    this.color,
    this.year,
    this.vin,
  });

  // Create from Firestore document
  factory VehicleModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return VehicleModel(
      vehicleId: docId,
      userId: data['userId'] ?? '',
      brand: data['brand'] ?? '',
      model: data['model'] ?? '',
      trim: data['trim'] ?? '',
      batteryCapacity: data['batteryCapacity'] ?? '',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as dynamic).toDate() 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as dynamic).toDate() 
          : null,
      isDefault: data['isDefault'] ?? false,
      licensePlate: data['licensePlate'],
      color: data['color'],
      year: data['year'],
      vin: data['vin'],
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'brand': brand,
      'model': model,
      'trim': trim,
      'batteryCapacity': batteryCapacity,
      'isDefault': isDefault,
      'licensePlate': licensePlate,
      'color': color,
      'year': year,
      'vin': vin,
    };
  }

  // Create a copy with updated fields
  VehicleModel copyWith({
    String? vehicleId,
    String? userId,
    String? brand,
    String? model,
    String? trim,
    String? batteryCapacity,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDefault,
    String? licensePlate,
    String? color,
    int? year,
    String? vin,
  }) {
    return VehicleModel(
      vehicleId: vehicleId ?? this.vehicleId,
      userId: userId ?? this.userId,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      trim: trim ?? this.trim,
      batteryCapacity: batteryCapacity ?? this.batteryCapacity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDefault: isDefault ?? this.isDefault,
      licensePlate: licensePlate ?? this.licensePlate,
      color: color ?? this.color,
      year: year ?? this.year,
      vin: vin ?? this.vin,
    );
  }

  // Get full vehicle name
  String get fullName => '$brand $model $trim';
  
  // Get display name
  String get displayName => '$brand $model';
}
