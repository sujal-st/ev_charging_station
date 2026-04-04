import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/booking_model.dart';
import 'services/station_admin_service.dart';

class StationBookingsScreen extends StatefulWidget {
  const StationBookingsScreen({super.key});

  @override
  State<StationBookingsScreen> createState() => _StationBookingsScreenState();
}

class _StationBookingsScreenState extends State<StationBookingsScreen> {
  final StationAdminService _adminService = StationAdminService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<BookingModel> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    if (!mounted) return;

    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bookings = await _adminService.getAllOwnerBookings(user.uid);
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading bookings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Bookings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBookings,
              child: _bookings.isEmpty
                  ? const Center(
                      child: Text('No bookings found.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _bookings.length,
                      itemBuilder: (context, index) {
                        final booking = _bookings[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text('Booking for ${booking.vehicleId}'),
                            subtitle: Text('Status: ${booking.status}'),
                            trailing: Text(booking.startTime.toString()),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

