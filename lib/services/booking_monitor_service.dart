import 'dart:async';
import 'booking_service.dart';

/// BookingMonitorService handles background monitoring and auto-closure of no-show bookings
/// It runs a periodic timer that checks for bookings that have passed their start time
/// and automatically cancels them if the station admin hasn't started the charging session
class BookingMonitorService {
  static final BookingMonitorService _instance = BookingMonitorService._internal();
  
  final BookingService _bookingService = BookingService();
  Timer? _monitorTimer;
  
  // Configuration
  static const Duration _checkInterval = Duration(minutes: 1); // Check every minute
  static const int _gracePeriodMinutes = 15; // 15 minute grace period from start time
  
  bool _isRunning = false;
  int _totalCancelledCount = 0;

  factory BookingMonitorService() {
    return _instance;
  }

  BookingMonitorService._internal();

  /// Start the background monitoring service
  /// This will check for no-show bookings every minute
  void startMonitoring() {
    if (_isRunning) {
      print('Booking monitor is already running');
      return;
    }
    
    _isRunning = true;
    print('📊 Starting Booking Monitor Service...');
    
    // Run immediately on startup
    _checkAndCancelNoShowBookings();
    
    // Then run periodically
    _monitorTimer = Timer.periodic(_checkInterval, (_) {
      _checkAndCancelNoShowBookings();
    });
  }

  /// Stop the background monitoring service
  void stopMonitoring() {
    if (!_isRunning) {
      print('Booking monitor is not running');
      return;
    }
    
    _monitorTimer?.cancel();
    _isRunning = false;
    print('⏹️ Booking Monitor Service stopped');
  }

  /// Check for and cancel no-show bookings
  Future<void> _checkAndCancelNoShowBookings() async {
    try {
      final cancelledCount = await _bookingService.autoCloseNoShowBookings(
        gracePeriodMinutes: _gracePeriodMinutes,
      );
      
      if (cancelledCount > 0) {
        _totalCancelledCount += cancelledCount;
        print('🚫 Auto-cancelled $cancelledCount no-show booking(s). Total so far: $_totalCancelledCount');
      }
    } catch (e) {
      print('❌ Error in booking monitor: $e');
    }
  }

  /// Get the monitoring status
  bool get isRunning => _isRunning;
  
  /// Get total number of no-show bookings cancelled
  int get totalCancelledCount => _totalCancelledCount;

  /// Reset the cancelled count
  void resetCancelledCount() {
    _totalCancelledCount = 0;
  }

  /// Gracefully shutdown the service
  void dispose() {
    stopMonitoring();
  }
}
