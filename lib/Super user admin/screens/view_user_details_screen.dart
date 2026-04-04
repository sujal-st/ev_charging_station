import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/super_admin_service.dart';
import '../../models/user_model.dart';
import '../../models/roles.dart';

class ViewUserDetailsScreen extends StatefulWidget {
  final UserModel user;

  const ViewUserDetailsScreen({
    super.key,
    required this.user,
  });

  @override
  State<ViewUserDetailsScreen> createState() => _ViewUserDetailsScreenState();
}

class _ViewUserDetailsScreenState extends State<ViewUserDetailsScreen> {
  final SuperAdminService _superAdminService = SuperAdminService();
  int _stationsCount = 0;
  int _bookingsCount = 0;
  List<Map<String, dynamic>> _stations = [];
  List<Map<String, dynamic>> _bookings = [];
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isLoadingStations = false;
  bool _isLoadingBookings = false;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load user data directly from Firestore to get ALL fields
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();
      
      if (userDoc.exists) {
        _userData = userDoc.data();
      }

      // Load stations count and bookings count in parallel
      final results = await Future.wait([
        _superAdminService.getStationsCountByUser(widget.user.uid),
        _superAdminService.getBookingsCountByUser(widget.user.uid),
      ]);

      if (mounted) {
        setState(() {
          _stationsCount = results[0] as int;
          _bookingsCount = results[1] as int;
          _isLoading = false;
        });
      }

      // Load detailed data if needed
      if (widget.user.role == Roles.chargingStationUser && _stationsCount > 0) {
        _loadStations();
      }
      if (_bookingsCount > 0) {
        _loadBookings();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load user details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadStations() async {
    setState(() {
      _isLoadingStations = true;
    });

    try {
      final stations = await _superAdminService.getStationsByUser(widget.user.uid);
      if (mounted) {
        setState(() {
          _stations = stations;
          _isLoadingStations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStations = false;
        });
      }
    }
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoadingBookings = true;
    });

    try {
      final bookings = await _superAdminService.getBookingsByUser(widget.user.uid);
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _isLoadingBookings = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBookings = false;
        });
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

  Color _getRoleColor(String role) {
    switch (role) {
      case Roles.evChargingUser:
        return Colors.blue;
      case Roles.chargingStationUser:
        return Colors.orange;
      case Roles.superUser:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case Roles.evChargingUser:
        return 'Regular User';
      case Roles.chargingStationUser:
        return 'Station Admin';
      case Roles.superUser:
        return 'Super Admin';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Details - ${widget.user.name}'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Info Card
                  _buildUserInfoCard(),
                  const SizedBox(height: 16),
                  
                  // Statistics Card
                  _buildStatisticsCard(),
                  const SizedBox(height: 16),
                  
                  // Stations Section (for station admins)
                  if (widget.user.role == Roles.chargingStationUser) ...[
                    _buildStationsSection(),
                    const SizedBox(height: 16),
                  ],
                  
                  // Bookings Section
                  if (_bookingsCount > 0) ...[
                    _buildBookingsSection(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildUserInfoCard() {
    final isActive = (_userData?['isActive'] ?? true) as bool;
    final isDeleted = (_userData?['isDeleted'] ?? false) as bool;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isActive && !isDeleted ? Colors.green : Colors.grey,
                  radius: 30,
                  child: Text(
                    widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive && !isDeleted ? Colors.green[100] : Colors.red[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isDeleted ? 'Deleted' : (isActive ? 'Active' : 'Inactive'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDeleted ? Colors.red[800] : (isActive ? Colors.green[800] : Colors.red[800]),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            
            // Display ALL fields from Firestore
            const Text(
              'User Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // UID
            _buildDetailRow('User ID', _userData?['uid']?.toString() ?? widget.user.uid),
            
            // Email
            _buildDetailRow('Email', _userData?['email']?.toString() ?? widget.user.email),
            
            // Name
            _buildDetailRow('Name', _userData?['name']?.toString() ?? widget.user.name),
            
            // Role
            _buildDetailRow('Role', _getRoleLabel(_userData?['role']?.toString() ?? widget.user.role), 
                _getRoleColor(_userData?['role']?.toString() ?? widget.user.role)),
            
            // Phone Number
            if ((_userData?['phoneNumber']?.toString() ?? widget.user.phoneNumber ?? '').isNotEmpty)
              _buildDetailRow('Phone Number', _userData?['phoneNumber']?.toString() ?? widget.user.phoneNumber ?? ''),
            
            // Gender
            if ((_userData?['gender']?.toString() ?? widget.user.gender ?? '').isNotEmpty)
              _buildDetailRow('Gender', _userData?['gender']?.toString() ?? widget.user.gender ?? ''),
            
            // Date of Birth
            _buildDateOfBirthRow(),
            
            // Is Active
            _buildDetailRow('Is Active', isActive ? 'Yes' : 'No', isActive ? Colors.green : Colors.red),
            
            // Is Deleted
            if (_userData?['isDeleted'] != null)
              _buildDetailRow('Is Deleted', isDeleted ? 'Yes' : 'No', isDeleted ? Colors.red : Colors.green),
            
            // Is Logged In
            _buildDetailRow('Is Logged In', 
                ((_userData?['isLoggedIn'] ?? widget.user.isLoggedIn) as bool) ? 'Yes' : 'No', 
                ((_userData?['isLoggedIn'] ?? widget.user.isLoggedIn) as bool) ? Colors.green : Colors.grey),
            
            // Has Seen Onboarding
            _buildDetailRow('Has Seen Onboarding', 
                ((_userData?['hasSeenOnboarding'] ?? widget.user.hasSeenOnboarding) as bool) ? 'Yes' : 'No'),
            
            // Created At
            _buildTimestampRow('Created At', _userData?['createdAt'], widget.user.createdAt),
            
            // Updated At
            _buildTimestampRow('Updated At', _userData?['updatedAt'], widget.user.updatedAt),
            
            // Last Login
            _buildTimestampRow('Last Login', _userData?['lastLoginAt'], widget.user.lastLoginAt),
            
            // Last Logout
            _buildTimestampRow('Last Logout', _userData?['lastLogoutAt'], widget.user.lastLogoutAt),
            
            // Deleted At (if exists)
            if (_userData?['deletedAt'] != null)
              _buildDetailRow('Deleted At', _formatTimestamp(_userData!['deletedAt']), Colors.red),
          ],
        ),
      ),
    );
  }

  String _formatFieldValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is Timestamp) {
      return _formatTimestamp(value);
    }
    if (value is DateTime) {
      return _formatTimestamp(value);
    }
    if (value is bool) {
      return value ? 'Yes' : 'No';
    }
    if (value is List) {
      return value.isEmpty ? '[]' : '[${value.join(', ')}]';
    }
    if (value is Map) {
      return '{${value.entries.map((e) => '${e.key}: ${e.value}').join(', ')}}';
    }
    return value.toString();
  }

  Widget _buildDateOfBirthRow() {
    final dateOfBirth = _userData?['dateOfBirth'];
    if (dateOfBirth != null) {
      if (dateOfBirth is Timestamp) {
        final date = dateOfBirth.toDate();
        return _buildDetailRow('Date of Birth', '${date.day}/${date.month}/${date.year}');
      } else if (dateOfBirth is String) {
        try {
          final date = DateTime.parse(dateOfBirth);
          return _buildDetailRow('Date of Birth', '${date.day}/${date.month}/${date.year}');
        } catch (e) {
          return _buildDetailRow('Date of Birth', dateOfBirth);
        }
      } else {
        return _buildDetailRow('Date of Birth', dateOfBirth.toString());
      }
    } else if (widget.user.dateOfBirth != null) {
      return _buildDetailRow('Date of Birth', 
          '${widget.user.dateOfBirth!.day}/${widget.user.dateOfBirth!.month}/${widget.user.dateOfBirth!.year}');
    }
    return const SizedBox.shrink();
  }

  Widget _buildTimestampRow(String label, dynamic firestoreValue, DateTime? modelValue) {
    if (firestoreValue != null) {
      return _buildDetailRow(label, _formatTimestamp(firestoreValue));
    } else if (modelValue != null) {
      return _buildDetailRow(label, _formatTimestamp(Timestamp.fromDate(modelValue)));
    }
    return const SizedBox.shrink();
  }

  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? Colors.grey[800],
                fontWeight: valueColor != null ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Stations',
                    _stationsCount.toString(),
                    Colors.orange,
                    Icons.ev_station,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Bookings',
                    _bookingsCount.toString(),
                    Colors.blue,
                    Icons.event,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Stations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isLoadingStations)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed: _loadStations,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_stations.isEmpty && !_isLoadingStations)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No stations found',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else if (_isLoadingStations)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              ..._stations.map((station) => _buildStationItem(station)),
          ],
        ),
      ),
    );
  }

  Widget _buildStationItem(Map<String, dynamic> station) {
    final status = station['status'] ?? 'active';
    final statusColor = _getStatusColor(status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  station['name'] ?? 'Unnamed Station',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (station['address'] != null) ...[
            const SizedBox(height: 4),
            Text(
              station['address'],
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
          if (station['connectorsCount'] != null) ...[
            const SizedBox(height: 4),
            Text(
              '${station['connectorsCount']} connector(s)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.red;
      case 'maintenance':
      case 'under_maintenance':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildBookingsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Recent Bookings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isLoadingBookings)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed: _loadBookings,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_bookings.isEmpty && !_isLoadingBookings)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No bookings found',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else if (_isLoadingBookings)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              ..._bookings.take(5).map((booking) => _buildBookingItem(booking)),
            if (_bookings.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '... and ${_bookings.length - 5} more booking(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingItem(Map<String, dynamic> booking) {
    final status = booking['status'] ?? 'unknown';
    final statusColor = _getBookingStatusColor(status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking['stationName'] ?? 'Unknown Station',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (booking['startTime'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Start: ${_formatTimestamp(booking['startTime'])}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
          if (booking['amount'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Amount: Rs. ${(booking['amount'] as num).toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getBookingStatusColor(String status) {
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
}

