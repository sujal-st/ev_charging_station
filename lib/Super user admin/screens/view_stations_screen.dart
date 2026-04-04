import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/super_admin_service.dart';
import '../../models/user_model.dart';

class ViewStationsScreen extends StatefulWidget {
  final UserModel admin;

  const ViewStationsScreen({
    super.key,
    required this.admin,
  });

  @override
  State<ViewStationsScreen> createState() => _ViewStationsScreenState();
}

class _ViewStationsScreenState extends State<ViewStationsScreen> {
  final SuperAdminService _superAdminService = SuperAdminService();
  List<Map<String, dynamic>> _stations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stations = await _superAdminService.getStationsByUser(widget.admin.uid);
      if (mounted) {
        setState(() {
          _stations = stations;
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
            content: Text('Failed to load stations: $e'),
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
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'N/A';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stations - ${widget.admin.name}'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.ev_station_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No stations found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStations,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _stations.length,
                    itemBuilder: (context, index) {
                      final station = _stations[index];
                      return _buildStationCard(station);
                    },
                  ),
                ),
    );
  }

  Widget _buildStationCard(Map<String, dynamic> station) {
    final status = station['status'] ?? 'active';
    final statusColor = _getStatusColor(status);
    final connectors = station['connectors'];
    final connectorsList = connectors is List ? connectors : [];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    station['name'] ?? 'Unnamed Station',
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
            
            // Address
            if (station['address'] != null && station['address'].toString().isNotEmpty)
              _buildInfoRow(Icons.location_on, station['address']),
            
            // Contact
            if (station['contact'] != null && station['contact'].toString().isNotEmpty)
              _buildInfoRow(Icons.phone, station['contact']),
            
            // Price
            _buildInfoRow(
              Icons.attach_money,
              'Rs. ${station['price']?.toStringAsFixed(2) ?? '0.00'} per kWh',
            ),
            
            // Power Output
            if (station['powerOutput'] != null && (station['powerOutput'] as num) > 0)
              _buildInfoRow(
                Icons.flash_on,
                '${station['powerOutput']} kW',
              ),
            
            // Connectors
            if (connectorsList.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Connectors:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ...connectorsList.map((connector) {
                final connectorData = connector is Map ? connector : {};
                return Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.power, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '${connectorData['type'] ?? 'Unknown'} - ${connectorData['maxPower'] ?? 'N/A'} kW',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ] else if (station['connectorsCount'] != null && station['connectorsCount'] > 0)
              _buildInfoRow(
                Icons.power,
                '${station['connectorsCount']} connector(s)',
              ),
            
            // Availability
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  station['available'] == true ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: station['available'] == true ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  station['available'] == true ? 'Available' : 'Unavailable',
                  style: TextStyle(
                    fontSize: 12,
                    color: station['available'] == true ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            
            // Description
            if (station['description'] != null && station['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Description:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                station['description'],
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
            
            // Amenities
            if (station['amenities'] != null && 
                station['amenities'] is List && 
                (station['amenities'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Amenities:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (station['amenities'] as List).map((amenity) {
                  return Chip(
                    label: Text(amenity.toString()),
                    backgroundColor: Colors.green[50],
                    labelStyle: const TextStyle(fontSize: 12),
                  );
                }).toList(),
              ),
            ],
            
            // Parking
            if (station['parking'] == true) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.local_parking, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    'Parking Available',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            
            // Rating
            if (station['rating'] != null && (station['rating'] as num) > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    '${station['rating']} (${station['totalReviews'] ?? 0} reviews)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
            
            // Created/Updated dates
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (station['createdAt'] != null)
                  Text(
                    'Created: ${_formatTimestamp(station['createdAt'])}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                if (station['updatedAt'] != null)
                  Text(
                    'Updated: ${_formatTimestamp(station['updatedAt'])}',
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

