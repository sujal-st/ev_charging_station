import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

class BookingProvider extends ChangeNotifier {
  final BookingService _bookingService = BookingService();
  
  List<BookingModel> _allBookings = [];
  List<BookingModel> _upcomingBookings = [];
  List<BookingModel> _completedBookings = [];
  List<BookingModel> _cancelledBookings = [];
  
  bool _isLoading = false;
  String? _error;

  // Getters
  List<BookingModel> get allBookings => _allBookings;
  List<BookingModel> get upcomingBookings => _upcomingBookings;
  List<BookingModel> get completedBookings => _completedBookings;
  List<BookingModel> get cancelledBookings => _cancelledBookings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get bookings by status
  List<BookingModel> getBookingsByStatus(String status) {
    switch (status) {
      case 'upcoming':
        return _upcomingBookings;
      case 'completed':
        return _completedBookings;
      case 'cancelled':
        return _cancelledBookings;
      default:
        return _allBookings;
    }
  }

  // Load all bookings for a user
  Future<void> loadUserBookings(String userId) async {
    _setLoading(true);
    _clearError();
    
    try {
      _allBookings = await _bookingService.getUserBookings(userId);
      _categorizeBookings();
    } catch (e) {
      _setError('Failed to load bookings: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load bookings by status
  Future<void> loadBookingsByStatus(String userId, String status) async {
    _setLoading(true);
    _clearError();
    
    try {
      List<BookingModel> bookings;
      switch (status) {
        case 'upcoming':
          bookings = await _bookingService.getUpcomingBookings(userId);
          _upcomingBookings = bookings;
          break;
        case 'completed':
          bookings = await _bookingService.getCompletedBookings(userId);
          _completedBookings = bookings;
          break;
        case 'cancelled':
          bookings = await _bookingService.getCancelledBookings(userId);
          _cancelledBookings = bookings;
          break;
        default:
          bookings = await _bookingService.getUserBookings(userId);
          _allBookings = bookings;
      }
    } catch (e) {
      _setError('Failed to load $status bookings: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Create a new booking
  Future<bool> createBooking({
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
    _setLoading(true);
    _clearError();
    
    try {
      final bookingId = await _bookingService.createBooking(
        userId: userId,
        stationId: stationId,
        stationName: stationName,
        stationAddress: stationAddress,
        stationLatitude: stationLatitude,
        stationLongitude: stationLongitude,
        plugType: plugType,
        maxPower: maxPower,
        durationMinutes: durationMinutes,
        amount: amount,
        startTime: startTime,
        connectorIndex: connectorIndex,
        notes: notes,
        vehicleId: vehicleId,
        vehicleModel: vehicleModel,
      );
      
      // Reload bookings to get the new one
      await loadUserBookings(userId);
      return true;
    } catch (e) {
      _setError('Failed to create booking: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Cancel a booking
  Future<bool> cancelBooking(String bookingId, String userId) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _bookingService.cancelBooking(bookingId);
      
      // Update local state
      final bookingIndex = _allBookings.indexWhere((b) => b.id == bookingId);
      if (bookingIndex != -1) {
        _allBookings[bookingIndex] = _allBookings[bookingIndex].copyWith(
          status: 'cancelled',
          updatedAt: DateTime.now(),
        );
        _categorizeBookings();
      }
      
      return true;
    } catch (e) {
      _setError('Failed to cancel booking: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Start a booking
  Future<bool> startBooking(String bookingId, String userId) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _bookingService.startBooking(bookingId);
      
      // Update local state
      final bookingIndex = _allBookings.indexWhere((b) => b.id == bookingId);
      if (bookingIndex != -1) {
        _allBookings[bookingIndex] = _allBookings[bookingIndex].copyWith(
          status: 'in_progress',
          updatedAt: DateTime.now(),
        );
        _categorizeBookings();
      }
      
      return true;
    } catch (e) {
      _setError('Failed to start booking: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Complete a booking
  Future<bool> completeBooking(String bookingId, String userId) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _bookingService.completeBooking(bookingId);
      
      // Update local state
      final bookingIndex = _allBookings.indexWhere((b) => b.id == bookingId);
      if (bookingIndex != -1) {
        _allBookings[bookingIndex] = _allBookings[bookingIndex].copyWith(
          status: 'completed',
          updatedAt: DateTime.now(),
        );
        _categorizeBookings();
      }
      
      return true;
    } catch (e) {
      _setError('Failed to complete booking: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update booking reminder
  Future<bool> updateBookingReminder(String bookingId, bool remindMe, String userId) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _bookingService.updateBookingReminder(bookingId, remindMe);
      
      // Update local state
      final bookingIndex = _allBookings.indexWhere((b) => b.id == bookingId);
      if (bookingIndex != -1) {
        _allBookings[bookingIndex] = _allBookings[bookingIndex].copyWith(
          remindMe: remindMe,
          updatedAt: DateTime.now(),
        );
        _categorizeBookings();
      }
      
      return true;
    } catch (e) {
      _setError('Failed to update reminder: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Check if user has active booking at station
  Future<bool> hasActiveBookingAtStation(String userId, String stationId) async {
    try {
      return await _bookingService.hasActiveBookingAtStation(userId, stationId);
    } catch (e) {
      _setError('Failed to check active booking: $e');
      return false;
    }
  }

  // Get booking by ID
  Future<BookingModel?> getBookingById(String bookingId) async {
    try {
      return await _bookingService.getBookingById(bookingId);
    } catch (e) {
      _setError('Failed to get booking: $e');
      return null;
    }
  }

  // Categorize bookings into different lists
  void _categorizeBookings() {
    _upcomingBookings = _allBookings.where((b) => b.isUpcoming).toList();
    _completedBookings = _allBookings.where((b) => b.isCompleted).toList();
    _cancelledBookings = _allBookings.where((b) => b.isCancelled).toList();
  }

  // Clear all bookings
  void clearBookings() {
    _allBookings.clear();
    _upcomingBookings.clear();
    _completedBookings.clear();
    _cancelledBookings.clear();
    notifyListeners();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  // Refresh all data
  Future<void> refresh(String userId) async {
    await loadUserBookings(userId);
  }

  // Auto-cancel no-show bookings (app-level call)
  Future<int> autoCloseNoShowBookings({int gracePeriodMinutes = 15}) async {
    try {
      return await _bookingService.autoCloseNoShowBookings(
        gracePeriodMinutes: gracePeriodMinutes,
      );
    } catch (e) {
      _setError('Failed to process no-show cancellations: $e');
      return 0;
    }
  }

  // Get bookings nearing timeout (for admin dashboard)
  Future<List<BookingModel>> getBookingsNearTimeout({int gracePeriodMinutes = 15}) async {
    try {
      return await _bookingService.getUpcomingBookingsNearTimeout(
        gracePeriodMinutes: gracePeriodMinutes,
      );
    } catch (e) {
      _setError('Failed to fetch bookings near timeout: $e');
      return [];
    }
  }
}