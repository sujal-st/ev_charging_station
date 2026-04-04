import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'services/charging_station_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class AddChargingStationScreen extends StatefulWidget {
  const AddChargingStationScreen({super.key});

  @override
  State<AddChargingStationScreen> createState() =>
      _AddChargingStationScreenState();
}

class _AddChargingStationScreenState extends State<AddChargingStationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();
  final _parkingSpacesController = TextEditingController();
  final _priceController = TextEditingController();
  final _businessRegistrationController = TextEditingController();
  
  // Photo upload
  File? _stationPhoto;
  final ImagePicker _imagePicker = ImagePicker();

  // Map and location related variables
  late MapController _mapController;
  LatLng? _selectedLocation; // Will be set when user taps on map
  Position? _currentPosition;
  List<Marker> _markers = [];

  // Charging station details
  bool _hasParkingAvailable = false;
  bool _isParkingPaid = false;
  String _selectedStatus = 'active';
  bool _isAvailable = true;

  // Connector related variables
  final List<Map<String, dynamic>> _connectors = [];
  final _connectorPowerController = TextEditingController();
  final String _selectedConnectorType = 'Type 2';
  final List<String> _connectorTypes = [
    'Type 1',
    'Type 2',
    'CCS',
    'CHAdeMO',
    'Tesla',
  ];

  bool _isLoading = false;
  final ChargingStationService _stationService = ChargingStationService();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    _parkingSpacesController.dispose();
    _connectorPowerController.dispose();
    _priceController.dispose();
    _businessRegistrationController.dispose();
    super.dispose();
  }
  
  Future<void> _pickStationPhoto() async {
    try {
      // Request permission for Android
      if (Platform.isAndroid) {
        PermissionStatus status;
        // Try photos permission first (Android 13+)
        try {
          status = await Permission.photos.request();
        } catch (e) {
          // Fallback to storage permission for older Android versions
          status = await Permission.storage.request();
        }
        
        if (status.isDenied) {
          // Request again if denied
          status = await Permission.photos.request();
          if (status.isDenied) {
            status = await Permission.storage.request();
          }
        }
        
        if (status.isPermanentlyDenied) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Permission Required'),
                content: const Text('Gallery permission is required to select photos. Please enable it in app settings.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      openAppSettings();
                    },
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            );
          }
          return;
        }
        
        if (status.isDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gallery permission is required to select photos'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }
      
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null && mounted) {
        setState(() {
          _stationPhoto = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  Future<void> _takeStationPhoto() async {
    try {
      // Request camera permission
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.camera.request();
        
        if (status.isDenied || status.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Camera permission is required to take photos'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }
      
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null && mounted) {
        setState(() {
          _stationPhoto = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickStationPhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takeStationPhoto();
                },
              ),
              if (_stationPhoto != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _stationPhoto = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied'),
          ),
        );
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _markers = [
          Marker(
            point: _selectedLocation!,
            width: 40,
            height: 40,
            builder: (context) => const Icon(
              Icons.location_on,
              color: Colors.red,
              size: 40,
            ),
          ),
        ];

        // Move map to current location
        _mapController.move(_selectedLocation!, 15.0);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  void _addConnector() {
    setState(() {
      _connectors.add({
        'type': _selectedConnectorType,
        'power': 0.0,
      });
    });
  }

  void _removeConnector(int index) {
    setState(() {
      _connectors.removeAt(index);
    });
  }

  Future<void> _saveChargingStation() async {
    // Validate connectors have power values
    bool hasInvalidConnector = false;
    for (var connector in _connectors) {
      final power = connector['power'] as double?;
      if (power == null || power <= 0) {
        hasInvalidConnector = true;
        break;
      }
    }
    
    if (hasInvalidConnector) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter power rating for all connectors'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_formKey.currentState!.validate()) {
      // Check if at least one connector is added
      if (_connectors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one connector'),
          ),
        );
        return;
      }
      
      // Check if photo is uploaded
      if (_stationPhoto == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload a photo of the charging station'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Check if location is selected
      if (_selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a location on the map'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You must be logged in to add a station'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Create charging station data
        final uuid = Uuid();
        final stationId = uuid.v4();
        
        // Upload photo to ImgBB and get URL
        String? photoUrl; // Contains ImgBB image URL
        try {
          if (_stationPhoto != null) {
            photoUrl = await _stationService.uploadStationPhoto(_stationPhoto!, stationId);
          }
        } catch (photoError) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload photo: $photoError'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }
        
        // Prepare data to be sent to backend
        // Ensure connectors have proper structure
        final connectorsData = _connectors.map((connector) {
          return {
            'type': connector['type'] ?? 'Type 2',
            'power': (connector['power'] as num?)?.toDouble() ?? 0.0,
            'maxPower': (connector['power'] as num?)?.toDouble() ?? 0.0,
          };
        }).toList();
        
        Map<String, dynamic> stationData = {
          'id': stationId,
          'name': _nameController.text.trim(),
          'address': _addressController.text.trim(),
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
          'lat': _selectedLocation!.latitude,
          'lng': _selectedLocation!.longitude,
          'plug_type': _connectors.map((c) => c['type']?.toString() ?? 'Type 2').join(', '),
          'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
          'available': _isAvailable,
          'status': _selectedStatus,
          'created_at': DateTime.now().toIso8601String(),
          'description': _descriptionController.text.trim(),
          'contact': _contactController.text.trim(),
          'ownerId': user.uid,
          'parking': {
            'available': _hasParkingAvailable,
            'paid': _isParkingPaid,
            'spaces': int.tryParse(_parkingSpacesController.text.trim()) ?? 0,
          },
          'connectors': connectorsData,
          'businessRegistrationNumber': _businessRegistrationController.text.trim(),
          'stationPhotoUrl': photoUrl ?? '',
          'verificationStatus': 'pending', // New stations require verification
        };

        // Save to Firestore
        try {
          final firestoreId = await _stationService.addStation(stationData);
          stationData['firestoreId'] = firestoreId;
        } catch (firestoreError) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to save station: $firestoreError'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }

        // Optionally mirror locally
        final prefs = await SharedPreferences.getInstance();
        final savedStations = prefs.getStringList('charging_stations') ?? [];
        savedStations.add(jsonEncode(stationData));
        await prefs.setStringList('charging_stations', savedStations);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Charging station added successfully. It will be reviewed before being published.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );

          // Navigate back with success indicator
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          String errorMessage = 'Error saving charging station';
          if (e.toString().contains('PERMISSION_DENIED')) {
            errorMessage = 'Permission denied. You may not have permission to create stations.';
          } else if (e.toString().contains('network') || e.toString().contains('connection')) {
            errorMessage = 'Network error. Please check your internet connection and try again.';
          } else {
            errorMessage = 'Error: ${e.toString()}';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Charging Station'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Station Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Station Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter station name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Address
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Contact Information
                    TextFormField(
                      controller: _contactController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Information',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Business Registration Number
                    TextFormField(
                      controller: _businessRegistrationController,
                      decoration: const InputDecoration(
                        labelText: 'Business Registration Number *',
                        border: OutlineInputBorder(),
                        helperText: 'Required for verification',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter business registration number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Station Photo Upload
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Station Photo *',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Upload a clear photo of your charging station for verification',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_stationPhoto != null) ...[
                              Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _stationPhoto!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            ElevatedButton.icon(
                              onPressed: _showPhotoOptions,
                              icon: Icon(_stationPhoto == null ? Icons.add_photo_alternate : Icons.change_circle),
                              label: Text(_stationPhoto == null ? 'Upload Station Photo' : 'Change Photo'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Price per kWh
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price per kWh',
                        border: OutlineInputBorder(),
                        prefixText: 'Rs ',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter price';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Status and Availability
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Status and Availability',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Status dropdown
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: _selectedStatus,
                              items: const [
                                DropdownMenuItem(
                                    value: 'active', child: Text('Active')),
                                DropdownMenuItem(
                                    value: 'inactive', child: Text('Inactive')),
                                DropdownMenuItem(
                                    value: 'maintenance',
                                    child: Text('Under Maintenance')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedStatus = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // Availability switch
                            SwitchListTile(
                              title: const Text('Station Available'),
                              value: _isAvailable,
                              onChanged: (value) {
                                setState(() {
                                  _isAvailable = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Parking Information
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Parking Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Parking availability switch
                            SwitchListTile(
                              title: const Text('Parking Available'),
                              value: _hasParkingAvailable,
                              onChanged: (value) {
                                setState(() {
                                  _hasParkingAvailable = value;
                                });
                              },
                            ),

                            // Paid parking switch (only if parking is available)
                            if (_hasParkingAvailable)
                              SwitchListTile(
                                title: const Text('Paid Parking'),
                                value: _isParkingPaid,
                                onChanged: (value) {
                                  setState(() {
                                    _isParkingPaid = value;
                                  });
                                },
                              ),

                            // Number of parking spaces (only if parking is available)
                            if (_hasParkingAvailable) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _parkingSpacesController,
                                decoration: const InputDecoration(
                                  labelText: 'Number of Parking Spaces',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (_hasParkingAvailable &&
                                      (value == null || value.isEmpty)) {
                                    return 'Please enter number of parking spaces';
                                  }
                                  if (value != null &&
                                      value.isNotEmpty &&
                                      int.tryParse(value) == null) {
                                    return 'Please enter a valid number';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Charging Connectors
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Charging Connectors',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _addConnector,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // List of connectors
                            ..._connectors.asMap().entries.map((entry) {
                              final index = entry.key;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Connector ${index + 1}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _removeConnector(index),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Connector type dropdown
                                      DropdownButtonFormField<String>(
                                        decoration: const InputDecoration(
                                          labelText: 'Connector Type',
                                          border: OutlineInputBorder(),
                                        ),
                                        initialValue: _connectors[index]['type']
                                            as String,
                                        items: _connectorTypes.map((type) {
                                          return DropdownMenuItem(
                                            value: type,
                                            child: Text(type),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _connectors[index]['type'] = value!;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 16),

                                      // Power rating
                                      TextFormField(
                                        key: ValueKey('power_${index}_${_connectors[index]['power']}'),
                                        initialValue: (_connectors[index]['power'] as num?)?.toString() ?? '',
                                        decoration: const InputDecoration(
                                          labelText: 'Power (kW) *',
                                          border: OutlineInputBorder(),
                                          helperText: 'Required',
                                        ),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (value) {
                                          final powerValue = double.tryParse(value);
                                          if (powerValue != null && powerValue > 0) {
                                            _connectors[index]['power'] = powerValue;
                                          } else {
                                            _connectors[index]['power'] = 0.0;
                                          }
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter power rating';
                                          }
                                          final powerValue = double.tryParse(value);
                                          if (powerValue == null) {
                                            return 'Please enter a valid number';
                                          }
                                          if (powerValue <= 0) {
                                            return 'Power must be greater than 0';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),

                            if (_connectors.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text(
                                    'No connectors added yet. Add at least one connector.',
                                    style:
                                        TextStyle(fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location on Map
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Location on Map',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap on the map to select the charging station location',
                              style: TextStyle(fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(height: 16),

                            // Map container
                            Container(
                              height: 300,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    center: _selectedLocation ??
                                        const LatLng(27.7172,
                                            85.3240), // Default to Kathmandu
                                    zoom: 15.0,
                                    onTap: (tapPosition, point) {
                                      setState(() {
                                        _selectedLocation = point;
                                        _markers = [
                                          Marker(
                                            point: point,
                                            width: 80,
                                            height: 80,
                                            builder: (context) => const Icon(
                                              Icons.location_on,
                                              color: Colors.red,
                                              size: 40,
                                            ),
                                          ),
                                        ];
                                      });
                                    },
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      subdomains: const ['a', 'b', 'c'],
                                    ),
                                    MarkerLayer(markers: _markers),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Location coordinates display
                            if (_selectedLocation != null) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      readOnly: true,
                                      initialValue: _selectedLocation!.latitude
                                          .toStringAsFixed(6),
                                      decoration: const InputDecoration(
                                        labelText: 'Latitude',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      readOnly: true,
                                      initialValue: _selectedLocation!.longitude
                                          .toStringAsFixed(6),
                                      decoration: const InputDecoration(
                                        labelText: 'Longitude',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else
                              const Center(
                                child: Text(
                                  'Please select a location on the map',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),

                            const SizedBox(height: 16),

                            // Current location button
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: _getCurrentLocation,
                                icon: const Icon(Icons.my_location),
                                label: const Text('Use Current Location'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Submit Charging Station',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_isLoading)
                              const Center(child: CircularProgressIndicator())
                            else
                              ElevatedButton(
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    if (_selectedLocation == null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Please select a location on the map'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    if (_connectors.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Please add at least one connector'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    _saveChargingStation();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'SAVE CHARGING STATION',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            if (!_isLoading)
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'All fields marked with * are required',
                                  style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
