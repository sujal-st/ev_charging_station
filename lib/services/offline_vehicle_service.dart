import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vehicle_model.dart';

class OfflineVehicleService {
  static const String _vehiclesKey = 'offline_vehicles';

  // Save vehicle offline
  Future<String> saveVehicleOffline({
    required String userId,
    required String brand,
    required String model,
    required String trim,
    required String batteryCapacity,
    String? licensePlate,
    String? color,
    int? year,
    String? vin,
    bool isDefault = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing vehicles
      final existingVehicles = await getVehiclesOffline(userId);
      
      // Create new vehicle
      final vehicleId = DateTime.now().millisecondsSinceEpoch.toString();
      final vehicle = VehicleModel(
        vehicleId: vehicleId,
        userId: userId,
        brand: brand,
        model: model,
        trim: trim,
        batteryCapacity: batteryCapacity,
        licensePlate: licensePlate,
        color: color,
        year: year,
        vin: vin,
        isDefault: isDefault,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Add to existing vehicles
      existingVehicles.add(vehicle);
      
      // Save to local storage
      final vehiclesJson = existingVehicles.map((v) => v.toFirestore()).toList();
      await prefs.setStringList(_vehiclesKey, vehiclesJson.map((v) => jsonEncode(v)).toList());
      
      print('Vehicle saved offline with ID: $vehicleId');
      return vehicleId;
    } catch (e) {
      print('Error saving vehicle offline: $e');
      throw Exception('Failed to save vehicle offline: $e');
    }
  }

  // Get vehicles offline
  Future<List<VehicleModel>> getVehiclesOffline(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vehiclesJson = prefs.getStringList(_vehiclesKey) ?? [];
      
      final vehicles = vehiclesJson.map((json) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        return VehicleModel.fromFirestore(data, data['vehicleId'] ?? '');
      }).where((v) => v.userId == userId).toList();
      
      return vehicles;
    } catch (e) {
      print('Error getting vehicles offline: $e');
      return [];
    }
  }

  // Delete vehicle offline
  Future<void> deleteVehicleOffline(String vehicleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vehiclesJson = prefs.getStringList(_vehiclesKey) ?? [];
      
      // Filter out the vehicle to delete
      final updatedVehicles = vehiclesJson.where((json) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        return data['vehicleId'] != vehicleId;
      }).toList();
      
      await prefs.setStringList(_vehiclesKey, updatedVehicles);
      print('Vehicle deleted offline: $vehicleId');
    } catch (e) {
      print('Error deleting vehicle offline: $e');
      throw Exception('Failed to delete vehicle offline: $e');
    }
  }

  // Update vehicle offline
  Future<void> updateVehicleOffline({
    required String vehicleId,
    String? brand,
    String? model,
    String? trim,
    String? batteryCapacity,
    String? licensePlate,
    String? color,
    int? year,
    String? vin,
    bool? isDefault,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vehiclesJson = prefs.getStringList(_vehiclesKey) ?? [];
      
      final updatedVehicles = vehiclesJson.map((json) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        if (data['vehicleId'] == vehicleId) {
          // Update the vehicle
          if (brand != null) data['brand'] = brand;
          if (model != null) data['model'] = model;
          if (trim != null) data['trim'] = trim;
          if (batteryCapacity != null) data['batteryCapacity'] = batteryCapacity;
          if (licensePlate != null) data['licensePlate'] = licensePlate;
          if (color != null) data['color'] = color;
          if (year != null) data['year'] = year;
          if (vin != null) data['vin'] = vin;
          if (isDefault != null) data['isDefault'] = isDefault;
          data['updatedAt'] = DateTime.now().toIso8601String();
        }
        return jsonEncode(data);
      }).toList();
      
      await prefs.setStringList(_vehiclesKey, updatedVehicles);
      print('Vehicle updated offline: $vehicleId');
    } catch (e) {
      print('Error updating vehicle offline: $e');
      throw Exception('Failed to update vehicle offline: $e');
    }
  }
}
