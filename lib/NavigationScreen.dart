import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

class NavigationScreen extends StatefulWidget {
  final LatLng start;
  final LatLng end;
  final List<LatLng> routePoints;

  const NavigationScreen({
    super.key,
    required this.start,
    required this.end,
    required this.routePoints,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  MapController? _mapController;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  void _goToCurrentLocation() {
    _mapController?.move(widget.start, 14.0);
  }

  Future<void> _launchGoogleMapsNavigation() async {
    setState(() {
      _isNavigating = true;
    });

    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permissions are required for navigation.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied. Please enable them in settings.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get current location
      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Log coordinates for debugging
      print('Current Location: ${currentPosition.latitude}, ${currentPosition.longitude}');
      print('Destination: ${widget.end.latitude}, ${widget.end.longitude}');

      // Prioritize Android-specific navigation URLs
      final List<String> urlsToTry = [];
      
      // For Android, use Google Maps navigation intent (directly starts navigation)
      if (Platform.isAndroid) {
        // Primary: Google Maps navigation intent - directly starts turn-by-turn navigation
        urlsToTry.add('google.navigation:q=${widget.end.latitude},${widget.end.longitude}');
        
        // Secondary: Google Maps app with directions
        urlsToTry.add('comgooglemaps://?saddr=${currentPosition.latitude},${currentPosition.longitude}&daddr=${widget.end.latitude},${widget.end.longitude}&directionsmode=driving');
        
        // Tertiary: Geo URI scheme (opens default map app)
        urlsToTry.add('geo:${widget.end.latitude},${widget.end.longitude}?q=${widget.end.latitude},${widget.end.longitude}');
        
        // Fallback: Google Maps web with navigation
        urlsToTry.add('https://www.google.com/maps/dir/?api=1&origin=${currentPosition.latitude},${currentPosition.longitude}&destination=${widget.end.latitude},${widget.end.longitude}&travelmode=driving');
      } else if (Platform.isIOS) {
        // For iOS, use Apple Maps or Google Maps
        urlsToTry.add('http://maps.apple.com/?saddr=${currentPosition.latitude},${currentPosition.longitude}&daddr=${widget.end.latitude},${widget.end.longitude}');
        urlsToTry.add('comgooglemaps://?saddr=${currentPosition.latitude},${currentPosition.longitude}&daddr=${widget.end.latitude},${widget.end.longitude}&directionsmode=driving');
        urlsToTry.add('https://www.google.com/maps/dir/?api=1&origin=${currentPosition.latitude},${currentPosition.longitude}&destination=${widget.end.latitude},${widget.end.longitude}&travelmode=driving');
      } else {
        // Web or other platforms
        urlsToTry.add('https://www.google.com/maps/dir/?api=1&origin=${currentPosition.latitude},${currentPosition.longitude}&destination=${widget.end.latitude},${widget.end.longitude}&travelmode=driving');
      }

      bool launched = false;
      for (int i = 0; i < urlsToTry.length; i++) {
        String url = urlsToTry[i];
        try {
          print('Trying URL ${i + 1}: $url');
          final uri = Uri.parse(url);
          
          // For Android navigation intent, try to launch directly
          if (Platform.isAndroid && url.startsWith('google.navigation:')) {
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              print('Successfully launched Google Maps navigation');
              launched = true;
              break;
            } catch (e) {
              print('Failed to launch navigation intent: $e');
              // Continue to next URL
              continue;
            }
          }
          
          // For other URLs, check if they can be launched
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            print('Successfully launched URL ${i + 1}');
            launched = true;
            break;
          }
        } catch (e) {
          print('Failed to launch URL ${i + 1}: $e');
          // Continue to next URL if this one fails
          continue;
        }
      }

      if (!launched) {
        // Show error message if none of the URLs work
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open maps application. Please install Google Maps.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Handle location permission or other errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location or opening maps: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isNavigating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: Colors.black),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: widget.start,
                    zoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.ev_charging_station',
                    ),
                    PolylineLayer(
                      polylineCulling: false,
                      polylines: [
                        Polyline(
                          points: widget.routePoints,
                          color: Colors.green,
                          strokeWidth: 4,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: widget.start,
                          width: 40,
                          height: 40,
                          builder: (ctx) => const Icon(Icons.my_location,
                              color: Colors.blue, size: 32),
                        ),
                        Marker(
                          point: widget.end,
                          width: 40,
                          height: 40,
                          builder: (ctx) => const Icon(Icons.ev_station,
                              color: Colors.green, size: 32),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isNavigating ? null : _launchGoogleMapsNavigation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isNavigating ? Colors.grey[400] : Colors.green[400],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _isNavigating
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Opening Maps...', style: TextStyle(fontSize: 18)),
                            ],
                          )
                        : const Text('start', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
            ],
          ),
          // Control buttons
          Positioned(
            right: 16.0,
            bottom: 80.0, // Positioned above the start button
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
        ],
      ),
    );
  }
}
