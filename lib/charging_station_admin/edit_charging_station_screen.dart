import 'package:flutter/material.dart';
import '../services/charging_station_service.dart';

class EditChargingStationScreen extends StatefulWidget {
  final Map<String, dynamic> station;
  const EditChargingStationScreen({super.key, required this.station});

  @override
  State<EditChargingStationScreen> createState() => _EditChargingStationScreenState();
}

class _EditChargingStationScreenState extends State<EditChargingStationScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _descriptionController;
  late TextEditingController _contactController;
  late TextEditingController _priceController;
  bool _available = true;
  String _status = 'active';
  bool _saving = false;

  final ChargingStationService _service = ChargingStationService();

  @override
  void initState() {
    super.initState();
    final s = widget.station;
    _nameController = TextEditingController(text: s['name'] ?? '');
    _addressController = TextEditingController(text: s['address'] ?? '');
    _descriptionController = TextEditingController(text: s['description'] ?? '');
    _contactController = TextEditingController(text: s['contact'] ?? '');
    _priceController = TextEditingController(text: (s['price'] ?? 0).toString());
    _available = s['available'] ?? true;
    _status = s['status'] ?? 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // Use firestoreId (the actual document ID) for updates
      final id = widget.station['firestoreId'] ?? widget.station['id'];
      final updateData = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'description': _descriptionController.text.trim(),
        'contact': _contactController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'available': _available,
        'status': _status,
        // Don't include ownerId in update - security rules check existing document's ownerId
      };
      
      await _service.updateStation(id, updateData);
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        // Show more detailed error message
        String errorMessage = 'Error saving changes';
        if (e.toString().contains('PERMISSION_DENIED')) {
          errorMessage = 'Permission denied. You may not have permission to update this station.';
        } else if (e.toString().contains('NOT_FOUND')) {
          errorMessage = 'Station not found. It may have been deleted.';
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Charging Station'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Station Name', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactController,
              decoration: const InputDecoration(labelText: 'Contact', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Price per kWh', border: OutlineInputBorder(), prefixText: 'Rs '),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter a valid number' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                DropdownMenuItem(value: 'maintenance', child: Text('Under Maintenance')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'active'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Available'),
              value: _available,
              onChanged: (v) => setState(() => _available = v),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: _saving ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}


