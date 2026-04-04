import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle_model.dart';
import 'offline_vehicle_service.dart';

class VehicleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OfflineVehicleService _offlineService = OfflineVehicleService();

  // Add a new vehicle
  Future<String> addVehicle({
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
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        // If this is the first vehicle or marked as default, unset other defaults
        if (isDefault) {
          await _unsetOtherDefaults(userId);
        }

        final vehicleData = {
          'userId': userId,
          'brand': brand,
          'model': model,
          'trim': trim,
          'batteryCapacity': batteryCapacity,
          'licensePlate': licensePlate,
          'color': color,
          'year': year,
          'vin': vin,
          'isDefault': isDefault,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        final docRef = await _firestore.collection('vehicles').add(vehicleData);
        print('Vehicle added successfully with ID: ${docRef.id}');
        return docRef.id;
      } catch (e) {
        retryCount++;
        print('Error adding vehicle (attempt $retryCount): $e');
        
        if (retryCount < maxRetries) {
          print('Retrying vehicle creation in 2 seconds...');
          await Future.delayed(const Duration(seconds: 2));
        } else {
          print('Max retries reached for vehicle creation');
          print('Falling back to offline mode...');
          
          // Fallback to offline mode
          try {
            final vehicleId = await _offlineService.saveVehicleOffline(
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
            );
            print('Vehicle saved offline with ID: $vehicleId');
            return vehicleId;
          } catch (offlineError) {
            throw Exception('Failed to add vehicle online and offline: $e, Offline: $offlineError');
          }
        }
      }
    }
    
    throw Exception('Unexpected error in addVehicle');
  }

  // Get all vehicles for a user
  Future<List<VehicleModel>> getUserVehicles(String userId) async {
    try {
      // Remove orderBy to avoid index requirement, sort in memory instead
      final querySnapshot = await _firestore
          .collection('vehicles')
          .where('userId', isEqualTo: userId)
          .get();

      final vehicles = querySnapshot.docs.map((doc) {
        return VehicleModel.fromFirestore(doc.data(), doc.id);
      }).toList();
      
      // Sort by createdAt descending in memory
      vehicles.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });
      
      return vehicles;
    } catch (e) {
      print('Error getting user vehicles from Firebase: $e');
      print('Falling back to offline mode...');
      
      // Fallback to offline mode
      try {
        return await _offlineService.getVehiclesOffline(userId);
      } catch (offlineError) {
        print('Error getting vehicles offline: $offlineError');
        return [];
      }
    }
  }

  // Get stream of vehicles for a user
  Stream<List<VehicleModel>> getUserVehiclesStream(String userId) {
    return _firestore
        .collection('vehicles')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final vehicles = snapshot.docs.map((doc) {
        return VehicleModel.fromFirestore(doc.data(), doc.id);
      }).toList();
      
      // Sort by createdAt descending in memory
      vehicles.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });
      
      return vehicles;
    });
  }

  // Get a specific vehicle by ID
  Future<VehicleModel?> getVehicle(String vehicleId) async {
    try {
      final doc = await _firestore.collection('vehicles').doc(vehicleId).get();
      if (doc.exists) {
        return VehicleModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting vehicle: $e');
      return null;
    }
  }

  // Update a vehicle
  Future<void> updateVehicle({
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
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (brand != null) updateData['brand'] = brand;
      if (model != null) updateData['model'] = model;
      if (trim != null) updateData['trim'] = trim;
      if (batteryCapacity != null) {
        updateData['batteryCapacity'] = batteryCapacity;
      }
      if (licensePlate != null) updateData['licensePlate'] = licensePlate;
      if (color != null) updateData['color'] = color;
      if (year != null) updateData['year'] = year;
      if (vin != null) updateData['vin'] = vin;
      if (isDefault != null) updateData['isDefault'] = isDefault;

      // If setting as default, unset other defaults
      if (isDefault == true) {
        final vehicle = await getVehicle(vehicleId);
        if (vehicle != null) {
          await _unsetOtherDefaults(vehicle.userId);
        }
      }

      await _firestore.collection('vehicles').doc(vehicleId).update(updateData);
      print('Vehicle updated successfully');
    } catch (e) {
      print('Error updating vehicle: $e');
      throw Exception('Failed to update vehicle: $e');
    }
  }

  // Delete a vehicle
  Future<void> deleteVehicle(String vehicleId) async {
    try {
      await _firestore.collection('vehicles').doc(vehicleId).delete();
      print('Vehicle deleted successfully');
    } catch (e) {
      print('Error deleting vehicle: $e');
      throw Exception('Failed to delete vehicle: $e');
    }
  }

  // Set a vehicle as default
  Future<void> setDefaultVehicle(String vehicleId) async {
    try {
      final vehicle = await getVehicle(vehicleId);
      if (vehicle != null) {
        await _unsetOtherDefaults(vehicle.userId);
        await _firestore.collection('vehicles').doc(vehicleId).update({
          'isDefault': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('Vehicle set as default successfully');
      }
    } catch (e) {
      print('Error setting default vehicle: $e');
      throw Exception('Failed to set default vehicle: $e');
    }
  }

  // Get default vehicle for a user
  Future<VehicleModel?> getDefaultVehicle(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('vehicles')
          .where('userId', isEqualTo: userId)
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return VehicleModel.fromFirestore(
          querySnapshot.docs.first.data(),
          querySnapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      print('Error getting default vehicle: $e');
      return null;
    }
  }

  // Helper method to unset other default vehicles
  Future<void> _unsetOtherDefaults(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('vehicles')
          .where('userId', isEqualTo: userId)
          .where('isDefault', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'isDefault': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      print('Error unsetting other defaults: $e');
    }
  }

  // Get vehicle brands (for dropdown)
  Future<List<String>> getVehicleBrands() async {
    // This could be fetched from Firestore or hardcoded
    return [
      'Tesla',
      'Nissan',
      'Chevrolet',
      'Ford',
      'BMW',
      'Audi',
      'Mercedes-Benz',
      'Volkswagen',
      'Hyundai',
      'Kia',
      'Porsche',
      'Jaguar',
      'Volvo',
      'Polestar',
      'Rivian',
      'Lucid',
      'Other',
    ];
  }

  // Get vehicle models for a brand
  Future<Map<String, List<String>>> getVehicleModels() async {
    // This could be fetched from Firestore or hardcoded
    return {
      'Tesla': ['Model S', 'Model 3', 'Model X', 'Model Y', 'Cybertruck'],
      'Nissan': ['Leaf', 'Ariya'],
      'Chevrolet': ['Bolt EV', 'Bolt EUV'],
      'Ford': ['Mustang Mach-E', 'F-150 Lightning', 'E-Transit'],
      'BMW': ['i3', 'i4', 'iX', 'i7'],
      'Audi': ['e-tron', 'e-tron GT', 'Q4 e-tron'],
      'Mercedes-Benz': ['EQS', 'EQE', 'EQB', 'EQA'],
      'Volkswagen': ['ID.4', 'ID.3', 'ID.5'],
      'Hyundai': ['Kona Electric', 'Ioniq 5', 'Ioniq 6'],
      'Kia': ['Niro EV', 'EV6', 'Soul EV'],
      'Porsche': ['Taycan'],
      'Jaguar': ['I-Pace'],
      'Volvo': ['XC40 Recharge', 'C40 Recharge'],
      'Polestar': ['Polestar 2'],
      'Rivian': ['R1T', 'R1S'],
      'Lucid': ['Air', 'Gravity'],
      'Other': ['Other'],
    };
  }
}
