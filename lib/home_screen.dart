import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'add_charging_station_screen.dart';
import 'charging_station_details_screen.dart';
import 'bookingscreen.dart'; // Make sure this import is at the top
import 'create_booking_screen.dart';
import 'profile_screen.dart';
import 'favorites_screen.dart';
import 'services/charging_station_service.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Position? _currentPosition;
  final List<Marker> _markers = [];
  MapController? _mapController;
  bool _isLoading = true;
  final LatLng _kathmandu =
      LatLng(27.7172, 85.3240); // Kathmandu, Nepal coordinates
  StreamSubscription<Position>? _positionSubscription;

  // Charging stations data - initially empty, will be populated when users add stations
  final List<Map<String, dynamic>> _stations = [];
  final ChargingStationService _stationService = ChargingStationService();
  Set<String> _favoriteIds = <String>{};
  
  // Filter and sort variables
  double _maxRangeKm = 50.0; // Default max range in km
  bool _sortByDistance = true; // Sort by shortest distance
  List<Map<String, dynamic>> _filteredStations = [];
  
  // Search variables
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStationData();
    _loadFavorites();
    _getCurrentLocation();
    
    // Listen to search text changes
    _searchController.addListener(_onSearchChanged);

    // Load user bookings if logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
      
      if (authProvider.currentUser != null) {
        bookingProvider.loadUserBookings(authProvider.currentUser!.uid);
      }
    });
  }


  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim();
    });
    _applyFilters();
  }

  // Calculate similarity score between two strings (0.0 to 1.0)
  // Higher score means more similar
  double _calculateSimilarity(String query, String text) {
    if (query.isEmpty) return 1.0;
    if (text.isEmpty) return 0.0;
    
    final queryLower = query.toLowerCase();
    final textLower = text.toLowerCase();
    
    // Exact match gets highest score
    if (textLower == queryLower) return 1.0;
    
    // Starts with query gets high score
    if (textLower.startsWith(queryLower)) return 0.9;
    
    // Contains query gets medium-high score
    if (textLower.contains(queryLower)) return 0.7;
    
    // Calculate character-based similarity
    int matches = 0;
    int queryIndex = 0;
    
    for (int i = 0; i < textLower.length && queryIndex < queryLower.length; i++) {
      if (textLower[i] == queryLower[queryIndex]) {
        matches++;
        queryIndex++;
      }
    }
    
    // Score based on how many query characters were found in order
    final orderScore = matches / queryLower.length;
    
    // Calculate common characters (not necessarily in order)
    final queryChars = queryLower.split('');
    final textChars = textLower.split('');
    int commonChars = 0;
    
    for (var char in queryChars) {
      if (textChars.contains(char)) {
        commonChars++;
        textChars.remove(char);
      }
    }
    
    final commonScore = commonChars / queryLower.length;
    
    // Weighted combination
    return (orderScore * 0.6 + commonScore * 0.4);
  }

  // Load charging station data from storage
  Future<void> _loadStationData() async {
    setState(() => _isLoading = true);
    try {
      // Always fetch from Firestore (source of truth)
      final remote = await _stationService.fetchAllStations();
      
      setState(() {
        _stations.clear();
        if (remote.isNotEmpty) {
          _stations.addAll(remote);
        }
        _isLoading = false;
        _applyFilters();
        _setupMarkers();
      });

      // Cache to local storage for faster next launch
      if (remote.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final toCache = remote.map((s) => jsonEncode(s)).toList();
        await prefs.setStringList('charging_stations', toCache);
      }
    } catch (e) {
      print('Error loading station data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Calculate distance from current location to station
  double? _calculateDistance(Map<String, dynamic> station) {
    if (_currentPosition == null) return null;
    
    final double stationLat = station['lat'] ?? station['latitude'] ?? 27.7172;
    final double stationLng = station['lng'] ?? station['longitude'] ?? 85.3240;
    
    try {
      final distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        stationLat,
        stationLng,
      );
      return distanceInMeters / 1000; // Convert to km
    } catch (e) {
      print('Error calculating distance: $e');
      return null;
    }
  }

  // Apply filters and sorting
  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_stations);
    
    // Apply search filter if query exists
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.map((station) {
        final stationName = (station['name'] ?? '').toString();
        final stationAddress = (station['address'] ?? '').toString();
        
        // Calculate similarity scores for name and address
        final nameScore = _calculateSimilarity(_searchQuery, stationName);
        final addressScore = _calculateSimilarity(_searchQuery, stationAddress);
        
        // Use the higher score (best match)
        final similarityScore = nameScore > addressScore ? nameScore : addressScore;
        
        // Add similarity score to station data
        station['similarityScore'] = similarityScore;
        
        return station;
      }).where((station) {
        // Only include stations with similarity score > 0.3 (threshold for relevance)
        final score = station['similarityScore'] as double? ?? 0.0;
        return score > 0.3;
      }).toList();
      
      // Sort by similarity score (highest first)
      filtered.sort((a, b) {
        final scoreA = a['similarityScore'] as double? ?? 0.0;
        final scoreB = b['similarityScore'] as double? ?? 0.0;
        return scoreB.compareTo(scoreA); // Descending order
      });
    }
    
    // If location is not available, show filtered stations without distance filtering
    if (_currentPosition == null) {
      setState(() {
        _filteredStations = filtered;
      });
      return;
    }
    
    // Calculate distances and add to station data
    for (var station in filtered) {
      final distance = _calculateDistance(station);
      station['distance'] = distance;
    }
    
    // Filter by range
    filtered = filtered.where((station) {
      final distance = station['distance'] as double?;
      return distance != null && distance <= _maxRangeKm;
    }).toList();
    
    // Sort by distance (shortest first) if not searching, or by similarity if searching
    if (_searchQuery.isEmpty && _sortByDistance) {
      filtered.sort((a, b) {
        final distA = a['distance'] as double?;
        final distB = b['distance'] as double?;
        if (distA == null && distB == null) return 0;
        if (distA == null) return 1;
        if (distB == null) return -1;
        return distA.compareTo(distB);
      });
    } else if (_searchQuery.isNotEmpty) {
      // When searching, sort by similarity first, then by distance
      filtered.sort((a, b) {
        final scoreA = a['similarityScore'] as double? ?? 0.0;
        final scoreB = b['similarityScore'] as double? ?? 0.0;
        
        // If similarity scores are very close (within 0.1), sort by distance
        if ((scoreA - scoreB).abs() < 0.1) {
          final distA = a['distance'] as double?;
          final distB = b['distance'] as double?;
          if (distA != null && distB != null) {
            return distA.compareTo(distB);
          }
        }
        
        return scoreB.compareTo(scoreA); // Higher similarity first
      });
    }
    
    setState(() {
      _filteredStations = filtered;
      _setupMarkers(); // Update map markers when filters change
    });
  }

  // Show filter dialog
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Stations'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Maximum Range (km)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _maxRangeKm,
                      min: 1.0,
                      max: 100.0,
                      divisions: 99,
                      label: '${_maxRangeKm.toStringAsFixed(1)} km',
                      onChanged: (value) {
                        setDialogState(() {
                          _maxRangeKm = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${_maxRangeKm.toStringAsFixed(1)} km',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Sort by shortest distance'),
                value: _sortByDistance,
                onChanged: (value) {
                  setDialogState(() {
                    _sortByDistance = value ?? true;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Reset to defaults
                setDialogState(() {
                  _maxRangeKm = 50.0;
                  _sortByDistance = true;
                });
              },
              child: const Text('Reset'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _applyFilters();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('favorite_station_ids') ?? <String>[];
      setState(() {
        _favoriteIds = ids.toSet();
      });
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_station_ids', _favoriteIds.toList());
    } catch (e) {
      print('Error saving favorites: $e');
    }
  }

  String _stationId(Map<String, dynamic> station) {
    return (station['id']?.toString().isNotEmpty == true
            ? station['id']
            : station['firestoreId'] ?? '')
        .toString();
  }

  bool _isFavorite(Map<String, dynamic> station) {
    final id = _stationId(station);
    return id.isNotEmpty && _favoriteIds.contains(id);
  }

  void _toggleFavorite(Map<String, dynamic> station) async {
    final id = _stationId(station);
    if (id.isEmpty) return;
    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
    });
    await _saveFavorites();
  }

  // Show favorites screen
  void _showFavoritesScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FavoritesScreen(),
      ),
    );
  }

  // Show profile options
  void _showProfileOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Profile Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.pop(context);
                await _logout();
              },
            ),
            ListTile(
              leading: const Icon(Icons.clear_all, color: Colors.orange),
              title: const Text('Clear All Data'),
              onTap: () async {
                Navigator.pop(context);
                await _clearAllData();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // Logout functionality
  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', false);
      await prefs.remove('username');

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (route) => false,
      );
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  // Clear all app data
  Future<void> _clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // This will clear all stored data

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data cleared successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Restart the app to show onboarding
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (route) => false,
      );
    } catch (e) {
      print('Error clearing all data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error clearing data'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    _mapController?.dispose();
    _positionSubscription?.cancel();
    super.dispose();
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Ensure permission is granted (defensive in case user skipped initial screen)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _currentPosition = position;
        _isLoading = false;
        _applyFilters();
        _setupMarkers();
      });

      // Start listening for more accurate/fresh updates
      _positionSubscription?.cancel();
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5, // meters
      );
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position updated) {
        setState(() {
          _currentPosition = updated;
          _applyFilters();
          _setupMarkers();
        });
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error getting location: $e');
    }
  }

  // Setup map markers for charging stations
  void _setupMarkers() {
    _markers.clear();

    // Add current location marker
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          point:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          width: 40,
          height: 40,
          builder: (context) => const Icon(
            Icons.my_location,
            color: Colors.blue,
            size: 30,
          ),
        ),
      );
    }

    // Add charging station markers (use filtered stations)
    final stationsToShow = _filteredStations.isNotEmpty ? _filteredStations : _stations;
    for (int i = 0; i < stationsToShow.length; i++) {
      final station = stationsToShow[i];
      final double lat = station['lat'] ?? station['latitude'] ?? 27.7172;
      final double lng = station['lng'] ?? station['longitude'] ?? 85.3240;

      _markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 140,
          height: 80,
          builder: (context) => GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Station name and address with favorite toggle
                        Text(
                          station['name'] ?? 'Charging station name',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            onPressed: () {
                              _toggleFavorite(station);
                              setState(() {});
                            },
                            icon: Icon(
                              _isFavorite(station)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          station['address'] ?? 'Address of station',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Rating, status, distance, time
                        Row(
                          children: [
                            Text(
                              '4.3',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Row(
                              children: List.generate(
                                4,
                                (index) => const Icon(Icons.star,
                                    color: Colors.amber, size: 18),
                              )..add(const Icon(Icons.star_half,
                                  color: Colors.amber, size: 18)),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(0 reviews)',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildStatusChip(station),
                            const SizedBox(width: 12),
                            const Icon(Icons.location_on,
                                color: Colors.grey, size: 18),
                            const SizedBox(width: 2),
                            Text(
                              _getDistanceText(station),
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                  side: const BorderSide(
                                      color: Colors.green, width: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ChargingStationDetailsScreen(
                                        station: station,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'view',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[400],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () {
                                  // Check if station is available for booking
                                  final bool isAvailable = station['available'] ?? true;
                                  final String status = station['status'] ?? 'active';
                                  
                                  if (!isAvailable || status != 'active') {
                                    Navigator.pop(context);
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
                                  
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CreateBookingScreen(
                                        station: station,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'book',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: station['available'] == true
                        ? Colors.green
                        : Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.ev_station,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    station['name'] ?? '',
                    style: const TextStyle(fontSize: 13, color: Colors.black),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // Move camera to current location
  void _goToCurrentLocation() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        15.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search bar and filter button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Colors.grey),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search station',
                                border: InputBorder.none,
                                hintStyle: const TextStyle(color: Colors.grey),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 20),
                                        onPressed: () {
                                          _searchController.clear();
                                        },
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.tune),
                      onPressed: _showFilterDialog,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            // Tab bar
            TabBar(
              controller: _tabController,
              labelColor: Colors.green,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.green,
              tabs: const [
                Tab(icon: Icon(Icons.list)),
                Tab(icon: Icon(Icons.map)),
              ],
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // List view
                  _buildStationListView(),

                  // Map view
                  _buildMapView(),
                ],
              ),
            ),

            // Bottom navigation bar
            BottomNavigationBar(
              currentIndex: 0,
              selectedItemColor: Colors.green,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              onTap: (index) {
                if (index == 1) {
                  // Favorites tab
                  _showFavoritesScreen();
                } else if (index == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BookingScreen()),
                  );
                } else if (index == 3) {
                  // Profile tab
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                }
                // Optionally handle index == 0 for Home
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.favorite_border),
                  label: 'Favorites',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.book_online),
                  label: 'My Bookings',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  label: 'Profile',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build station list view
  Widget _buildStationListView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_filteredStations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No stations found within ${_maxRangeKm.toStringAsFixed(1)} km',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _showFilterDialog,
              child: const Text('Adjust Filter'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _filteredStations.length,
      itemBuilder: (context, index) {
        final station = _filteredStations[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: station['available'] ? Colors.green : Colors.red,
              child: const Icon(Icons.ev_station, color: Colors.white),
            ),
            title: Text(station['name'] ?? 'Station name'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(station['address'] ?? 'Station address'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      station['available'] ? 'Available' : 'Not Available',
                      style: TextStyle(
                        color: station['available'] ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (station['distance'] != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 2),
                      Text(
                        '${(station['distance'] as double).toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _isFavorite(station)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: Colors.red,
                  ),
                  onPressed: () => _toggleFavorite(station),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChargingStationDetailsScreen(
                    station: station,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Build map view
  Widget _buildMapView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Use Kathmandu as default position if current location is not available
    final LatLng initialPosition = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _kathmandu;

    // Initialize map controller if not already done
    _mapController ??= MapController();

    // Setup markers if not already done
    if (_markers.isEmpty) {
      _setupMarkers();
    }

    return Stack(
      children: [
        // Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            center: initialPosition,
            zoom: 14.0,
            onTap: (tapPosition, point) {
              // Handle map tap if needed
            },
          ),
          children: [
            // Base map layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.ev_charging_station',
            ),
            // Markers layer
            MarkerLayer(markers: _markers),
          ],
        ),

        // Control buttons
        Positioned(
          right: 16.0,
          bottom: 16.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // My location button
              FloatingActionButton(
                heroTag: 'locationButton',
                mini: true,
                backgroundColor: Colors.white,
                onPressed: _goToCurrentLocation,
                child: const Icon(Icons.my_location, color: Colors.black),
              ),
              const SizedBox(height: 8.0),
              // Zoom in button
              FloatingActionButton(
                heroTag: 'zoomInButton',
                mini: true,
                backgroundColor: Colors.white,
                onPressed: () {
                  final currentZoom = _mapController?.zoom ?? 14.0;
                  _mapController?.move(
                      _mapController!.center, currentZoom + 1.0);
                },
                child: const Icon(Icons.add, color: Colors.black),
              ),
              const SizedBox(height: 8.0),
              // Zoom out button
              FloatingActionButton(
                heroTag: 'zoomOutButton',
                mini: true,
                backgroundColor: Colors.white,
                onPressed: () {
                  final currentZoom = _mapController?.zoom ?? 14.0;
                  _mapController?.move(
                      _mapController!.center, currentZoom - 1.0);
                },
                child: const Icon(Icons.remove, color: Colors.black),
              ),
            ],
          ),
        ),

        // List button
        Positioned(
          left: 16.0,
          bottom: 16.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'listButton',
                backgroundColor: Colors.green,
                onPressed: () {
                  _tabController.animateTo(0);
                },
                child: const Icon(Icons.list),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Build status chip for station popup
  Widget _buildStatusChip(Map<String, dynamic> station) {
    final bool isAvailable = station['available'] ?? true;
    final String status = station['status'] ?? 'active';
    
    String statusText;
    Color statusColor;

    if (!isAvailable) {
      statusText = 'Unavailable';
      statusColor = Colors.red;
    } else if (status == 'maintenance' || status == 'under_maintenance') {
      statusText = 'Under Maintenance';
      statusColor = Colors.orange;
    } else if (status == 'inactive') {
      statusText = 'Inactive';
      statusColor = Colors.grey;
    } else {
      statusText = 'Available';
      statusColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor == Colors.red 
            ? Colors.red[400]!
            : statusColor == Colors.orange
                ? Colors.orange[400]!
                : statusColor == Colors.grey
                    ? Colors.grey[400]!
                    : Colors.green[400]!,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  // Get distance text for station
  String _getDistanceText(Map<String, dynamic> station) {
    if (_currentPosition == null) {
      return 'Distance unknown';
    }
    
    final distance = station['distance'] as double?;
    if (distance != null) {
      return '${distance.toStringAsFixed(1)} km';
    }
    
    // Calculate distance if not already calculated
    try {
      final double stationLat = station['lat'] ?? station['latitude'] ?? 27.7172;
      final double stationLng = station['lng'] ?? station['longitude'] ?? 85.3240;
      
      final distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        stationLat,
        stationLng,
      );
      
      final distanceInKm = distanceInMeters / 1000;
      return '${distanceInKm.toStringAsFixed(1)} km';
    } catch (e) {
      return 'Distance unknown';
    }
  }
}
