import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/booking_model.dart';

class StationAdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isValidStatusTransition(String from, String to) {
    // Define valid status transitions
    final validTransitions = {
      'upcoming': ['in_progress', 'cancelled'],
      'in_progress': ['completed', 'cancelled'],
      'completed': [], // Terminal state
      'cancelled': [], // Terminal state
    };
    
    return validTransitions[from]?.contains(to) ?? false;
  }

  // Get all stations for a specific owner
  Future<List<Map<String, dynamic>>> getOwnerStations(String ownerId) async {
    try {
      // Remove orderBy to avoid index requirement, sort in memory instead
      final snapshot = await _firestore
          .collection('charging_stations')
          .where('ownerId', isEqualTo: ownerId)
          .get();

      if (snapshot.docs.isEmpty) {
        // Return an empty list if no stations are found for the owner.
        return [];
      }

      final stations = snapshot.docs.map((doc) {
        final data = doc.data();
        // Ensure that the data is structured as expected.
        // If critical fields are missing, this will now be more apparent.
        return {
          'id': doc.id,
          'firestoreId': doc.id,
          'name': data['name'],
          'address': data['address'],
          'available': data['available'],
          'status': data['status'],
          'createdAt': data['createdAt'],
          'updatedAt': data['updatedAt'],
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          'price': data['price'],
          'connectors': data['connectors'],
          'ownerId': data['ownerId'],
          ...data,
        };
      }).toList();

      // Sort by createdAt descending in memory
      stations.sort((a, b) {
        final aTime = a['createdAt'];
        final bTime = b['createdAt'];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        // Handle Timestamp objects
        DateTime aDate;
        DateTime bDate;
        
        if (aTime is Timestamp) {
          aDate = aTime.toDate();
        } else if (aTime is DateTime) {
          aDate = aTime;
        } else {
          return 0;
        }
        
        if (bTime is Timestamp) {
          bDate = bTime.toDate();
        } else if (bTime is DateTime) {
          bDate = bTime;
        } else {
          return 0;
        }
        
        return bDate.compareTo(aDate); // Descending order
      });

      return stations;
    } on FirebaseException catch (e) {
      // Catch specific Firebase exceptions for better error handling.
      throw Exception('Failed to fetch owner stations: ${e.message}');
    } catch (e) {
      // Catch any other exceptions.
      throw Exception('An unexpected error occurred while fetching stations: $e');
    }
  }

  // Get all bookings for a specific station
  Future<List<BookingModel>> getStationBookings(String stationId) async {
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .where('stationId', isEqualTo: stationId)
          .get();

      final bookings = snapshot.docs.map((doc) {
        return BookingModel.fromFirestore(doc.data(), doc.id);
      }).toList();
      
      // Sort by startTime descending (most recent first)
      bookings.sort((a, b) => b.startTime.compareTo(a.startTime));
      
      return bookings;
    } catch (e) {
      throw Exception('Failed to fetch station bookings: $e');
    }
  }

  // Get bookings by status for a specific station
  Future<List<BookingModel>> getStationBookingsByStatus(
    String stationId, 
    String status
  ) async {
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .where('stationId', isEqualTo: stationId)
          .where('status', isEqualTo: status)
          .get();

      final bookings = snapshot.docs.map((doc) {
        return BookingModel.fromFirestore(doc.data(), doc.id);
      }).toList();
      
      bookings.sort((a, b) => b.startTime.compareTo(a.startTime));
      
      return bookings;
    } catch (e) {
      throw Exception('Failed to fetch bookings by status: $e');
    }
  }

  // Update station status/availability
  Future<void> updateStationStatus({
    required String stationId,
    bool? available,
    String? status,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (available != null) updateData['available'] = available;
      if (status != null) updateData['status'] = status;
      
      await _firestore.collection('charging_stations').doc(stationId).update(updateData);
    } catch (e) {
      throw Exception('Failed to update station: $e');
    }
  }

  // Update booking status
  Future<void> updateBookingStatus(String bookingId, String status, {String? ownerId}) async {
    try {
      // Start a transaction to ensure data consistency
      // IMPORTANT: All reads must be done before any writes in Firestore transactions
      await _firestore.runTransaction((transaction) async {
        // ========== PHASE 1: ALL READS FIRST ==========
        final bookingRef = _firestore.collection('bookings').doc(bookingId);
        final bookingDoc = await transaction.get(bookingRef);
        
        if (!bookingDoc.exists) {
          throw Exception('Booking not found');
        }
        
        final bookingData = bookingDoc.data() as Map<String, dynamic>;
        final currentStatus = bookingData['status'] as String;
        final stationId = bookingData['stationId'] as String?;
        
        // Read station document for ownership verification (if needed)
        DocumentSnapshot? stationDocForOwnership;
        if (ownerId != null && stationId != null && stationId.isNotEmpty) {
          final stationRef = _firestore.collection('charging_stations').doc(stationId);
          stationDocForOwnership = await transaction.get(stationRef);
          
          if (stationDocForOwnership.exists) {
            // Station exists, verify ownership
            final stationData = stationDocForOwnership.data() as Map<String, dynamic>;
            final stationOwnerId = stationData['ownerId'] as String?;
            
            if (stationOwnerId != null && stationOwnerId != ownerId) {
              throw Exception('You do not have permission to update this booking');
            }
          }
          // If station doesn't exist, we'll allow the update anyway
          // (station might have been deleted, but booking should still be updatable)
        }
        
        // Read station document for availability update (if needed)
        // Reuse the same read if we already have it, otherwise read again
        DocumentSnapshot? stationDocForAvailability;
        final needsAvailabilityUpdate = (status == 'completed' || status == 'cancelled') && 
                                        stationId != null && 
                                        stationId.isNotEmpty;
        
        if (needsAvailabilityUpdate) {
          if (stationDocForOwnership != null) {
            // Reuse the station document we already read
            stationDocForAvailability = stationDocForOwnership;
          } else {
            // Read the station document for the first time
            final stationRef = _firestore.collection('charging_stations').doc(stationId);
            stationDocForAvailability = await transaction.get(stationRef);
          }
        }
        
        // Validate status transition
        if (!_isValidStatusTransition(currentStatus, status)) {
          throw Exception('Invalid status transition from $currentStatus to $status');
        }
        
        // ========== PHASE 2: ALL WRITES AFTER READS ==========
        // Update booking status
        transaction.update(bookingRef, {
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastStatus': currentStatus,
          'statusUpdatedAt': FieldValue.serverTimestamp(),
        });
        
        // If status is completed or cancelled, update station availability
        if (needsAvailabilityUpdate && stationDocForAvailability != null && stationDocForAvailability.exists) {
          final stationData = stationDocForAvailability.data() as Map<String, dynamic>;
          // Only update if the current user owns the station or ownerId is not provided
          if (ownerId == null || stationData['ownerId'] == ownerId) {
            final stationRef = _firestore.collection('charging_stations').doc(stationId);
            transaction.update(stationRef, {
              'available': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });
    } catch (e) {
      throw Exception('Failed to update booking status: $e');
    }
  }

  // Delete station
  Future<void> deleteStation(String stationId) async {
    try {
      await _firestore.collection('charging_stations').doc(stationId).delete();
    } catch (e) {
      throw Exception('Failed to delete station: $e');
    }
  }

  // Get statistics for owner's stations
  Future<Map<String, dynamic>> getOwnerStatistics(String ownerId) async {
    try {
      // Get all owner's stations
      final stations = await getOwnerStations(ownerId);
      final stationIds = stations.map((s) => s['id']).toList();

      if (stationIds.isEmpty) {
        return {
          'totalStations': 0,
          'totalBookings': 0,
          'upcomingBookings': 0,
          'inProgressBookings': 0,
          'completedBookings': 0,
        };
      }

      // Get all bookings for owner's stations
      QuerySnapshot bookingsSnapshot;
      if (stationIds.length == 1) {
        bookingsSnapshot = await _firestore
            .collection('bookings')
            .where('stationId', isEqualTo: stationIds.first)
            .get();
      } else if (stationIds.length <= 10) {
        // Firestore whereIn supports up to 10 items
        bookingsSnapshot = await _firestore
            .collection('bookings')
            .where('stationId', whereIn: stationIds)
            .get();
      } else {
        // For more than 10 stations, fetch all and filter
        bookingsSnapshot = await _firestore
            .collection('bookings')
            .get();
      }

      final allBookings = bookingsSnapshot.docs
          .map((doc) => BookingModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .where((booking) => stationIds.contains(booking.stationId))
          .toList();

      final upcomingCount = allBookings.where((b) => b.status == 'upcoming').length;
      final inProgressCount = allBookings.where((b) => b.status == 'in_progress').length;
      final completedCount = allBookings.where((b) => b.status == 'completed').length;

      return {
        'totalStations': stations.length,
        'totalBookings': allBookings.length,
        'upcomingBookings': upcomingCount,
        'inProgressBookings': inProgressCount,
        'completedBookings': completedCount,
      };
    } catch (e) {
      throw Exception('Failed to fetch statistics: $e');
    }
  }

  // Get all bookings for all stations owned by the owner
  Future<List<BookingModel>> getAllOwnerBookings(String ownerId) async {
    try {
      // First, get all the stations owned by the user
      final stations = await getOwnerStations(ownerId);
      final stationIds = stations.map((s) => s['id'] as String).toList();

      if (stationIds.isEmpty) {
        return []; // No stations, so no bookings
      }

      // Fetch bookings for the owner's stations
      // Firestore 'whereIn' query is limited to 10 items, so we may need to batch
      final List<BookingModel> allBookings = [];
      for (var i = 0; i < stationIds.length; i += 10) {
        final batchIds = stationIds.sublist(i, i + 10 > stationIds.length ? stationIds.length : i + 10);
        final snapshot = await _firestore
            .collection('bookings')
            .where('stationId', whereIn: batchIds)
            .get();
        
        final bookings = snapshot.docs.map((doc) {
          return BookingModel.fromFirestore(doc.data(), doc.id);
        }).toList();
        allBookings.addAll(bookings);
      }

      // Sort by start time descending
      allBookings.sort((a, b) => b.startTime.compareTo(a.startTime));

      return allBookings;
    } catch (e) {
      throw Exception('Failed to fetch all owner bookings: $e');
    }
  }

  // Stream of bookings for real-time updates
  Stream<List<BookingModel>> getStationBookingsStream(String stationId) {
    return _firestore
        .collection('bookings')
        .where('stationId', isEqualTo: stationId)
        .snapshots()
        .map((snapshot) {
      final bookings = snapshot.docs.map((doc) {
        return BookingModel.fromFirestore(doc.data(), doc.id);
      }).toList();
      
      bookings.sort((a, b) => b.startTime.compareTo(a.startTime));
      
      return bookings;
    });
  }

  // Stream of owner stations for real-time updates
  Stream<List<Map<String, dynamic>>> getOwnerStationsStream(String ownerId) {
    return _firestore
        .collection('charging_stations')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'firestoreId': doc.id,
          ...data,
        };
      }).toList();
    });
  }

  // Get sales statistics for owner's stations
  Future<Map<String, dynamic>> getOwnerSalesStatistics(String ownerId) async {
    try {
      // Get all owner's stations
      final stations = await getOwnerStations(ownerId);
      final stationIds = stations.map((s) => s['id']).toList();

      if (stationIds.isEmpty) {
        return {
          'totalRevenue': 0.0,
          'todayRevenue': 0.0,
          'thisWeekRevenue': 0.0,
          'thisMonthRevenue': 0.0,
          'totalTransactions': 0,
          'todayTransactions': 0,
          'thisWeekTransactions': 0,
          'thisMonthTransactions': 0,
          'averageTransactionValue': 0.0,
          'confirmedRevenue': 0.0,
          'pendingRevenue': 0.0,
        };
      }

      // Get all bookings for owner's stations
      QuerySnapshot bookingsSnapshot;
      if (stationIds.length == 1) {
        bookingsSnapshot = await _firestore
            .collection('bookings')
            .where('stationId', isEqualTo: stationIds.first)
            .get();
      } else if (stationIds.length <= 10) {
        bookingsSnapshot = await _firestore
            .collection('bookings')
            .where('stationId', whereIn: stationIds)
            .get();
      } else {
        bookingsSnapshot = await _firestore
            .collection('bookings')
            .get();
      }

      final allBookings = bookingsSnapshot.docs
          .map((doc) => BookingModel.fromFirestore(
              doc.data() as Map<String, dynamic>, doc.id))
          .where((booking) => stationIds.contains(booking.stationId))
          .toList();

      // Calculate date ranges
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      // Filter bookings by date
      final todayBookings = allBookings.where((b) {
        final bookingDate = b.createdAt;
        return bookingDate.isAfter(todayStart) || bookingDate.isAtSameMomentAs(todayStart);
      }).toList();

      final weekBookings = allBookings.where((b) {
        return b.createdAt.isAfter(weekStart) || b.createdAt.isAtSameMomentAs(weekStart);
      }).toList();

      final monthBookings = allBookings.where((b) {
        return b.createdAt.isAfter(monthStart) || b.createdAt.isAtSameMomentAs(monthStart);
      }).toList();

      // Calculate confirmed revenue (only admin_confirmed and paid payments)
      final confirmedBookings = allBookings.where((b) =>
          b.paymentStatus == 'admin_confirmed' || b.paymentStatus == 'paid').toList();
      final confirmedRevenue = confirmedBookings.fold<double>(
          0.0, (sum, b) => sum + b.amount);

      // Calculate pending revenue (paid but not confirmed)
      final pendingBookings = allBookings.where((b) =>
          b.paymentStatus == 'paid' && b.paymentStatus != 'admin_confirmed').toList();
      final pendingRevenue = pendingBookings.fold<double>(
          0.0, (sum, b) => sum + b.amount);

      // Calculate total revenue (all confirmed bookings)
      final totalRevenue = confirmedRevenue;

      // Calculate time-based revenues (only confirmed/paid)
      final todayRevenue = todayBookings
          .where((b) => b.paymentStatus == 'admin_confirmed' || b.paymentStatus == 'paid')
          .fold<double>(0.0, (sum, b) => sum + b.amount);

      final thisWeekRevenue = weekBookings
          .where((b) => b.paymentStatus == 'admin_confirmed' || b.paymentStatus == 'paid')
          .fold<double>(0.0, (sum, b) => sum + b.amount);

      final thisMonthRevenue = monthBookings
          .where((b) => b.paymentStatus == 'admin_confirmed' || b.paymentStatus == 'paid')
          .fold<double>(0.0, (sum, b) => sum + b.amount);

      // Count transactions
      final totalTransactions = confirmedBookings.length;
      final todayTransactions = todayBookings
          .where((b) => b.paymentStatus == 'admin_confirmed' || b.paymentStatus == 'paid')
          .length;
      final thisWeekTransactions = weekBookings
          .where((b) => b.paymentStatus == 'admin_confirmed' || b.paymentStatus == 'paid')
          .length;
      final thisMonthTransactions = monthBookings
          .where((b) => b.paymentStatus == 'admin_confirmed' || b.paymentStatus == 'paid')
          .length;

      // Calculate average transaction value
      final averageTransactionValue = totalTransactions > 0
          ? totalRevenue / totalTransactions
          : 0.0;

      return {
        'totalRevenue': totalRevenue,
        'todayRevenue': todayRevenue,
        'thisWeekRevenue': thisWeekRevenue,
        'thisMonthRevenue': thisMonthRevenue,
        'totalTransactions': totalTransactions,
        'todayTransactions': todayTransactions,
        'thisWeekTransactions': thisWeekTransactions,
        'thisMonthTransactions': thisMonthTransactions,
        'averageTransactionValue': averageTransactionValue,
        'confirmedRevenue': confirmedRevenue,
        'pendingRevenue': pendingRevenue,
      };
    } catch (e) {
      throw Exception('Failed to fetch sales statistics: $e');
    }
  }

  // Confirm payment (admin action)
  Future<void> confirmPayment(String bookingId, {String? ownerId}) async {
    try {
      // Start a transaction to ensure data consistency
      await _firestore.runTransaction((transaction) async {
        // ========== PHASE 1: ALL READS FIRST ==========
        final bookingRef = _firestore.collection('bookings').doc(bookingId);
        final bookingDoc = await transaction.get(bookingRef);
        
        if (!bookingDoc.exists) {
          throw Exception('Booking not found');
        }
        
        final bookingData = bookingDoc.data() as Map<String, dynamic>;
        final paymentStatus = bookingData['paymentStatus'] as String? ?? 'pending';
        final paymentMethod = bookingData['paymentMethod'] as String?;
        final stationId = bookingData['stationId'] as String?;
        
        // Verify payment is in 'paid' status (for Khalti) or 'pending' (for COD)
        final isCOD = paymentMethod == 'cod';
        if (!isCOD && paymentStatus != 'paid') {
          throw Exception('Payment must be in "paid" status to confirm');
        }
        if (isCOD && paymentStatus != 'pending') {
          throw Exception('COD payment must be in "pending" status to confirm');
        }
        
        // Verify station ownership if ownerId is provided
        if (ownerId != null && stationId != null && stationId.isNotEmpty) {
          final stationRef = _firestore.collection('charging_stations').doc(stationId);
          final stationDoc = await transaction.get(stationRef);
          
          if (stationDoc.exists) {
            final stationData = stationDoc.data() as Map<String, dynamic>;
            final stationOwnerId = stationData['ownerId'] as String?;
            
            if (stationOwnerId != null && stationOwnerId != ownerId) {
              throw Exception('You do not have permission to confirm this payment');
            }
          }
        }
        
        // ========== PHASE 2: ALL WRITES AFTER READS ==========
        // Update payment status to admin_confirmed
        // For COD, also mark as paid since payment is collected at station
        final updateData = <String, dynamic>{
          'paymentStatus': 'admin_confirmed',
          'confirmedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        // For COD, also set paidAt timestamp
        if (isCOD) {
          updateData['paidAt'] = FieldValue.serverTimestamp();
        }
        
        transaction.update(bookingRef, updateData);
      });
    } catch (e) {
      throw Exception('Failed to confirm payment: $e');
    }
  }
}

