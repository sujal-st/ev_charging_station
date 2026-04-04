import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../login_screen.dart';
import 'services/station_admin_service.dart';
import '../add_charging_station_screen.dart';
import 'edit_charging_station_screen.dart';
import 'admin_stations_map_screen.dart';
import 'widgets/stat_card.dart';
import 'widgets/quick_action_card.dart';
import 'widgets/sales_overview_section.dart';
import 'station_bookings_screen.dart';
import 'admin_bookings_screen.dart';
import 'payment_tracking_screen.dart';

class StationAdminDashboard extends StatefulWidget {
  const StationAdminDashboard({super.key});

  @override
  State<StationAdminDashboard> createState() => _StationAdminDashboardState();
}

class _StationAdminDashboardState extends State<StationAdminDashboard> {
  final StationAdminService _adminService = StationAdminService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _stations = [];
  Map<String, dynamic> _statistics = {
    'totalStations': 0,
    'totalBookings': 0,
    'inProgressBookings': 0,
    'completedBookings': 0,
  };
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Use a post-frame callback to ensure the user is authenticated
    // before loading data. This is safer than loading directly in initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
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
      // Set up real-time stream for stations
      _adminService.getOwnerStationsStream(user.uid).listen(
        (stations) {
          if (!mounted) return;
          setState(() {
            _stations = stations;
            _isLoading = false;
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading stations: $error'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );

      // Load statistics
      final statistics = await _adminService.getOwnerStatistics(user.uid);
      if (!mounted) return;
      
      setState(() {
        _statistics = statistics;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load dashboard data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistics',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final cardWidth = (constraints.maxWidth - 16) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: StatCard(
                        title: 'Total Stations',
                        value: _statistics['totalStations']?.toString() ?? '0',
                        icon: Icons.ev_station,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: StatCard(
                        title: 'Total Bookings',
                        value: _statistics['totalBookings']?.toString() ?? '0',
                        icon: Icons.bookmark,
                        color: Colors.orange,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: StatCard(
                        title: 'In Progress',
                        value: _statistics['inProgressBookings']?.toString() ?? '0',
                        icon: Icons.flash_on,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: StatCard(
                        title: 'Completed',
                        value: _statistics['completedBookings']?.toString() ?? '0',
                        icon: Icons.check_circle,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            
            // Sales & Revenue Section
            const SalesOverviewSection(),
            
            const SizedBox(height: 24),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            QuickActionCard(
              title: 'Add New Station',
              icon: Icons.add_location,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddChargingStationScreen(),
                  ),
                ).then((result) {
                  if (result == true) {
                    _loadDashboardData();
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            QuickActionCard(
              title: 'View All Stations',
              icon: Icons.map,
              onTap: () {
                if (mounted) {
                  setState(() {
                    _selectedIndex = 1; // Changed from _selectedTab to _selectedIndex
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            QuickActionCard(
              title: 'Manage Bookings',
              icon: Icons.calendar_today,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StationBookingsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            QuickActionCard(
              title: 'Payment Track',
              icon: Icons.payment,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PaymentTrackingScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationsTab() {
    if (_stations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.ev_station, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No stations added yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddChargingStationScreen(),
                  ),
                ).then((result) {
                  if (result == true) {
                    _loadDashboardData();
                  }
                });
              },
              icon: const Icon(Icons.add_location),
              label: const Text('Add Your First Station'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _stations.length,
        itemBuilder: (context, index) {
          final station = _stations[index];
          final bool isAvailable = station['available'] ?? false;
          
          final verificationStatus = station['verificationStatus'] ?? 'pending';
          final isPending = verificationStatus == 'pending';
          final isApproved = verificationStatus == 'approved';
          final isRejected = verificationStatus == 'rejected';
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isAvailable ? Colors.green : Colors.grey,
                child: const Icon(
                  Icons.ev_station,
                  color: Colors.white,
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(station['name'] ?? 'Unnamed'),
                  ),
                  // Verification Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPending 
                          ? Colors.orange.withOpacity(0.2)
                          : isApproved
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPending
                            ? Colors.orange
                            : isApproved
                                ? Colors.green
                                : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isPending
                          ? 'Pending Verification'
                          : isApproved
                              ? 'Approved'
                              : 'Rejected',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isPending
                            ? Colors.orange[800]
                            : isApproved
                                ? Colors.green[800]
                                : Colors.red[800],
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(station['address'] ?? 'No address'),
                  if (isPending) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Awaiting super admin approval',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (isRejected && station['rejectionReason'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Reason: ${station['rejectionReason']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditChargingStationScreen(station: station),
                  ),
                ).then((result) {
                  if (result == true) {
                    _loadDashboardData();
                  }
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookingsTab() {
    return const AdminBookingsScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminStationsMapScreen(stations: _stations),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<app_auth.AuthProvider>().signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: [
                _buildOverviewTab(),
                _buildStationsTab(),
                _buildBookingsTab(),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.ev_station),
            label: 'Stations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_online),
            label: 'Bookings',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}