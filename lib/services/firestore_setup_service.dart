import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreSetupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create sample charging stations
  Future<void> createSampleChargingStations() async {
    final sampleStations = [
      {
        'name': 'Downtown EV Charging Hub',
        'address': '123 Main Street, Downtown',
        'latitude': 40.7128,
        'longitude': -74.0060,
        'plugType': 'Type 2',
        'price': 0.35,
        'available': true,
        'status': 'active',
        'description': 'Fast charging station in downtown area',
        'contact': '+1-555-0123',
        'parking': true,
        'connectors': 4,
        'powerOutput': 50.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'ownerId': 'admin',
        'images': <String>[],
        'amenities': <String>['Restroom', 'Coffee Shop', 'WiFi'],
        'rating': 4.5,
        'totalReviews': 12,
      },
      {
        'name': 'Mall Parking Charging Station',
        'address': '456 Shopping Ave, Mall District',
        'latitude': 40.7589,
        'longitude': -73.9851,
        'plugType': 'CCS',
        'price': 0.40,
        'available': true,
        'status': 'active',
        'description': 'Convenient charging while shopping',
        'contact': '+1-555-0456',
        'parking': true,
        'connectors': 6,
        'powerOutput': 75.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'ownerId': 'admin',
        'images': <String>[],
        'amenities': <String>['Shopping', 'Food Court', 'Security'],
        'rating': 4.2,
        'totalReviews': 8,
      },
    ];

    try {
      for (var station in sampleStations) {
        await _firestore.collection('charging_stations').add(station);
      }
      print('Sample charging stations created successfully');
    } catch (e) {
      print('Error creating sample charging stations: $e');
    }
  }

  // Create sample vehicles for testing
  Future<void> createSampleVehicles() async {
    final sampleVehicles = [
      {
        'userId': 'test_user_123',
        'brand': 'Tesla',
        'model': 'Model 3',
        'trim': 'Long Range',
        'batteryCapacity': '75 kWh',
        'licensePlate': 'TESLA123',
        'color': 'Red',
        'year': 2023,
        'vin': '1HGBH41JXMN109186',
        'isDefault': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'userId': 'test_user_123',
        'brand': 'Nissan',
        'model': 'Leaf',
        'trim': 'SL Plus',
        'batteryCapacity': '62 kWh',
        'licensePlate': 'NISSAN456',
        'color': 'Blue',
        'year': 2022,
        'vin': '2HGBH41JXMN109187',
        'isDefault': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    ];

    try {
      for (var vehicle in sampleVehicles) {
        await _firestore.collection('vehicles').add(vehicle);
      }
      print('Sample vehicles created successfully');
    } catch (e) {
      print('Error creating sample vehicles: $e');
    }
  }

  // Initialize database with sample data
  Future<void> initializeDatabase() async {
    print('Initializing Firestore database...');
    await createSampleChargingStations();
    await createSampleVehicles();
    print('Database initialization completed!');
  }
}
