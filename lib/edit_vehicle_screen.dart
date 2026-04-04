import 'package:flutter/material.dart';
import 'models/vehicle_model.dart';
import 'services/vehicle_service.dart';

class EditVehicleScreen extends StatefulWidget {
  final VehicleModel vehicle;

  const EditVehicleScreen({super.key, required this.vehicle});

  @override
  State<EditVehicleScreen> createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends State<EditVehicleScreen> {
  final VehicleService _vehicleService = VehicleService();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _trimController;
  late TextEditingController _batteryCapacityController;
  late TextEditingController _licensePlateController;
  late TextEditingController _colorController;
  late TextEditingController _yearController;
  late TextEditingController _vinController;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _brandController = TextEditingController(text: widget.vehicle.brand);
    _modelController = TextEditingController(text: widget.vehicle.model);
    _trimController = TextEditingController(text: widget.vehicle.trim);
    _batteryCapacityController = TextEditingController(text: widget.vehicle.batteryCapacity);
    _licensePlateController = TextEditingController(text: widget.vehicle.licensePlate ?? '');
    _colorController = TextEditingController(text: widget.vehicle.color ?? '');
    _yearController = TextEditingController(text: widget.vehicle.year?.toString() ?? '');
    _vinController = TextEditingController(text: widget.vehicle.vin ?? '');
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _trimController.dispose();
    _batteryCapacityController.dispose();
    _licensePlateController.dispose();
    _colorController.dispose();
    _yearController.dispose();
    _vinController.dispose();
    super.dispose();
  }

  Future<void> _updateVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _vehicleService.updateVehicle(
        vehicleId: widget.vehicle.vehicleId,
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        trim: _trimController.text.trim(),
        batteryCapacity: _batteryCapacityController.text.trim(),
        licensePlate: _licensePlateController.text.trim().isEmpty 
            ? null 
            : _licensePlateController.text.trim(),
        color: _colorController.text.trim().isEmpty 
            ? null 
            : _colorController.text.trim(),
        year: _yearController.text.trim().isEmpty 
            ? null 
            : int.tryParse(_yearController.text.trim()),
        vin: _vinController.text.trim().isEmpty 
            ? null 
            : _vinController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehicle updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update vehicle: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Edit Vehicle',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.black,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _updateVehicle,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Basic Information Section
              const Text(
                'Basic Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Brand
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(
                  labelText: 'Brand *',
                  hintText: 'e.g., Tesla, BMW',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Brand is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Model
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model *',
                  hintText: 'e.g., Model 3, i3',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Model is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Trim
              TextFormField(
                controller: _trimController,
                decoration: const InputDecoration(
                  labelText: 'Trim *',
                  hintText: 'e.g., Long Range, Performance',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Trim is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Battery Capacity
              TextFormField(
                controller: _batteryCapacityController,
                decoration: const InputDecoration(
                  labelText: 'Battery Capacity',
                  hintText: 'e.g., 75 kWh',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Additional Information Section
              const Text(
                'Additional Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // License Plate
              TextFormField(
                controller: _licensePlateController,
                decoration: const InputDecoration(
                  labelText: 'License Plate',
                  hintText: 'e.g., ABC-1234',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Color
              TextFormField(
                controller: _colorController,
                decoration: const InputDecoration(
                  labelText: 'Color',
                  hintText: 'e.g., Red, Blue, White',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Year
              TextFormField(
                controller: _yearController,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  hintText: 'e.g., 2023',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final year = int.tryParse(value.trim());
                    if (year == null || year < 1900 || year > DateTime.now().year + 1) {
                      return 'Please enter a valid year';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // VIN
              TextFormField(
                controller: _vinController,
                decoration: const InputDecoration(
                  labelText: 'VIN (Vehicle Identification Number)',
                  hintText: '17-character VIN',
                  border: OutlineInputBorder(),
                ),
                maxLength: 17,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (value.trim().length != 17) {
                      return 'VIN must be 17 characters';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateVehicle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Update Vehicle',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
