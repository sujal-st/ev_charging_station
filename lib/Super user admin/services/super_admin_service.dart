import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/roles.dart';

class SuperAdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all regular users (ev_charging_user)
  Future<List<UserModel>> getAllRegularUsers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: Roles.evChargingUser)
          .get();

      return snapshot.docs
          .where((doc) => (doc.data()['isDeleted'] ?? false) == false)
          .map((doc) {
            return UserModel.fromFirestore(doc.data());
          })
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch regular users: $e');
    }
  }

  // Get all station admins (charging_station_user)
  Future<List<UserModel>> getAllStationAdmins() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: Roles.chargingStationUser)
          .get();

      return snapshot.docs
          .where((doc) => (doc.data()['isDeleted'] ?? false) == false)
          .map((doc) {
            return UserModel.fromFirestore(doc.data());
          })
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch station admins: $e');
    }
  }

  // Get all users (any role)
  Future<List<UserModel>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();

      return snapshot.docs.map((doc) {
        return UserModel.fromFirestore(doc.data());
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch all users: $e');
    }
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user: $e');
    }
  }

  // Update user role
  Future<void> updateUserRole(String userId, String newRole) async {
    try {
      if (!Roles.isValid(newRole)) {
        throw Exception('Invalid role: $newRole');
      }

      await _firestore.collection('users').doc(userId).update({
        'role': newRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update user role: $e');
    }
  }

  // Update user information
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      final updateData = {
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(userId).update(updateData);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // Delete user (soft delete - mark as deleted)
  Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  // Permanently delete user
  Future<void> permanentlyDeleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      throw Exception('Failed to permanently delete user: $e');
    }
  }

  // Activate/Deactivate user
  Future<void> toggleUserStatus(String userId, bool isActive) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to toggle user status: $e');
    }
  }

  // Get user statistics
  Future<Map<String, dynamic>> getUserStatistics() async {
    try {
      final allUsers = await getAllUsers();
      
      final regularUsers = allUsers.where((u) => u.role == Roles.evChargingUser).length;
      final stationAdmins = allUsers.where((u) => u.role == Roles.chargingStationUser).length;
      final superUsers = allUsers.where((u) => u.role == Roles.superUser).length;
      final activeUsers = allUsers.where((u) => (u.toFirestore()['isActive'] ?? true) == true).length;
      final inactiveUsers = allUsers.length - activeUsers;

      return {
        'totalUsers': allUsers.length,
        'regularUsers': regularUsers,
        'stationAdmins': stationAdmins,
        'superUsers': superUsers,
        'activeUsers': activeUsers,
        'inactiveUsers': inactiveUsers,
      };
    } catch (e) {
      throw Exception('Failed to get user statistics: $e');
    }
  }

  // Stream of all regular users
  Stream<List<UserModel>> getAllRegularUsersStream() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: Roles.evChargingUser)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) => (doc.data()['isDeleted'] ?? false) == false)
          .map((doc) {
            return UserModel.fromFirestore(doc.data());
          })
          .toList();
    });
  }

  // Stream of all station admins
  Stream<List<UserModel>> getAllStationAdminsStream() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: Roles.chargingStationUser)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) => (doc.data()['isDeleted'] ?? false) == false)
          .map((doc) {
            return UserModel.fromFirestore(doc.data());
          })
          .toList();
    });
  }

  // Get stations owned by a user
  Future<int> getStationsCountByUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('charging_stations')
          .where('ownerId', isEqualTo: userId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      throw Exception('Failed to get stations count: $e');
    }
  }

  // Get all stations owned by a user
  Future<List<Map<String, dynamic>>> getStationsByUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('charging_stations')
          .where('ownerId', isEqualTo: userId)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final connectors = data['connectors'];
        final int connectorsCount = connectors is List ? connectors.length : (connectors is int ? connectors : 0);
        return {
          'id': data['id'] ?? doc.id,
          'firestoreId': doc.id,
          'name': data['name'] ?? '',
          'address': data['address'] ?? '',
          'latitude': data['latitude'] ?? data['lat'] ?? 0.0,
          'longitude': data['longitude'] ?? data['lng'] ?? 0.0,
          'plugType': data['plugType'] ?? data['plug_type'] ?? '',
          'price': data['price'] ?? 0.0,
          'available': data['available'] ?? true,
          'status': data['status'] ?? 'active',
          'description': data['description'] ?? '',
          'contact': data['contact'] ?? '',
          'parking': data['parking'] ?? false,
          'connectors': connectors,
          'connectorsCount': connectorsCount,
          'powerOutput': data['powerOutput'] ?? data['power_output'] ?? 0.0,
          'ownerId': data['ownerId'] ?? '',
          'images': data['images'] ?? [],
          'amenities': data['amenities'] ?? [],
          'rating': data['rating'] ?? 0.0,
          'totalReviews': data['totalReviews'] ?? data['total_reviews'] ?? 0,
          'createdAt': data['createdAt'],
          'updatedAt': data['updatedAt'],
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get stations: $e');
    }
  }

  // Get bookings count by user
  Future<int> getBookingsCountByUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      throw Exception('Failed to get bookings count: $e');
    }
  }

  // Get all bookings for a user
  Future<List<Map<String, dynamic>>> getBookingsByUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get bookings: $e');
    }
  }

  // Stream of all users
  Stream<List<UserModel>> getAllUsersStream() {
    return _firestore
        .collection('users')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) => (doc.data()['isDeleted'] ?? false) == false)
          .map((doc) {
            return UserModel.fromFirestore(doc.data());
          })
          .toList();
    });
  }

  // Get pending stations (awaiting approval)
  Future<List<Map<String, dynamic>>> getPendingStations() async {
    try {
      final snapshot = await _firestore
          .collection('charging_stations')
          .where('verificationStatus', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final connectors = data['connectors'];
        final int connectorsCount = connectors is List ? connectors.length : (connectors is int ? connectors : 0);
        return {
          'id': data['id'] ?? doc.id,
          'firestoreId': doc.id,
          'name': data['name'] ?? '',
          'address': data['address'] ?? '',
          'latitude': data['latitude'] ?? data['lat'] ?? 0.0,
          'longitude': data['longitude'] ?? data['lng'] ?? 0.0,
          'plugType': data['plugType'] ?? data['plug_type'] ?? '',
          'price': data['price'] ?? 0.0,
          'available': data['available'] ?? true,
          'status': data['status'] ?? 'active',
          'description': data['description'] ?? '',
          'contact': data['contact'] ?? '',
          'parking': data['parking'] ?? {},
          'connectors': connectors,
          'connectorsCount': connectorsCount,
          'ownerId': data['ownerId'] ?? '',
          'businessRegistrationNumber': data['businessRegistrationNumber'] ?? '',
          'stationPhotoUrl': data['stationPhotoUrl'] ?? '',
          'verificationStatus': data['verificationStatus'] ?? 'pending',
          'createdAt': data['createdAt'],
          'updatedAt': data['updatedAt'],
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get pending stations: $e');
    }
  }

  // Stream of pending stations
  // Uses query without orderBy to avoid index requirement, sorts in memory
  Stream<List<Map<String, dynamic>>> getPendingStationsStream() {
    return _firestore
        .collection('charging_stations')
        .where('verificationStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final stations = snapshot.docs.map((doc) {
        final data = doc.data();
        final connectors = data['connectors'];
        final int connectorsCount = connectors is List ? connectors.length : (connectors is int ? connectors : 0);
        return {
          'id': data['id'] ?? doc.id,
          'firestoreId': doc.id,
          'name': data['name'] ?? '',
          'address': data['address'] ?? '',
          'latitude': data['latitude'] ?? data['lat'] ?? 0.0,
          'longitude': data['longitude'] ?? data['lng'] ?? 0.0,
          'plugType': data['plugType'] ?? data['plug_type'] ?? '',
          'price': data['price'] ?? 0.0,
          'available': data['available'] ?? true,
          'status': data['status'] ?? 'active',
          'description': data['description'] ?? '',
          'contact': data['contact'] ?? '',
          'parking': data['parking'] ?? {},
          'connectors': connectors,
          'connectorsCount': connectorsCount,
          'ownerId': data['ownerId'] ?? '',
          'businessRegistrationNumber': data['businessRegistrationNumber'] ?? '',
          'stationPhotoUrl': data['stationPhotoUrl'] ?? '',
          'verificationStatus': data['verificationStatus'] ?? 'pending',
          'createdAt': data['createdAt'],
          'updatedAt': data['updatedAt'],
        };
      }).toList();
      
      // Sort in memory by createdAt descending
      stations.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      
      return stations;
    });
  }

  // Approve a station
  Future<void> approveStation(String stationId) async {
    try {
      await _firestore.collection('charging_stations').doc(stationId).update({
        'verificationStatus': 'approved',
        'verifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to approve station: $e');
    }
  }

  // Reject a station
  Future<void> rejectStation(String stationId, {String? rejectionReason}) async {
    try {
      final updateData = {
        'verificationStatus': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (rejectionReason != null && rejectionReason.isNotEmpty) {
        updateData['rejectionReason'] = rejectionReason;
      }
      
      await _firestore.collection('charging_stations').doc(stationId).update(updateData);
    } catch (e) {
      throw Exception('Failed to reject station: $e');
    }
  }
}

