import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/super_admin_service.dart';
import '../../models/user_model.dart';

class ViewBookingsScreen extends StatefulWidget {
  final UserModel user;

  const ViewBookingsScreen({
    super.key,
    required this.user,
  });

  @override
  State<ViewBookingsScreen> createState() => _ViewBookingsScreenState();
}

class _ViewBookingsScreenState extends State<ViewBookingsScreen> {
  final SuperAdminService _superAdminService = SuperAdminService();
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bookings = await _superAdminService.getBookingsByUser(widget.user.uid);
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load bookings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'N/A';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'upcoming':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPaymentStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'admin_confirmed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bookings - ${widget.user.name}'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.event_busy,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No bookings found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBookings,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _bookings.length,
                    itemBuilder: (context, index) {
                      final booking = _bookings[index];
                      return _buildBookingCard(booking);
                    },
                  ),
                ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] ?? 'unknown';
    final statusColor = _getStatusColor(status);
    final paymentStatus = booking['paymentStatus'];
    final paymentStatusColor = _getPaymentStatusColor(paymentStatus);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with station name and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking['stationName'] ?? 'Unknown Station',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Station Address
            if (booking['stationAddress'] != null)
              _buildInfoRow(Icons.location_on, booking['stationAddress']),
            
            // Start Time
            if (booking['startTime'] != null)
              _buildInfoRow(Icons.access_time, 'Start: ${_formatTimestamp(booking['startTime'])}'),
            
            // End Time
            if (booking['endTime'] != null)
              _buildInfoRow(Icons.access_time_filled, 'End: ${_formatTimestamp(booking['endTime'])}'),
            
            // Duration
            if (booking['durationMinutes'] != null)
              _buildInfoRow(
                Icons.timer,
                'Duration: ${booking['durationMinutes']} minutes',
              ),
            
            // Amount
            if (booking['amount'] != null)
              _buildInfoRow(
                Icons.attach_money,
                'Amount: Rs. ${(booking['amount'] as num).toStringAsFixed(2)}',
              ),
            
            // Plug Type
            if (booking['plugType'] != null)
              _buildInfoRow(Icons.power, 'Plug Type: ${booking['plugType']}'),
            
            // Max Power
            if (booking['maxPower'] != null)
              _buildInfoRow(
                Icons.flash_on,
                'Max Power: ${booking['maxPower']} kW',
              ),
            
            // Payment Status
            if (paymentStatus != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.payment,
                    size: 16,
                    color: paymentStatusColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Payment: ${paymentStatus.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: paymentStatusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            
            // Payment Method
            if (booking['paymentMethod'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Method: ${booking['paymentMethod']}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
            
            // Vehicle
            if (booking['vehicleModel'] != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.directions_car, 'Vehicle: ${booking['vehicleModel']}'),
            ],
            
            // Notes
            if (booking['notes'] != null && booking['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Notes:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                booking['notes'],
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
            
            // Created/Updated dates
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (booking['createdAt'] != null)
                  Text(
                    'Created: ${_formatTimestamp(booking['createdAt'])}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                if (booking['updatedAt'] != null)
                  Text(
                    'Updated: ${_formatTimestamp(booking['updatedAt'])}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

