import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get booked time slots for a connector on a specific date
  // Note: Only includes 'upcoming' and 'in_progress' bookings.
  // Completed bookings are excluded, so if a booking is completed early,
  // the remaining time slot becomes available for other users.
  Future<List<Map<String, DateTime>>> getBookedTimeSlots({
    required String stationId,
    required int connectorIndex,
    required DateTime date,
  }) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day, 0, 0);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      
      // Only query active bookings (upcoming, in_progress)
      // Completed bookings are excluded - when a booking is marked as completed,
      // the time slot becomes available immediately, even if it's before the scheduled end time
      final snapshot = await _firestore
          .collection('bookings')
          .where('stationId', isEqualTo: stationId)
          .where('status', whereIn: ['upcoming', 'in_progress'])
          .get();

      final List<Map<String, DateTime>> bookedSlots = [];

      for (var doc in snapshot.docs) {
        final bookingData = doc.data();
        final bookingConnectorIndex = bookingData['connectorIndex'];
        if (bookingConnectorIndex != connectorIndex) {
          continue; // Different connector, skip
        }

        final booking = BookingModel.fromFirestore(bookingData, doc.id);
        
        // Check if booking is on the same date
        if (booking.startTime.year == date.year &&
            booking.startTime.month == date.month &&
            booking.startTime.day == date.day) {
          bookedSlots.add({
            'start': booking.startTime,
            'end': booking.endTime,
          });
        }
      }

      return bookedSlots;
    } catch (e) {
      throw Exception('Failed to get booked time slots: $e');
    }
  }

  // Check if a connector is available for a given time slot
  // Note: Only checks 'upcoming' and 'in_progress' bookings.
  // Completed bookings are excluded - when a booking is completed early,
  // the remaining time slot becomes available for other users.
  Future<bool> isConnectorAvailable({
    required String stationId,
    required int connectorIndex,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeBookingId, // Exclude this booking when checking (for updates)
  }) async {
    try {
      // Get all bookings for this station with the same connector index
      // that overlap with the requested time slot
      // Note: We query by stationId and status first, then filter by connectorIndex in memory
      // to avoid requiring a composite index
      // Only active bookings (upcoming, in_progress) are considered.
      // Completed bookings are excluded, so completed slots become available immediately.
      final snapshot = await _firestore
          .collection('bookings')
          .where('stationId', isEqualTo: stationId)
          .where('status', whereIn: ['upcoming', 'in_progress'])
          .get();

      // Check for time overlaps
      for (var doc in snapshot.docs) {
        // Skip the excluded booking (for updates)
        if (excludeBookingId != null && doc.id == excludeBookingId) {
          continue;
        }

        final bookingData = doc.data();
        // Filter by connectorIndex (handle null for backward compatibility)
        final bookingConnectorIndex = bookingData['connectorIndex'];
        if (bookingConnectorIndex != connectorIndex) {
          continue; // Different connector, skip
        }

        final booking = BookingModel.fromFirestore(bookingData, doc.id);
        
        // Check if time slots overlap
        // Two time slots overlap if: start1 < end2 && start2 < end1
        if (booking.startTime.isBefore(endTime) && startTime.isBefore(booking.endTime)) {
          return false; // Connector is booked during this time
        }
      }

      return true; // Connector is available
    } catch (e) {
      throw Exception('Failed to check connector availability: $e');
    }
  }

  // Create a new booking with transaction to prevent double booking
  Future<String> createBooking({
    required String userId,
    required String stationId,
    required String stationName,
    required String stationAddress,
    required double stationLatitude,
    required double stationLongitude,
    required String plugType,
    required double maxPower,
    required int durationMinutes,
    required double amount,
    required DateTime startTime,
    required int connectorIndex,
    String? notes,
    String? vehicleId,
    String? vehicleModel,
  }) async {
    try {
      final endTime = startTime.add(Duration(minutes: durationMinutes));
      final bookingDate = DateTime(startTime.year, startTime.month, startTime.day);
      
      // Use transaction to ensure atomic booking creation and prevent double booking
      return await _firestore.runTransaction((transaction) async {
        // ========== PHASE 1: ALL READS FIRST ==========
        // Check if connector is available by querying existing bookings
        // Only active bookings (upcoming, in_progress) are considered.
        // Completed bookings are excluded - when a booking is completed early,
        // the remaining time slot becomes available for other users.
        final snapshot = await _firestore
            .collection('bookings')
            .where('stationId', isEqualTo: stationId)
            .where('status', whereIn: ['upcoming', 'in_progress'])
            .get();

        // Check for time overlaps with the same connector
        for (var doc in snapshot.docs) {
          final bookingData = doc.data();
          final bookingConnectorIndex = bookingData['connectorIndex'];
          if (bookingConnectorIndex != connectorIndex) {
            continue; // Different connector, skip
          }

          final booking = BookingModel.fromFirestore(bookingData, doc.id);
          
          // Check if time slots overlap
          if (booking.startTime.isBefore(endTime) && startTime.isBefore(booking.endTime)) {
            throw Exception('Connector ${connectorIndex + 1} is not available for the selected time slot. Another user has already booked it.');
          }
        }

        // ========== PHASE 2: ALL WRITES AFTER READS ==========
        // Create the booking
        final bookingData = {
          'userId': userId,
          'stationId': stationId,
          'stationName': stationName,
          'stationAddress': stationAddress,
          'stationLatitude': stationLatitude,
          'stationLongitude': stationLongitude,
          'plugType': plugType,
          'maxPower': maxPower,
          'durationMinutes': durationMinutes,
          'amount': amount,
          'status': 'upcoming',
          'paymentStatus': 'pending', // Default payment status
          'bookingDate': bookingDate,
          'startTime': startTime,
          'endTime': endTime,
          'connectorIndex': connectorIndex,
          'remindMe': true,
          'notes': notes,
          'vehicleId': vehicleId,
          'vehicleModel': vehicleModel,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        final docRef = _firestore.collection('bookings').doc();
        transaction.set(docRef, bookingData);
        
        return docRef.id;
      });
    } catch (e) {
      throw Exception('Failed to create booking: $e');
    }
  }

  // Get all bookings for a specific user
  Future<List<BookingModel>> getUserBookings(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .get();

      // Sort in memory to avoid index requirement
      final bookings = snapshot.docs.map((doc) {
        return BookingModel.fromFirestore(doc.data(), doc.id);
      }).toList();
      
      // Sort by startTime descending
      bookings.sort((a, b) => b.startTime.compareTo(a.startTime));
      
      return bookings;
    } catch (e) {
      throw Exception('Failed to fetch user bookings: $e');
    }
  }

  // Get bookings by status for a specific user
  Future<List<BookingModel>> getUserBookingsByStatus(String userId, String status) async {
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: status)
          .get();

      // Sort in memory to avoid index requirement
      final bookings = snapshot.docs.map((doc) {
        return BookingModel.fromFirestore(doc.data(), doc.id);
      }).toList();
      
      // Sort by startTime descending
      bookings.sort((a, b) => b.startTime.compareTo(a.startTime));
      
      return bookings;
    } catch (e) {
      throw Exception('Failed to fetch bookings by status: $e');
    }
  }

  // Get upcoming bookings for a specific user
  Future<List<BookingModel>> getUpcomingBookings(String userId) async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'upcoming')
          .get();

      // Filter and sort in memory to avoid complex index requirements
      final bookings = snapshot.docs.map((doc) {
        return BookingModel.fromFirestore(doc.data(), doc.id);
      }).where((booking) => booking.startTime.isAfter(now)).toList();
      
      // Sort by startTime ascending (earliest first)
      bookings.sort((a, b) => a.startTime.compareTo(b.startTime));
      
      return bookings;
    } catch (e) {
      throw Exception('Failed to fetch upcoming bookings: $e');
    }
  }

  // Get completed bookings for a specific user
  Future<List<BookingModel>> getCompletedBookings(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .get();

      // Sort in memory to avoid index requirement
      final bookings = snapshot.docs.map((doc) {
        return BookingModel.fromFirestore(doc.data(), doc.id);
      }).toList();
      
      // Sort by endTime descending (most recent first)
      bookings.sort((a, b) => b.endTime.compareTo(a.endTime));
      
      return bookings;
    } catch (e) {
      throw Exception('Failed to fetch completed bookings: $e');
    }
  }

  // Get cancelled bookings for a specific user
  Future<List<BookingModel>> getCancelledBookings(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'cancelled')
          .get();

      // Sort in memory to avoid index requirement
      final bookings = snapshot.docs.map((doc) {
        return BookingModel.fromFirestore(doc.data(), doc.id);
      }).toList();
      
      // Sort by updatedAt descending (most recent first)
      bookings.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      return bookings;
    } catch (e) {
      throw Exception('Failed to fetch cancelled bookings: $e');
    }
  }

  // Update booking status
  Future<void> updateBookingStatus(String bookingId, String status) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update booking status: $e');
    }
  }

  // Cancel a booking
  Future<void> cancelBooking(String bookingId, {String? cancellationReason}) async {
    try {
      final updateData = {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (cancellationReason != null) {
        updateData['cancellationReason'] = cancellationReason;
      } else {
        updateData['cancellationReason'] = 'user_cancelled';
      }
      
      await _firestore.collection('bookings').doc(bookingId).update(updateData);
    } catch (e) {
      throw Exception('Failed to cancel booking: $e');
    }
  }

  // Start a booking (mark as in_progress)
  Future<void> startBooking(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to start booking: $e');
    }
  }

  // Complete a booking
  // When a booking is marked as completed, it's excluded from availability checks.
  // This means if a user completes charging early (e.g., booking was 11:00-12:00,
  // but completed at 11:30), the remaining time slot (11:30-12:00) becomes
  // immediately available for other users to book.
  Future<void> completeBooking(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to complete booking: $e');
    }
  }

  // Update booking reminder setting
  Future<void> updateBookingReminder(String bookingId, bool remindMe) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'remindMe': remindMe,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update booking reminder: $e');
    }
  }

  // Get a specific booking by ID
  Future<BookingModel?> getBookingById(String bookingId) async {
    try {
      final doc = await _firestore.collection('bookings').doc(bookingId).get();
      if (doc.exists) {
        return BookingModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch booking: $e');
    }
  }

  // Stream of user bookings for real-time updates
  Stream<List<BookingModel>> getUserBookingsStream(String userId) {
    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final bookings = snapshot.docs.map((doc) {
        return BookingModel.fromFirestore(doc.data(), doc.id);
      }).toList();
      
      // Sort by startTime descending
      bookings.sort((a, b) => b.startTime.compareTo(a.startTime));
      
      return bookings;
    });
  }

  // Stream of upcoming bookings for real-time updates
  Stream<List<BookingModel>> getUpcomingBookingsStream(String userId) {
    final now = DateTime.now();
    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'upcoming')
        .snapshots()
        .map((snapshot) {
      final bookings = snapshot.docs.map((doc) {
        return BookingModel.fromFirestore(doc.data(), doc.id);
      }).where((booking) => booking.startTime.isAfter(now)).toList();
      // Sort by startTime ascending (earliest first)
      bookings.sort((a, b) => a.startTime.compareTo(b.startTime));
      
      return bookings;
    });
  }

  // Check if user has any active bookings at a specific station
  Future<bool> hasActiveBookingAtStation(String userId, String stationId) async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('stationId', isEqualTo: stationId)
          .where('status', whereIn: ['upcoming', 'in_progress'])
          .get();

      // Filter in memory to avoid complex index requirements
      final activeBookings = snapshot.docs.map((doc) {
        return BookingModel.fromFirestore(doc.data(), doc.id);
      }).where((booking) => booking.endTime.isAfter(now)).toList();

      return activeBookings.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check active booking: $e');
    }
  }

  // Delete a booking (permanent deletion)
  Future<void> deleteBooking(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).delete();
    } catch (e) {
      throw Exception('Failed to delete booking: $e');
    }
  }

  // Update payment status
  Future<void> updatePaymentStatus({
    required String bookingId,
    required String status,
    String? paymentId,
    String? transactionId,
    String? paymentMethod,
    Map<String, dynamic>? paymentMetadata,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'paymentStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (paymentId != null) updateData['paymentId'] = paymentId;
      if (transactionId != null) updateData['transactionId'] = transactionId;
      if (paymentMethod != null) updateData['paymentMethod'] = paymentMethod;
      if (paymentMetadata != null) updateData['paymentMetadata'] = paymentMetadata;

      if (status == 'paid') {
        updateData['paidAt'] = FieldValue.serverTimestamp();
      } else if (status == 'admin_confirmed') {
        updateData['confirmedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('bookings').doc(bookingId).update(updateData);
    } catch (e) {
      throw Exception('Failed to update payment status: $e');
    }
  }

  // Confirm payment (admin action)
  Future<void> confirmPayment(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'paymentStatus': 'admin_confirmed',
        'confirmedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to confirm payment: $e');
    }
  }

  // Auto-cancel no-show bookings
  // Cancels any 'upcoming' bookings that have passed their start time
  // with no charging activity (status still 'upcoming' after grace period)
  // Grace period is typically 15 minutes from start time
  Future<int> autoCloseNoShowBookings({int gracePeriodMinutes = 15}) async {
    try {
      int cancelledCount = 0;
      final now = DateTime.now();
      
      // Get all upcoming bookings
      final snapshot = await _firestore
          .collection('bookings')
          .where('status', isEqualTo: 'upcoming')
          .get();

      for (var doc in snapshot.docs) {
        final bookingData = doc.data();
        final booking = BookingModel.fromFirestore(bookingData, doc.id);
        
        // Calculate time past the start time
        final timePastStart = now.difference(booking.startTime);
        
        // If booking start time has passed by more than grace period
        // and status is still 'upcoming' (not started by admin)
        if (timePastStart.inMinutes >= gracePeriodMinutes) {
          // Auto-cancel the booking with no-show reason
          await _firestore.collection('bookings').doc(doc.id).update({
            'status': 'cancelled',
            'cancellationReason': 'no_show',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          cancelledCount++;
          
          print('Auto-cancelled no-show booking: ${doc.id} for station ${booking.stationId}');
        }
      }
      
      return cancelledCount;
    } catch (e) {
      throw Exception('Failed to auto-cancel no-show bookings: $e');
    }
  }

  // Get all upcoming bookings that are approaching grace period timeout
  // Useful for admin dashboard to see which bookings are at risk
  Future<List<BookingModel>> getUpcomingBookingsNearTimeout({int gracePeriodMinutes = 15}) async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('bookings')
          .where('status', isEqualTo: 'upcoming')
          .get();

      final risky = <BookingModel>[];
      
      for (var doc in snapshot.docs) {
        final booking = BookingModel.fromFirestore(doc.data(), doc.id);
        final timePastStart = now.difference(booking.startTime);
        
        // If booking has started but not yet timed out (grace period not yet exceeded)
        if (timePastStart.inMinutes >= 0 && timePastStart.inMinutes < gracePeriodMinutes) {
          risky.add(booking);
        }
      }
      
      return risky;
    } catch (e) {
      throw Exception('Failed to fetch bookings near timeout: $e');
    }
  }}