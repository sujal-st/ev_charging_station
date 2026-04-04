import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'NavigationScreen.dart';
import 'create_booking_screen.dart';
import 'services/charging_station_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class _Place {
  final String displayName;
  final String shortName;
  final LatLng location;

  _Place({
    required this.displayName,
    required this.shortName,
    required this.location,
  });
}

class _RouteStation {
  final String id;
  final String name;
  final String address;
  final LatLng location;
  final double distanceFromRoute; // metres
  final double distanceAlongRoute; // km from origin
  final String source;
  final Map<String, dynamic>? stationData;

  _RouteStation({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.distanceFromRoute,
    required this.distanceAlongRoute,
    required this.source,
    this.stationData,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Which field is active for search
// ─────────────────────────────────────────────────────────────────────────────
enum _ActiveField { origin, destination }

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class TripPlannerScreen extends StatefulWidget {
  const TripPlannerScreen({super.key});

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen>
    with SingleTickerProviderStateMixin {
  static const double _maxOffRouteDistanceMetres = 5000;

  // Controllers
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _originFocus = FocusNode();
  final FocusNode _destinationFocus = FocusNode();
  final MapController _mapController = MapController();
  final ChargingStationService _stationService = ChargingStationService();
  late final AnimationController _panelAnim;
  late final Animation<double> _panelSlide;

  // Locations
  LatLng? _gpsLocation;
  LatLng? _originLocation;
  LatLng? _destinationLocation;

  // Results
  List<LatLng> _routePoints = [];
  List<_RouteStation> _nearbyStations = [];
  List<_Place> _suggestions = [];

  // UI state
  _ActiveField _activeField = _ActiveField.destination;
  bool _isLoadingGps = false;
  bool _isLoadingRoute = false;
  bool _isSearching = false;
  bool _showPanel = false;
  bool _showSearch = true;
  String? _errorMessage;

  // Debounce
  DateTime _lastSearch = DateTime.now();

  @override
  void initState() {
    super.initState();
    _panelAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _panelSlide =
        CurvedAnimation(parent: _panelAnim, curve: Curves.easeOutCubic);

    _originController.text = 'My location';
    _fetchGPS();

    _originFocus.addListener(() {
      if (_originFocus.hasFocus) {
        setState(() => _activeField = _ActiveField.origin);
        if (_originController.text == 'My location') {
          _originController.clear();
        }
      }
    });
    _destinationFocus.addListener(() {
      if (_destinationFocus.hasFocus) {
        setState(() => _activeField = _ActiveField.destination);
      }
    });
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _originFocus.dispose();
    _destinationFocus.dispose();
    _panelAnim.dispose();
    super.dispose();
  }

  // ── GPS ──────────────────────────────────────────────────────────────────────

  Future<void> _fetchGPS() async {
    setState(() => _isLoadingGps = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permission denied.';
          _isLoadingGps = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _gpsLocation = LatLng(pos.latitude, pos.longitude);
        _originLocation = _gpsLocation;
        _isLoadingGps = false;
      });
      _mapController.move(_gpsLocation!, 13);
    } catch (_) {
      setState(() {
        _gpsLocation = const LatLng(27.7172, 85.3240);
        _originLocation = _gpsLocation;
        _isLoadingGps = false;
      });
    }
  }

  // ── Search / Geocoding ───────────────────────────────────────────────────────

  Future<void> _onSearchChanged(String query) async {
    if (query.length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    final ts = DateTime.now();
    _lastSearch = ts;
    await Future.delayed(const Duration(milliseconds: 400));
    if (_lastSearch != ts || !mounted) return;

    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}&format=json&limit=6&addressdetails=1',
      );
      final resp =
          await http.get(uri, headers: {'User-Agent': 'BijulixEVApp/1.0'});
      if (resp.statusCode == 200) {
        final List data = json.decode(resp.body);
        setState(() {
          _suggestions = data.map((e) {
            final parts = (e['display_name'] as String).split(',');
            return _Place(
              displayName: e['display_name'] as String,
              shortName: parts.first.trim(),
              location: LatLng(
                double.parse(e['lat'] as String),
                double.parse(e['lon'] as String),
              ),
            );
          }).toList();
        });
      }
    } catch (_) {
      // silent
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectPlace(_Place place) {
    setState(() {
      _suggestions = [];
      if (_activeField == _ActiveField.origin) {
        _originLocation = place.location;
        _originController.text = place.shortName;
        _originFocus.unfocus();
        if (_destinationController.text.isEmpty) {
          _destinationFocus.requestFocus();
        }
      } else {
        _destinationLocation = place.location;
        _destinationController.text = place.shortName;
        _destinationFocus.unfocus();
      }
    });
    _tryBuildRoute();
  }

  void _useMyLocation() {
    if (_gpsLocation == null) return;
    setState(() {
      _originLocation = _gpsLocation;
      _originController.text = 'My location';
      _suggestions = [];
    });
    _originFocus.unfocus();
    _tryBuildRoute();
  }

  void _swapOriginDestination() {
    final tmpLoc = _originLocation;
    final tmpText = _originController.text;
    setState(() {
      _originLocation = _destinationLocation;
      _originController.text = _destinationController.text;
      _destinationLocation = tmpLoc;
      _destinationController.text = tmpText;
    });
    _tryBuildRoute();
  }

  void _tryBuildRoute() {
    if (_originLocation != null && _destinationLocation != null) {
      FocusScope.of(context).unfocus();
      _buildRoute();
    }
  }

  // ── Route ─────────────────────────────────────────────────────────────────

  Future<void> _buildRoute() async {
    setState(() {
      _isLoadingRoute = true;
      _routePoints = [];
      _nearbyStations = [];
      _errorMessage = null;
      _showPanel = false;
    });

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_originLocation!.longitude},${_originLocation!.latitude};'
        '${_destinationLocation!.longitude},${_destinationLocation!.latitude}'
        '?overview=full&geometries=geojson',
      );
      final resp = await http.get(url);
      if (resp.statusCode != 200) throw Exception('Route failed');

      final data = json.decode(resp.body);
      if ((data['routes'] as List).isEmpty) throw Exception('No route');

      final coords = data['routes'][0]['geometry']['coordinates'] as List;
      final points =
          coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();

      final stations = await _fetchEVStations(points);

      setState(() {
        _routePoints = points;
        _nearbyStations = stations;
        _isLoadingRoute = false;
        _showPanel = true;
        _showSearch = false;
      });
      _panelAnim.forward(from: 0);

      if (points.isNotEmpty) {
        _mapController.fitBounds(
          LatLngBounds.fromPoints(points),
          options: const FitBoundsOptions(
            padding: EdgeInsets.fromLTRB(40, 120, 40, 340),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingRoute = false;
        _errorMessage = 'Could not build route. Check your connection.';
      });
    }
  }

  // ── EV Stations: Overpass + approved in-app stations ─────────────────────

  Future<List<_RouteStation>> _fetchEVStations(List<LatLng> pts) async {
    if (pts.isEmpty) return [];

    final overpass = await _fetchStationsFromOverpass(pts);
    final approvedInApp = await _fetchApprovedInAppStations(pts);

    final Map<String, _RouteStation> deduped = {};
    void addUnique(_RouteStation s) {
      // Merge by rounded coordinate so same station from two sources appears once.
      final key =
          '${s.location.latitude.toStringAsFixed(5)}_${s.location.longitude.toStringAsFixed(5)}';
      final existing = deduped[key];
      final isApprovedUpgrade =
          existing != null && existing.source == 'osm' && s.source == 'approved';
      if (existing == null || isApprovedUpgrade || s.distanceFromRoute < existing.distanceFromRoute) {
        deduped[key] = s;
      }
    }

    for (final s in overpass) {
      addUnique(s);
    }
    for (final s in approvedInApp) {
      addUnique(s);
    }

    final result = deduped.values.toList();
    result.sort((a, b) => a.distanceAlongRoute.compareTo(b.distanceAlongRoute));
    return result;
  }

  Future<List<_RouteStation>> _fetchStationsFromOverpass(List<LatLng> pts) async {
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLon = pts.first.longitude, maxLon = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    const pad = 0.06;
    minLat -= pad;
    maxLat += pad;
    minLon -= pad;
    maxLon += pad;

    final query = '''
[out:json][timeout:30];
(
  node["amenity"="charging_station"]($minLat,$minLon,$maxLat,$maxLon);
  way["amenity"="charging_station"]($minLat,$minLon,$maxLat,$maxLon);
);
out center;
''';

    try {
      final resp = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: {'data': query},
      );
      if (resp.statusCode != 200) return [];

      final data = json.decode(resp.body) as Map<String, dynamic>;
      final elements = (data['elements'] as List?) ?? const [];

      final List<_RouteStation> result = [];
      for (final el in elements) {
        final lat = _toDouble((el as Map)['lat'] ?? el['center']?['lat']);
        final lon = _toDouble(el['lon'] ?? el['center']?['lon']);
        if (lat == null || lon == null) continue;

        final loc = LatLng(lat, lon);
        final distFromRoute = _minDistToPolyline(loc, pts);
        if (distFromRoute > _maxOffRouteDistanceMetres) continue;

        final tags = (el['tags'] as Map?) ?? {};
        result.add(_RouteStation(
          id: 'osm_${el['id']}',
          name: (tags['name'] ?? tags['operator'] ?? 'EV Charging Station')
              .toString(),
          address: _buildAddress(tags),
          location: loc,
          distanceFromRoute: distFromRoute,
          distanceAlongRoute: _distAlongRoute(loc, pts),
          source: 'osm',
          stationData: null,
        ));
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<List<_RouteStation>> _fetchApprovedInAppStations(List<LatLng> pts) async {
    try {
      final stations = await _stationService.fetchAllStations();
      final List<_RouteStation> result = [];

      for (final st in stations) {
        final lat = _toDouble(st['lat'] ?? st['latitude']);
        final lon = _toDouble(st['lng'] ?? st['longitude']);
        if (lat == null || lon == null) continue;

        final loc = LatLng(lat, lon);
        final distFromRoute = _minDistToPolyline(loc, pts);
        if (distFromRoute > _maxOffRouteDistanceMetres) continue;

        result.add(_RouteStation(
          id: 'app_${st['firestoreId'] ?? st['id'] ?? '${lat}_$lon'}',
          name: (st['name'] ?? 'EV Charging Station').toString(),
          address: (st['address'] ?? 'Approved station').toString(),
          location: loc,
          distanceFromRoute: distFromRoute,
          distanceAlongRoute: _distAlongRoute(loc, pts),
          source: 'approved',
          stationData: st,
        ));
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  String _buildAddress(Map tags) {
    final parts = <String>[
      tags['addr:street'] ?? '',
      tags['addr:city'] ?? '',
    ].where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? 'Along your route' : parts.join(', ');
  }

  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // ── Geometry ──────────────────────────────────────────────────────────────

  double _minDistToPolyline(LatLng p, List<LatLng> poly) {
    double min = double.infinity;
    for (final q in poly) {
      final d = _metres(p, q);
      if (d < min) min = d;
    }
    return min;
  }

  double _distAlongRoute(LatLng p, List<LatLng> poly) {
    double cumulative = 0;
    double best = double.infinity;
    double bestDist = 0;
    for (int i = 0; i < poly.length; i++) {
      final d = _metres(p, poly[i]);
      if (d < best) {
        best = d;
        bestDist = cumulative;
      }
      if (i > 0) cumulative += _metres(poly[i - 1], poly[i]);
    }
    return bestDist / 1000;
  }

  double _metres(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  double _rad(double d) => d * math.pi / 180;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          _buildMap(),
          if (_showSearch || _routePoints.isEmpty) _buildSearchCard(),
          if (!_showSearch && _routePoints.isNotEmpty) _buildRouteHeader(),
          if (_suggestions.isNotEmpty) _buildSuggestions(),
          if (_isLoadingRoute) _buildLoadingOverlay(),
          if (_showPanel) _buildStationPanel(),
          _buildMyLocationFab(),
        ],
      ),
    );
  }

  // ── Map ───────────────────────────────────────────────────────────────────

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: _gpsLocation ?? const LatLng(27.7172, 85.3240),
        zoom: 13,
        onTap: (_, __) {
          FocusScope.of(context).unfocus();
          setState(() => _suggestions = []);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.ev_charging_station',
        ),
        if (_routePoints.isNotEmpty)
          PolylineLayer(polylines: [
            Polyline(
              points: _routePoints,
              color: Colors.green.shade600,
              strokeWidth: 5,
              borderColor: Colors.green.shade900,
              borderStrokeWidth: 1,
            ),
          ]),
        MarkerLayer(markers: [
          if (_originLocation != null)
            Marker(
              point: _originLocation!,
              width: 44,
              height: 44,
              builder: (_) => _mapPin(Colors.blue.shade700, Icons.my_location),
            ),
          if (_destinationLocation != null)
            Marker(
              point: _destinationLocation!,
              width: 44,
              height: 44,
              builder: (_) => _mapPin(Colors.red.shade600, Icons.place),
            ),
          ..._nearbyStations.map((s) => Marker(
                point: s.location,
                width: 40,
                height: 40,
                builder: (_) => GestureDetector(
                  onTap: () => _showStationSheet(s),
                  child:
                      _mapPin(Colors.green.shade500, Icons.ev_station, size: 18),
                ),
              )),
        ]),
      ],
    );
  }

  Widget _mapPin(Color color, IconData icon, {double size = 22}) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.45), blurRadius: 8)],
      ),
      child: Icon(icon, color: Colors.white, size: size),
    );
  }

  // ── Search card (Google Maps style) ──────────────────────────────────────

  Widget _buildSearchCard() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.alt_route,
                          color: Colors.green, size: 22),
                      const SizedBox(width: 8),
                      const Text('Plan Your Trip',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      if (_routePoints.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () =>
                              setState(() => _showSearch = false),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),

                // Origin field
                _searchField(
                  controller: _originController,
                  focusNode: _originFocus,
                  hint: 'Starting point',
                  dotColor: Colors.blue.shade600,
                  onChanged: _onSearchChanged,
                  trailing: _isLoadingGps
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : _originController.text != 'My location'
                          ? GestureDetector(
                              onTap: _useMyLocation,
                              child: const Icon(Icons.gps_fixed,
                                  size: 18, color: Colors.green),
                            )
                          : null,
                ),

                // Divider with swap button
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 1),
                    ),
                    Positioned(
                      right: 18,
                      child: GestureDetector(
                        onTap: _swapOriginDestination,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Icon(Icons.swap_vert,
                              size: 18, color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),

                // Destination field
                _searchField(
                  controller: _destinationController,
                  focusNode: _destinationFocus,
                  hint: 'Where to?',
                  dotColor: Colors.red.shade600,
                  onChanged: _onSearchChanged,
                  trailing: _destinationController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _destinationController.clear();
                            setState(() {
                              _destinationLocation = null;
                              _routePoints = [];
                              _nearbyStations = [];
                              _showPanel = false;
                            });
                          },
                          child: const Icon(Icons.close,
                              size: 18, color: Colors.grey),
                        )
                      : null,
                ),

                // Error
                if (_errorMessage != null)
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(_errorMessage!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                // Search button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.ev_station, size: 18),
                      label: const Text('Find EV Stations Along Route'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            (_originLocation != null &&
                                    _destinationLocation != null)
                                ? Colors.green
                                : Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed:
                          (_originLocation != null &&
                                  _destinationLocation != null)
                              ? _buildRoute
                              : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required Color dotColor,
    required ValueChanged<String> onChanged,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    const TextStyle(color: Colors.grey, fontSize: 15),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  // ── Collapsed route header ────────────────────────────────────────────────

  Widget _buildRouteHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _showSearch = true),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alt_route, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _originController.text,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '→ ${_destinationController.text}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Suggestions dropdown ──────────────────────────────────────────────────

  Widget _buildSuggestions() {
    // Offset below the search card. The card is roughly 200px tall.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 205, 12, 0),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length +
                  (_activeField == _ActiveField.origin ? 1 : 0),
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 52),
              itemBuilder: (_, i) {
                // "Use my location" shortcut for origin field
                if (_activeField == _ActiveField.origin && i == 0) {
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.gps_fixed,
                          size: 18, color: Colors.blue.shade700),
                    ),
                    title: const Text('Use my current location',
                        style:
                            TextStyle(fontWeight: FontWeight.w600)),
                    onTap: _useMyLocation,
                  );
                }
                final place = _suggestions[
                    i - (_activeField == _ActiveField.origin ? 1 : 0)];
                final parts = place.displayName.split(',');
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on,
                        color: Colors.green, size: 18),
                  ),
                  title: Text(place.shortName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600)),
                  subtitle: parts.length > 1
                      ? Text(
                          parts.skip(1).take(2).join(',').trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        )
                      : null,
                  onTap: () => _selectPlace(place),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Loading overlay ───────────────────────────────────────────────────────

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black26,
      child: const Center(
        child: Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16))),
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.green),
                SizedBox(height: 16),
                Text(
                  'Finding route & EV stations…',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Station panel ─────────────────────────────────────────────────────────

  Widget _buildStationPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(_panelSlide),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black26,
                  blurRadius: 18,
                  offset: Offset(0, -4))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.ev_station,
                          color: Colors.green, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_nearbyStations.length} EV Station${_nearbyStations.length != 1 ? 's' : ''} Along Route',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    // Re-open search
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showSearch = true),
                      child: const Icon(Icons.edit,
                          size: 18, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _panelAnim.reverse().then(
                          (_) => setState(() => _showPanel = false)),
                      child: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: _nearbyStations.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.ev_station,
                                size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'No EV stations found within 5 km of this route (including approved in-app stations).',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _nearbyStations.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (_, i) =>
                            _stationTile(_nearbyStations[i], i + 1),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stationTile(_RouteStation s, int index) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: Colors.green.shade50, shape: BoxShape.circle),
            child: const Icon(Icons.ev_station, color: Colors.green),
          ),
          Positioned(
            bottom: -2,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                  color: Colors.green, shape: BoxShape.circle),
              child: Text('$index',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(s.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          const SizedBox(width: 8),
          _sourceBadge(s.source),
        ],
      ),
      subtitle: Text(s.address,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${s.distanceAlongRoute.toStringAsFixed(1)} km',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
                fontSize: 13),
          ),
          const Text('along route',
              style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
      onTap: () => _showStationSheet(s),
    );
  }

  // ── Station detail sheet ──────────────────────────────────────────────────

  void _showStationSheet(_RouteStation s) {
    _mapController.move(s.location, 15);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle),
                  child: const Icon(Icons.ev_station,
                      color: Colors.green, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      Text(s.address,
                          style:
                              const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 6),
                      _sourceBadge(s.source),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _chip(Icons.route,
                    '${s.distanceAlongRoute.toStringAsFixed(1)} km along route'),
                _chip(Icons.near_me,
                    '${(s.distanceFromRoute / 1000).toStringAsFixed(1)} km off route'),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.navigation),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NavigationScreen(
                            start: _originLocation ??
                                const LatLng(27.7172, 85.3240),
                            end: s.location,
                            routePoints: _routePoints,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (s.source == 'approved' && s.stationData != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.book_online),
                      label: const Text('Book slot'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateBookingScreen(
                              station: s.stationData!,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceBadge(String source) {
    final bool isApproved = source == 'approved';
    final Color bg = isApproved ? Colors.green.shade50 : Colors.blue.shade50;
    final Color border = isApproved ? Colors.green.shade200 : Colors.blue.shade200;
    final Color fg = isApproved ? Colors.green.shade700 : Colors.blue.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        isApproved ? 'Approved' : 'OSM',
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.green),
          const SizedBox(width: 6),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: Colors.green)),
        ],
      ),
    );
  }

  // ── My Location FAB ───────────────────────────────────────────────────────

  Widget _buildMyLocationFab() {
    return Positioned(
      right: 14,
      bottom: _showPanel ? 316 : 20,
      child: FloatingActionButton(
        mini: true,
        heroTag: 'locFab',
        backgroundColor: Colors.white,
        elevation: 4,
        onPressed: () {
          if (_gpsLocation != null) _mapController.move(_gpsLocation!, 14);
        },
        child: const Icon(Icons.my_location, color: Colors.green),
      ),
    );
  }
}