import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AdminStationsMapScreen extends StatelessWidget {
  final List<Map<String, dynamic>> stations;
  const AdminStationsMapScreen({super.key, required this.stations});

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    for (final s in stations) {
      final lat = (s['lat'] ?? s['latitude']) as num? ?? 27.7172;
      final lng = (s['lng'] ?? s['longitude']) as num? ?? 85.3240;
      markers.add(
        Marker(
          point: LatLng(lat.toDouble(), lng.toDouble()),
          width: 120,
          height: 80,
          builder: (context) => Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]),
                child: Text(s['name'] ?? '', style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: (s['available'] == true && (s['status'] ?? 'active') == 'active') ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.ev_station, color: Colors.white, size: 24),
              ),
            ],
          ),
        ),
      );
    }

    final initialCenter = stations.isNotEmpty
        ? LatLng(
            ((stations.first['lat'] ?? stations.first['latitude']) as num? ?? 27.7172).toDouble(),
            ((stations.first['lng'] ?? stations.first['longitude']) as num? ?? 85.3240).toDouble(),
          )
        : const LatLng(27.7172, 85.3240);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Charging Stations Map'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        options: MapOptions(
          center: initialCenter,
          zoom: 13,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.ev_charging_station',
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}


