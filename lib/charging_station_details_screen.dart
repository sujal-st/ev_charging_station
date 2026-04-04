import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'NavigationScreen.dart';
import 'create_booking_screen.dart';

class ChargingStationDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> station;

  const ChargingStationDetailsScreen({
    super.key,
    required this.station,
  });

  @override
  State<ChargingStationDetailsScreen> createState() =>
      _ChargingStationDetailsScreenState();
}

class _ChargingStationDetailsScreenState
    extends State<ChargingStationDetailsScreen> {
  late MapController _mapController;
  late List<Marker> _markers;
  bool _isFavorite = false;
  double? _distanceInKm;
  Position? _currentPosition;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<int, bool> _connectorStatusMap = {}; // Map of connector index to isInUse

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _setupMarkers();
    _checkIfFavorite();
    _calculateDistance();
    _checkConnectorStatuses();
  }

  Future<void> _checkConnectorStatuses() async {
    try {
      final stationId = widget.station['id'] ?? widget.station['firestoreId'] ?? '';
      if (stationId.isEmpty) return;

      // Get all active bookings for this station
      final snapshot = await _firestore
          .collection('bookings')
          .where('stationId', isEqualTo: stationId)
          .where('status', whereIn: ['upcoming', 'in_progress'])
          .get();

      final now = DateTime.now();
      final statusMap = <int, bool>{};

      // Check each booking to see if it's currently active
      for (var doc in snapshot.docs) {
        final bookingData = doc.data();
        final connectorIndex = bookingData['connectorIndex'];
        
        if (connectorIndex != null) {
          // Handle different data types for connectorIndex
          int? index;
          if (connectorIndex is int) {
            index = connectorIndex;
          } else if (connectorIndex is num) {
            index = connectorIndex.toInt();
          } else if (connectorIndex is String) {
            index = int.tryParse(connectorIndex);
          }
          
          if (index != null) {
            final startTime = (bookingData['startTime'] as Timestamp?)?.toDate();
            final endTime = (bookingData['endTime'] as Timestamp?)?.toDate();
            
            // Check if booking is currently active (now is between start and end)
            if (startTime != null && endTime != null) {
              if (now.isAfter(startTime) && now.isBefore(endTime)) {
                statusMap[index] = true; // In use
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _connectorStatusMap = statusMap;
        });
      }
    } catch (e) {
      print('Error checking connector statuses: $e');
    }
  }

  Future<void> _calculateDistance() async {
    try {
      // Request location permission if not granted
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.always &&
            permission != LocationPermission.whileInUse) {
          return;
        }
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final stationLat = _getLatitude(widget.station);
      final stationLng = _getLongitude(widget.station);

      final distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        stationLat,
        stationLng,
      );

      if (mounted) {
        setState(() {
          _distanceInKm = distanceInMeters / 1000; // Convert to km
        });
      }
    } catch (e) {
      print('Error calculating distance: $e');
    }
  }

  String _stationId() {
    return (widget.station['id']?.toString().isNotEmpty == true
            ? widget.station['id']
            : widget.station['firestoreId'] ?? '')
        .toString();
  }

  Future<void> _checkIfFavorite() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList('favorite_station_ids') ?? [];
      final stationId = _stationId();
      setState(() {
        _isFavorite = stationId.isNotEmpty && favorites.contains(stationId);
      });
    } catch (e) {
      print('Error checking favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList('favorite_station_ids') ?? [];
      final stationId = _stationId();

      if (stationId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to identify station'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        if (_isFavorite) {
          favorites.remove(stationId);
          _isFavorite = false;
        } else {
          if (!favorites.contains(stationId)) {
            favorites.add(stationId);
          }
          _isFavorite = true;
        }
      });

      await prefs.setStringList('favorite_station_ids', favorites);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _isFavorite ? 'Added to favorites' : 'Removed from favorites'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error toggling favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating favorites'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _setupMarkers() {
    _markers = [
      Marker(
        point:
            LatLng(_getLatitude(widget.station), _getLongitude(widget.station)),
        width: 40,
        height: 40,
        builder: (context) => const Icon(
          Icons.ev_station,
          color: Colors.green,
          size: 40,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Charging Station Details',
            style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : Colors.grey,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.white,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.ev_station,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.station['name'] ?? 'charging station Name',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.station['address'] ?? 'Address',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 16),
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 16),
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 16),
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 16),
                                const Icon(Icons.star_half,
                                    color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text('4.5',
                                    style: TextStyle(color: Colors.grey[600])),
                                const SizedBox(width: 4),
                                Text('(0 reviews)',
                                    style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorite ? Colors.red : Colors.grey,
                        ),
                        onPressed: _toggleFavorite,
                      ),
                    ],
                  ),
                ),
                // Status, distance
                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildStatusChip(),
                      const SizedBox(width: 12),
                      const Icon(Icons.location_on,
                          color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _distanceInKm != null
                            ? '${_distanceInKm!.toStringAsFixed(1)} km'
                            : 'Calculating...',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Consumer2<AuthProvider, BookingProvider>(
                          builder: (context, authProvider, bookingProvider, child) {
                            return ElevatedButton(
                              onPressed: authProvider.currentUser == null
                                  ? () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Please log in to book a station'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  : () async {
                                      // Check if station is available for booking
                                      final bool isAvailable = widget.station['available'] ?? true;
                                      final String status = widget.station['status'] ?? 'active';
                                      
                                      if (!isAvailable || status != 'active') {
                                        String message = 'This station is not available for booking.';
                                        if (!isAvailable) {
                                          message = 'This station is currently unavailable for booking.';
                                        } else if (status == 'maintenance' || status == 'under_maintenance') {
                                          message = 'This station is under maintenance and cannot be booked at this time.';
                                        } else if (status == 'inactive') {
                                          message = 'This station is inactive and cannot be booked.';
                                        }
                                        
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(message),
                                            backgroundColor: Colors.orange,
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );
                                        return;
                                      }
                                      
                                      // Check if user already has an active booking at this station
                                      final hasActiveBooking = await bookingProvider.hasActiveBookingAtStation(
                                        authProvider.currentUser!.uid,
                                        widget.station['id'] ?? widget.station['firestoreId'] ?? '',
                                      );
                                      
                                      if (hasActiveBooking) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('You already have an active booking at this station'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                        return;
                                      }
                                      
                                      // Navigate to create booking screen
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => CreateBookingScreen(
                                            station: widget.station,
                                          ),
                                        ),
                                      );
                                      
                                      // If booking was created successfully, show success message
                                      if (result == true && mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Booking created successfully!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[300],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Book station'),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            try {
                              // Request location permission if not granted
                              LocationPermission permission =
                                  await Geolocator.checkPermission();
                              if (permission == LocationPermission.denied ||
                                  permission ==
                                      LocationPermission.deniedForever) {
                                permission =
                                    await Geolocator.requestPermission();
                                if (permission != LocationPermission.always &&
                                    permission !=
                                        LocationPermission.whileInUse) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Location permission denied')),
                                  );
                                  return;
                                }
                              }

                              LatLng start = await getCurrentLocation();
                              LatLng end = LatLng(_getLatitude(widget.station),
                                  _getLongitude(widget.station));
                              List<LatLng> routePoints =
                                  await fetchRoute(start, end);

                              if (routePoints.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('No route found')),
                                );
                                return;
                              }

                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NavigationScreen(
                                    start: start,
                                    end: end,
                                    routePoints: routePoints,
                                  ),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Get directions'),
                        ),
                      ),
                    ],
                  ),
                ),
                // Tabs
                Container(
                  color: Colors.white,
                  child: DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        TabBar(
                          labelColor: Colors.green,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Colors.green,
                          indicatorWeight: 3,
                          tabs: const [
                            Tab(text: 'Info'),
                            Tab(text: 'Chargers'),
                            Tab(text: 'Reviews'),
                          ],
                        ),
                        SizedBox(
                          height: 600,
                          child: TabBarView(
                            children: [
                              // Info tab
                              _buildInfoTab(),
                              // Chargers tab
                              _buildChargersTab(),
                              // Reviews tab
                              const Center(child: Text('No reviews yet')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Book button at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.all(16.0),
              child: Consumer2<AuthProvider, BookingProvider>(
                builder: (context, authProvider, bookingProvider, child) {
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: authProvider.currentUser == null
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please log in to book a station'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          : () async {
                              // Check if station is available for booking
                              final bool isAvailable = widget.station['available'] ?? true;
                              final String status = widget.station['status'] ?? 'active';
                              
                              if (!isAvailable || status != 'active') {
                                String message = 'This station is not available for booking.';
                                if (!isAvailable) {
                                  message = 'This station is currently unavailable for booking.';
                                } else if (status == 'maintenance' || status == 'under_maintenance') {
                                  message = 'This station is under maintenance and cannot be booked at this time.';
                                } else if (status == 'inactive') {
                                  message = 'This station is inactive and cannot be booked.';
                                }
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(message),
                                    backgroundColor: Colors.orange,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                                return;
                              }
                              
                              // Check if user already has an active booking at this station
                              final hasActiveBooking = await bookingProvider.hasActiveBookingAtStation(
                                authProvider.currentUser!.uid,
                                widget.station['id'] ?? widget.station['firestoreId'] ?? '',
                              );
                              
                              if (hasActiveBooking) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('You already have an active booking at this station'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              
                              // Navigate to create booking screen
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreateBookingScreen(
                                    station: widget.station,
                                  ),
                                ),
                              );
                              
                              // If booking was created successfully, show success message
                              if (result == true && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Booking created successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'BOOK',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.station['description'] ??
                  'In this section write the description of the charging station which was written during charging station adding by the user',
              style: const TextStyle(color: Colors.black),
            ),
          ),
          const SizedBox(height: 24),
          // Parking and Pay section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Parking',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Pay', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Cost', style: TextStyle(color: Colors.grey[600])),
                    Text('Payment is required',
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Location section with map
          const Text(
            'Location of station',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Container(
                  height: 180,
                  margin: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        center: LatLng(_getLatitude(widget.station),
                            _getLongitude(widget.station)),
                        zoom: 15.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'com.example.ev_charging_station',
                        ),
                        MarkerLayer(markers: _markers),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    widget.station['address'] ?? 'Address not available',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _getLatitude(Map<String, dynamic> station) {
    var lat = station['lat'] ?? station['latitude'];
    if (lat == null) return 27.7172;
    if (lat is double) return lat;
    if (lat is int) return lat.toDouble();
    if (lat is String) return double.tryParse(lat) ?? 27.7172;
    return 27.7172;
  }

  double _getLongitude(Map<String, dynamic> station) {
    var lng = station['lng'] ?? station['longitude'];
    if (lng == null) return 85.3240;
    if (lng is double) return lng;
    if (lng is int) return lng.toDouble();
    if (lng is String) return double.tryParse(lng) ?? 85.3240;
    return 85.3240;
  }

  Widget _buildChargersTab() {
    // Get connectors from station data
    final connectors = widget.station['connectors'];
    
    // Handle different data formats
    List<Map<String, dynamic>> connectorList = [];
    
    if (connectors == null) {
      // No connectors found
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No chargers available for this station',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    
    if (connectors is List) {
      // Convert list to list of maps
      for (var connector in connectors) {
        if (connector is Map<String, dynamic>) {
          connectorList.add(connector);
        } else if (connector is Map) {
          connectorList.add(Map<String, dynamic>.from(connector));
        }
      }
    } else if (connectors is Map) {
      connectorList.add(Map<String, dynamic>.from(connectors));
    }

    if (connectorList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No chargers available for this station',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        itemCount: connectorList.length,
        itemBuilder: (context, index) {
          final connector = connectorList[index];
          final connectorType = connector['type']?.toString() ?? 'Unknown';
          final power = connector['power'] ?? connector['maxPower'] ?? 0.0;
          final powerKw = power is num ? power.toDouble() : 0.0;
          
          // Check if this connector is in use
          final isInUse = _connectorStatusMap[index] ?? false;
          final status = isInUse ? 'In use' : 'Available';
          final statusColor = isInUse ? Colors.orange : Colors.green;
          
          return Column(
            children: [
              _buildChargerItem(
                connectorType,
                '${powerKw.toStringAsFixed(0)} kW',
                status,
                statusColor,
              ),
              if (index < connectorList.length - 1) const Divider(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChargerItem(
      String type, String power, String status, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.electrical_services, color: Colors.green),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  power,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenityChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.green),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    // Get status from station data
    final bool isAvailable = widget.station['available'] ?? true;
    final String status = widget.station['status'] ?? 'active';
    
    String statusText;
    Color statusColor;
    Color backgroundColor;

    if (!isAvailable) {
      statusText = 'Unavailable';
      statusColor = Colors.red;
      backgroundColor = Colors.red[100]!;
    } else if (status == 'maintenance' || status == 'under_maintenance') {
      statusText = 'Under Maintenance';
      statusColor = Colors.orange;
      backgroundColor = Colors.orange[100]!;
    } else if (status == 'inactive') {
      statusText = 'Inactive';
      statusColor = Colors.grey;
      backgroundColor = Colors.grey[200]!;
    } else {
      statusText = 'Available';
      statusColor = Colors.green;
      backgroundColor = Colors.green[100]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: TextStyle(color: statusColor, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// Helper to get current location
Future<LatLng> getCurrentLocation() async {
  Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);
  return LatLng(position.latitude, position.longitude);
}

// Helper to fetch route from API
Future<List<LatLng>> fetchRoute(LatLng start, LatLng end) async {
  final apiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImMzNzEwNjAwN2RiNDRlMWI4ZTUwMDAzZDAxMWI2MTFjIiwiaCI6Im11cm11cjY0In0=';
  final url =
      'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}';
  final response = await http.get(Uri.parse(url));
  final data = json.decode(response.body);
  final coords = data['features'][0]['geometry']['coordinates'] as List;
  return coords.map((c) => LatLng(c[1], c[0])).toList();
}
