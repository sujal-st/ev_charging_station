import 'dart:async';
import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../providers/booking_provider.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

/// Global service to manage booking arrival confirmations
/// Ensures each booking is only prompted once across the entire app
class BookingNotificationService {
  static final BookingNotificationService _instance = BookingNotificationService._internal();

  Timer? _confirmationTimer;
  final Set<String> _promptedBookings = <String>{};
  bool _isRunning = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  // Configuration
  static const Duration _checkInterval = Duration(seconds: 30);

  factory BookingNotificationService() {
    return _instance;
  }

  BookingNotificationService._internal();

  /// Initialize the service with a navigator key
  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  /// Start the global confirmation checking service
  void startConfirmationChecking() {
    if (_navigatorKey == null) {
      print('❌ BookingNotificationService: Navigator key not set');
      return;
    }

    if (_isRunning) return;

    _isRunning = true;
    print('📱 Starting global booking confirmation service...');

    // Check immediately on start
    _checkForBookingConfirmations();

    // Then check periodically
    _confirmationTimer = Timer.periodic(_checkInterval, (_) {
      _checkForBookingConfirmations();
    });
  }

  /// Stop the confirmation checking service
  void stopConfirmationChecking() {
    if (!_isRunning) return;

    _confirmationTimer?.cancel();
    _isRunning = false;
    print('⏹️ Booking confirmation service stopped');
  }

  /// Check for bookings that need confirmation
  void _checkForBookingConfirmations() {
    final context = _navigatorKey?.currentContext;
    if (context == null || !context.mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);

    if (authProvider.currentUser == null) return;

    final now = DateTime.now();
    final upcomingBookings = bookingProvider.upcomingBookings;

    for (final booking in upcomingBookings) {
      // Check if booking starts within 10 minutes
      final timeUntilStart = booking.startTime.difference(now);
      if (timeUntilStart.inMinutes <= 10 && timeUntilStart.inMinutes >= 0) {
        // Check if we haven't already prompted for this booking globally
        if (!_promptedBookings.contains(booking.id)) {
          _promptedBookings.add(booking.id);
          _showArrivalConfirmationDialog(context, booking);
        }
      }
    }
  }

  /// Show the arrival confirmation dialog
  void _showArrivalConfirmationDialog(BuildContext context, BookingModel booking) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // User must choose
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Your Arrival'),
          content: Text(
            'Your booking at ${booking.stationName} starts in ${booking.startTime.difference(DateTime.now()).inMinutes} minutes. '
            'Will you be arriving on time to start charging?'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleBookingCancellation(context, booking);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('No, Cancel Booking'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // User confirmed they will arrive - just dismiss dialog
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Yes, I\'m on my way'),
            ),
          ],
        );
      },
    );
  }

  /// Handle booking cancellation
  Future<void> _handleBookingCancellation(BuildContext context, BookingModel booking) async {
    if (!context.mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);

    final success = await bookingProvider.cancelBooking(
      booking.id,
      authProvider.currentUser!.uid
    );

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Booking cancelled due to no-show confirmation"),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bookingProvider.error ?? "Failed to cancel booking"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Get the service status
  bool get isRunning => _isRunning;

  /// Get number of prompted bookings
  int get promptedBookingsCount => _promptedBookings.length;

  /// Clear prompted bookings (useful for testing or reset)
  void clearPromptedBookings() {
    _promptedBookings.clear();
  }

  /// Gracefully shutdown the service
  void dispose() {
    stopConfirmationChecking();
  }
}