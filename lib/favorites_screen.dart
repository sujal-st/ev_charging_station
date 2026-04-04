import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'charging_station_details_screen.dart';
import 'services/charging_station_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final ChargingStationService _stationService = ChargingStationService();
  List<Map<String, dynamic>> _favoriteStations = [];
  Set<String> _favoriteIds = <String>{};
  bool _isLoading = true;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      // Error getting location - silently fail
    }
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load favorite IDs from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('favorite_station_ids') ?? <String>[];
      setState(() {
        _favoriteIds = ids.toSet();
      });

      if (_favoriteIds.isEmpty) {
        setState(() {
          _favoriteStations.clear();
          _isLoading = false;
        });
        return;
      }

      // Load all stations from Firestore
      final allStations = await _stationService.fetchAllStations();

      // Filter to only favorite stations
      final favoriteStations = allStations.where((station) {
        final stationId = _stationId(station);
        return stationId.isNotEmpty && _favoriteIds.contains(stationId);
      }).toList();

      // Sort by distance if location is available
      if (_currentPosition != null) {
        favoriteStations.sort((a, b) {
          final distanceA = _calculateDistance(a);
          final distanceB = _calculateDistance(b);
          return distanceA.compareTo(distanceB);
        });
      }

      setState(() {
        _favoriteStations = favoriteStations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load favorites: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _stationId(Map<String, dynamic> station) {
    return (station['id']?.toString().isNotEmpty == true
            ? station['id']
            : station['firestoreId'] ?? '')
        .toString();
  }

  double _calculateDistance(Map<String, dynamic> station) {
    if (_currentPosition == null) return double.infinity;

    try {
      final lat = _getLatitude(station);
      final lng = _getLongitude(station);

      final distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        lat,
        lng,
      );

      return distanceInMeters / 1000; // Convert to km
    } catch (e) {
      return double.infinity;
    }
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

  Future<void> _toggleFavorite(Map<String, dynamic> station) async {
    final id = _stationId(station);
    if (id.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final List<String> favoriteIds = prefs.getStringList('favorite_station_ids') ?? [];

    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
        favoriteIds.remove(id);
        _favoriteStations.removeWhere((s) => _stationId(s) == id);
      } else {
        _favoriteIds.add(id);
        favoriteIds.add(id);
        _favoriteStations.add(station);
      }
    });

    await prefs.setStringList('favorite_station_ids', favoriteIds);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _favoriteIds.contains(id)
                ? 'Added to favorites'
                : 'Removed from favorites',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  bool _isFavorite(Map<String, dynamic> station) {
    final id = _stationId(station);
    return id.isNotEmpty && _favoriteIds.contains(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFavorites,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteStations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Favorite Stations',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add stations to favorites to see them here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _favoriteStations.length,
                    itemBuilder: (context, index) {
                      final station = _favoriteStations[index];
                      final distance = _currentPosition != null
                          ? _calculateDistance(station)
                          : null;
                      final isAvailable = station['available'] ?? false;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.1),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isAvailable ? Colors.green : Colors.grey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.ev_station,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          title: Text(
                            station['name'] ?? 'Unknown Station',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                station['address'] ?? 'Unknown Address',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              if (distance != null && distance != double.infinity) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${distance.toStringAsFixed(1)} km away',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
                            ).then((_) {
                              // Reload favorites when returning from details screen
                              _loadFavorites();
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
