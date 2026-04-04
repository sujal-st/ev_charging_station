import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/booking_model.dart';
import 'services/station_admin_service.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  final StationAdminService _adminService = StationAdminService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<BookingModel> _allBookings = [];
  List<BookingModel> _upcomingBookings = [];
  List<BookingModel> _inProgressBookings = [];
  List<BookingModel> _completedBookings = [];
  List<BookingModel> _cancelledBookings = [];
  Map<String, String> _userNames = {}; // Cache for user names: userId -> name
  bool _isLoading = true;
  int selectedTab = 0; // 0 = Upcoming, 1 = In Progress, 2 = Completed, 3 = Cancelled

  @override
  void initState() {
    super.initState();
    // Schedule loading after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookings();
    });
  }

  Future<void> _loadBookings() async {
    if (!mounted) return;

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated. Please log in.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bookings = await _adminService.getAllOwnerBookings(user.uid);
      if (!mounted) return;
      
      // Fetch user names for all unique user IDs
      await _fetchUserNames(bookings);
      
      if (!mounted) return;
      setState(() {
        _allBookings = bookings;
        _categorizeBookings();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load bookings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchUserNames(List<BookingModel> bookings) async {
    // Get unique user IDs
    final Set<String> userIds = bookings
        .where((b) => b.userId.isNotEmpty)
        .map((b) => b.userId)
        .toSet();

    // Fetch user names for IDs not in cache
    final Set<String> idsToFetch = userIds
        .where((id) => !_userNames.containsKey(id))
        .toSet();

    if (idsToFetch.isEmpty) return;

    try {
      // Fetch user documents in batches (Firestore 'whereIn' limit is 10)
      final List<String> idsList = idsToFetch.toList();
      for (int i = 0; i < idsList.length; i += 10) {
        final batch = idsList.sublist(
          i,
          i + 10 > idsList.length ? idsList.length : i + 10,
        );

        // Use get() for each user document (more efficient than whereIn for single field)
        final futures = batch.map((userId) async {
          try {
            final doc = await _firestore.collection('users').doc(userId).get();
            if (doc.exists && doc.data() != null) {
              final data = doc.data()!;
              return MapEntry(userId, data['name'] ?? 'Unknown User');
            }
            return MapEntry(userId, 'Unknown User');
          } catch (e) {
            return MapEntry(userId, 'Unknown User');
          }
        });

        final results = await Future.wait(futures);
        for (final entry in results) {
          _userNames[entry.key] = entry.value;
        }
      }
    } catch (e) {
      print('Error fetching user names: $e');
      // Set default names for failed fetches
      for (final id in idsToFetch) {
        if (!_userNames.containsKey(id)) {
          _userNames[id] = 'Unknown User';
        }
      }
    }
  }

  String _getUserName(String userId) {
    if (userId.isEmpty) return 'Unknown User';
    return _userNames[userId] ?? 'Loading...';
  }

  Color _getPaymentStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.blue;
      case 'admin_confirmed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'refunded':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'paid':
        return Icons.payment;
      case 'admin_confirmed':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      case 'refunded':
        return Icons.undo;
      default:
        return Icons.help_outline;
    }
  }

  String _getPaymentStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'paid':
        return 'Paid';
      case 'admin_confirmed':
        return 'Confirmed';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      default:
        return status;
    }
  }

  void _categorizeBookings() {
    _upcomingBookings = _allBookings.where((b) => b.status == 'upcoming').toList();
    _inProgressBookings = _allBookings.where((b) => b.status == 'in_progress').toList();
    _completedBookings = _allBookings.where((b) => b.status == 'completed').toList();
    _cancelledBookings = _allBookings.where((b) => b.status == 'cancelled').toList();
  }

  Future<void> _updateBookingStatus(BookingModel booking, String newStatus) async {
    if (!mounted) return;

    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _adminService.updateBookingStatus(booking.id, newStatus, ownerId: user.uid);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Reload bookings
      await _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update booking status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmPayment(BookingModel booking) async {
    if (!mounted) return;

    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _adminService.confirmPayment(booking.id, ownerId: user.uid);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment confirmed successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Reload bookings
      await _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to confirm payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showStatusUpdateDialog(BookingModel booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Booking Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Status: ${booking.status}'),
            const SizedBox(height: 16),
            const Text('Select new status:'),
            const SizedBox(height: 8),
            if (booking.status == 'upcoming') ...[
              ListTile(
                title: const Text('Start Charging'),
                leading: const Icon(Icons.play_arrow, color: Colors.green),
                onTap: () {
                  Navigator.pop(context);
                  _updateBookingStatus(booking, 'in_progress');
                },
              ),
              ListTile(
                title: const Text('Cancel'),
                leading: const Icon(Icons.cancel, color: Colors.red),
                onTap: () {
                  Navigator.pop(context);
                  _updateBookingStatus(booking, 'cancelled');
                },
              ),
            ],
            if (booking.status == 'in_progress') ...[
              ListTile(
                title: const Text('Complete'),
                leading: const Icon(Icons.check_circle, color: Colors.green),
                onTap: () {
                  Navigator.pop(context);
                  _updateBookingStatus(booking, 'completed');
                },
              ),
              ListTile(
                title: const Text('Cancel'),
                leading: const Icon(Icons.cancel, color: Colors.red),
                onTap: () {
                  Navigator.pop(context);
                  _updateBookingStatus(booking, 'cancelled');
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget buildBookingCard(BookingModel booking) {
    String extraText = "";
    bool disableButtons = false;
    Color statusColor = Colors.grey;
    
    switch (booking.status) {
      case "completed":
        extraText = "✅ Charging completed successfully.";
        disableButtons = true;
        statusColor = Colors.green;
        break;
      case "cancelled":
        extraText = "❌ This booking was cancelled.";
        disableButtons = true;
        statusColor = Colors.red;
        break;
      case "in_progress":
        extraText = "🔋 Charging in progress...";
        statusColor = Colors.orange;
        break;
      case "upcoming":
        extraText = "⏰ Upcoming booking";
        statusColor = Colors.blue;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${booking.formattedDate}\n${booking.formattedTime}",
                    style: const TextStyle(fontWeight: FontWeight.w500)
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Text(
                  booking.status.toUpperCase().replaceAll('_', ' '),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Station Name
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.stationName,
                      style: const TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    Text(
                      booking.stationAddress, 
                      style: const TextStyle(color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // User Info (if available)
          if (booking.userId.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Customer: ${_getUserName(booking.userId)}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),

          // Payment Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _getPaymentStatusColor(booking.paymentStatus).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getPaymentStatusColor(booking.paymentStatus),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getPaymentStatusIcon(booking.paymentStatus),
                      size: 16,
                      color: _getPaymentStatusColor(booking.paymentStatus),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Payment: ${_getPaymentStatusText(booking.paymentStatus)}',
                      style: TextStyle(
                        color: _getPaymentStatusColor(booking.paymentStatus),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    if (booking.transactionId != null) ...[
                      const Spacer(),
                      Text(
                        'Txn: ${booking.transactionId!.substring(0, 8)}...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
                if (booking.paymentMethod != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        booking.paymentMethod == 'cod' 
                            ? Icons.money 
                            : Icons.payment,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        booking.paymentMethod == 'cod' 
                            ? 'Cash on Delivery' 
                            : 'Khalti',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Confirm Payment Button (if payment is paid but not confirmed, or COD pending)
          if ((booking.isPaymentPaid && !booking.isPaymentConfirmed) ||
              (booking.paymentMethod == 'cod' && booking.isPaymentPending))
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton.icon(
                onPressed: () => _confirmPayment(booking),
                icon: const Icon(Icons.check_circle, size: 20),
                label: Text(booking.paymentMethod == 'cod' 
                    ? 'Confirm COD Payment' 
                    : 'Confirm Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

          // Booking Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  const Icon(Icons.ev_station, color: Colors.grey),
                  const SizedBox(height: 4),
                  Text(
                    booking.plugType,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    "${booking.maxPower.toInt()} kW", 
                    style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                  const Text("Max power", style: TextStyle(fontSize: 12)),
                ],
              ),
              Column(
                children: [
                  Text(
                    booking.formattedDuration, 
                    style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                  const Text("Duration", style: TextStyle(fontSize: 12)),
                ],
              ),
              Column(
                children: [
                  Text(
                    booking.formattedAmount,
                    style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                  const Text("Amount", style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Buttons
          if (!disableButtons)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showStatusUpdateDialog(booking),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Update Status"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Show booking details
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(booking.stationName),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Customer: ${_getUserName(booking.userId)}'),
                                const SizedBox(height: 8),
                                Text('Status: ${booking.status}'),
                                Text('Start: ${booking.startTime.toLocal()}'),
                                Text('End: ${booking.endTime.toLocal()}'),
                                Text('Duration: ${booking.formattedDuration}'),
                                Text('Amount: ${booking.formattedAmount}'),
                                const SizedBox(height: 8),
                                Text('Payment Status: ${_getPaymentStatusText(booking.paymentStatus)}'),
                                if (booking.transactionId != null) Text('Transaction ID: ${booking.transactionId}'),
                                if (booking.paidAt != null) Text('Paid At: ${booking.paidAt!.toLocal()}'),
                                if (booking.confirmedAt != null) Text('Confirmed At: ${booking.confirmedAt!.toLocal()}'),
                                if (booking.notes != null) Text('Notes: ${booking.notes}'),
                                if (booking.vehicleModel != null) Text('Vehicle: ${booking.vehicleModel}'),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[400],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("View Details"),
                  ),
                ),
              ],
            ),
          if (extraText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              extraText,
              style: TextStyle(
                color: disableButtons ? Colors.grey : statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get bookings based on selected tab
    List<BookingModel> bookings = [];
    switch (selectedTab) {
      case 0:
        bookings = _upcomingBookings;
        break;
      case 1:
        bookings = _inProgressBookings;
        break;
      case 2:
        bookings = _completedBookings;
        break;
      case 3:
        bookings = _cancelledBookings;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.green),
        title: const Text('Manage Bookings', style: TextStyle(color: Colors.green)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadBookings(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Tabs
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => selectedTab = 0),
                          child: Column(
                            children: [
                              Text(
                                "Upcoming (${_upcomingBookings.length})",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: selectedTab == 0
                                      ? Colors.green
                                      : Colors.grey
                                ),
                              ),
                              if (selectedTab == 0)
                                Container(
                                  height: 2,
                                  color: Colors.green,
                                  margin: const EdgeInsets.only(top: 4)
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => selectedTab = 1),
                          child: Column(
                            children: [
                              Text(
                                "In Progress (${_inProgressBookings.length})",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: selectedTab == 1
                                      ? Colors.green
                                      : Colors.grey
                                ),
                              ),
                              if (selectedTab == 1)
                                Container(
                                  height: 2,
                                  color: Colors.green,
                                  margin: const EdgeInsets.only(top: 4)
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => selectedTab = 2),
                          child: Column(
                            children: [
                              Text(
                                "Completed (${_completedBookings.length})",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: selectedTab == 2
                                      ? Colors.green
                                      : Colors.grey
                                ),
                              ),
                              if (selectedTab == 2)
                                Container(
                                  height: 2,
                                  color: Colors.green,
                                  margin: const EdgeInsets.only(top: 4)
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => selectedTab = 3),
                          child: Column(
                            children: [
                              Text(
                                "Cancelled (${_cancelledBookings.length})",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: selectedTab == 3
                                      ? Colors.green
                                      : Colors.grey
                                ),
                              ),
                              if (selectedTab == 3)
                                Container(
                                  height: 2,
                                  color: Colors.green,
                                  margin: const EdgeInsets.only(top: 4)
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Content based on selected tab
                  Expanded(
                    child: bookings.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  selectedTab == 0
                                      ? Icons.schedule
                                      : selectedTab == 1
                                          ? Icons.flash_on
                                          : selectedTab == 2
                                              ? Icons.check_circle_outline
                                              : Icons.cancel_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  selectedTab == 0
                                      ? 'No upcoming bookings'
                                      : selectedTab == 1
                                          ? 'No in-progress bookings'
                                          : selectedTab == 2
                                              ? 'No completed bookings'
                                              : 'No cancelled bookings',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadBookings,
                            child: ListView.builder(
                              itemCount: bookings.length,
                              itemBuilder: (context, index) {
                                return buildBookingCard(bookings[index]);
                              },
                            ),
                          ),
                  )
                ],
              ),
            ),
    );
  }
}