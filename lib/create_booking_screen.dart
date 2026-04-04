import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'models/booking_model.dart';
import 'services/booking_service.dart';
import 'config/reward_config.dart';
import 'payment_screen.dart';

class CreateBookingScreen extends StatefulWidget {
  final Map<String, dynamic> station;

  const CreateBookingScreen({
    super.key,
    required this.station,
  });

  @override
  State<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _selectedDuration = 60; // minutes
  int? _selectedConnectorIndex; // Selected connector index
  bool _remindMe = true;
  final TextEditingController _notesController = TextEditingController();
  bool _isCheckingAvailability = false;
  Map<int, bool> _connectorAvailability = {}; // Map of connector index to availability
  List<Map<String, DateTime>> _bookedTimeSlots = []; // Booked time slots for selected connector
  bool _isLoadingTimeSlots = false;
  int _userRewardPoints = 0;
  bool _isLoadingRewardPoints = false;
  bool _useRewardPoints = false;

  final List<int> _durationOptions = [30, 60, 90, 120, 180, 240]; // minutes
  final BookingService _bookingService = BookingService();

  // Get connectors from station data
  List<Map<String, dynamic>> get _connectors {
    final connectors = widget.station['connectors'];
    if (connectors == null) return [];
    if (connectors is List) {
      return List<Map<String, dynamic>>.from(connectors);
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectorAvailability();
      _loadUserRewardPoints();
    });
  }

  Future<void> _loadUserRewardPoints() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingRewardPoints = true;
    });

    try {
      final points = await _bookingService.getUserRewardPoints(user.uid);
      if (!mounted) return;
      setState(() {
        _userRewardPoints = points;
      });
    } catch (_) {
      // Silent fallback to zero points.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRewardPoints = false;
        });
      }
    }
  }

  Future<void> _loadBookedTimeSlots() async {
    if (_selectedConnectorIndex == null) {
      setState(() {
        _bookedTimeSlots = [];
      });
      return;
    }

    setState(() {
      _isLoadingTimeSlots = true;
    });

    try {
      final stationId = widget.station['id'] ?? widget.station['firestoreId'] ?? '';
      final bookedSlots = await _bookingService.getBookedTimeSlots(
        stationId: stationId,
        connectorIndex: _selectedConnectorIndex!,
        date: _selectedDate,
      );

      if (mounted) {
        setState(() {
          _bookedTimeSlots = bookedSlots;
          _isLoadingTimeSlots = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bookedTimeSlots = [];
          _isLoadingTimeSlots = false;
        });
      }
    }
  }

  Future<void> _checkConnectorAvailability() async {
    if (_connectors.isEmpty) return;

    setState(() {
      _isCheckingAvailability = true;
      _connectorAvailability.clear();
    });

    final startTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final endTime = startTime.add(Duration(minutes: _selectedDuration));
    final stationId = widget.station['id'] ?? widget.station['firestoreId'] ?? '';

    final Map<int, bool> availability = {};

    for (int i = 0; i < _connectors.length; i++) {
      try {
        final isAvailable = await _bookingService.isConnectorAvailable(
          stationId: stationId,
          connectorIndex: i,
          startTime: startTime,
          endTime: endTime,
        );
        availability[i] = isAvailable;
      } catch (e) {
        availability[i] = false;
      }
    }

    if (mounted) {
      setState(() {
        _connectorAvailability = availability;
        _isCheckingAvailability = false;
        // Don't clear selection - allow user to select connector even if booked at current time
        // They can choose a different time slot
      });
      
      // Load booked time slots for selected connector
      if (_selectedConnectorIndex != null) {
        await _loadBookedTimeSlots();
      }
    }
  }

  // Check if a time slot is available
  bool _isTimeSlotAvailable(TimeOfDay time) {
    if (_selectedConnectorIndex == null) return false;
    
    final selectedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      time.hour,
      time.minute,
    );
    final selectedEndTime = selectedDateTime.add(Duration(minutes: _selectedDuration));

    for (var slot in _bookedTimeSlots) {
      final bookedStart = slot['start']!;
      final bookedEnd = slot['end']!;
      
      // Check if time slots overlap
      if (selectedDateTime.isBefore(bookedEnd) && bookedStart.isBefore(selectedEndTime)) {
        return false; // Time slot is booked
      }
    }

    // Also check if time is in the past
    if (selectedDateTime.isBefore(DateTime.now())) {
      return false;
    }

    return true;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedConnectorIndex = null; // Reset selection
        _bookedTimeSlots = []; // Clear booked slots
      });
      _checkConnectorAvailability();
    }
  }

  Future<void> _selectTime() async {
    // Show time slot picker with availability
    if (_selectedConnectorIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a connector first to see available time slots'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Ensure booked time slots are loaded
    if (_bookedTimeSlots.isEmpty && !_isLoadingTimeSlots) {
      await _loadBookedTimeSlots();
    }

    await _showTimeSlotPicker();
  }

  Future<void> _showTimeSlotPicker() async {
    // Generate time slots for the day (every 30 minutes from 6 AM to 11 PM)
    final List<TimeOfDay> timeSlots = [];
    for (int hour = 6; hour < 24; hour++) {
      timeSlots.add(TimeOfDay(hour: hour, minute: 0));
      if (hour < 23) {
        timeSlots.add(TimeOfDay(hour: hour, minute: 30));
      }
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Time Slot'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Connector ${_selectedConnectorIndex! + 1} - ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Green = Available, Red = Booked\nSelect a green time slot to book',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                if (_isLoadingTimeSlots)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: timeSlots.map((time) {
                      final isAvailable = _isTimeSlotAvailable(time);
                      final isSelected = _selectedTime.hour == time.hour && 
                                       _selectedTime.minute == time.minute;
                      
                      return InkWell(
                        onTap: isAvailable
                            ? () {
                                setState(() {
                                  _selectedTime = time;
                                });
                                Navigator.pop(context);
                                _checkConnectorAvailability();
                              }
                            : () {
                                // Show why it's not available
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'This time slot (${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}) is already booked. Please select an available time.',
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue
                                : (isAvailable ? Colors.green[100] : Colors.red[100]),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blue
                                  : (isAvailable ? Colors.green : Colors.red),
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : (isAvailable ? Colors.green[900] : Colors.red[900]),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.check, color: Colors.white, size: 14),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  double _calculateBaseAmount() {
    // Simple pricing: Rs 0.25 per minute
    return _selectedDuration * 0.25;
  }

  bool _canRedeem() {
    return _userRewardPoints >= RewardConfig.minRedeemPoints;
  }

  int _pointsToRedeem() {
    return (_useRewardPoints && _canRedeem()) ? RewardConfig.minRedeemPoints : 0;
  }

  double _calculateDiscountAmount() {
    if (!_useRewardPoints || !_canRedeem()) return 0;
    return _calculateBaseAmount() * RewardConfig.redeemDiscountPercent;
  }

  double _calculateAmount() {
    return _calculateBaseAmount() - _calculateDiscountAmount();
  }

  Future<void> _createBooking() async {
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);

    if (authProvider.currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to create a booking'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final startTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Check if the selected time is in the past
    if (startTime.isBefore(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a future time for your booking'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if station is still available for booking
    final bool isAvailable = widget.station['available'] ?? true;
    final String status = widget.station['status'] ?? 'active';
    
    if (!isAvailable || status != 'active') {
      if (!mounted) return;
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

    // Check if a connector is selected
    if (_selectedConnectorIndex == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an available connector'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if selected time slot is still available
    if (!_isTimeSlotAvailable(_selectedTime)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This time slot is no longer available. Please select another time.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get connector details
    final connector = _connectors[_selectedConnectorIndex!];
    final plugType = connector['type'] ?? 'Type 2';
    final maxPower = (connector['power'] ?? 22.0).toDouble();

    final bookingService = BookingService();
    String? bookingId;

    try {
      // Create booking first
      bookingId = await bookingService.createBooking(
        userId: authProvider.currentUser!.uid,
        stationId: widget.station['id'] ?? widget.station['firestoreId'] ?? '',
        stationName: widget.station['name'] ?? 'Unknown Station',
        stationAddress: widget.station['address'] ?? 'Unknown Address',
        stationLatitude: _getLatitude(widget.station),
        stationLongitude: _getLongitude(widget.station),
        plugType: plugType,
        maxPower: maxPower,
        durationMinutes: _selectedDuration,
        amount: _calculateAmount(),
        startTime: startTime,
        connectorIndex: _selectedConnectorIndex!,
        pointsRedeemed: _pointsToRedeem(),
        discountPercent: _useRewardPoints ? RewardConfig.redeemDiscountPercent : 0,
        discountAmount: _calculateDiscountAmount(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (!mounted) return;

      // Fetch the created booking
      final booking = await bookingService.getBookingById(bookingId);
      
      if (booking != null && mounted) {
        // Navigate to payment screen
        final paymentResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentScreen(booking: booking),
          ),
        );

        if (!mounted) return;

        // If payment was successful, pop back to previous screen
        if (paymentResult == true) {
          Navigator.pop(context, true);
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking created but failed to load. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Booking'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.green),
        titleTextStyle: const TextStyle(color: Colors.green, fontSize: 20),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Station Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.ev_station, color: Colors.green[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.station['name'] ?? 'Unknown Station',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.station['address'] ?? 'Unknown Address',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Date Selection
            const Text(
              'Select Date',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.green),
                    const SizedBox(width: 12),
                    Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Time Selection
            Row(
              children: [
                const Text(
                  'Select Time',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_selectedConnectorIndex != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.blue[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Tap to see all available times for Connector ${_selectedConnectorIndex! + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectedConnectorIndex != null ? _selectTime : null,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedConnectorIndex != null
                        ? (_isTimeSlotAvailable(_selectedTime)
                            ? Colors.green
                            : Colors.orange)
                        : Colors.grey[300]!,
                    width: _selectedConnectorIndex != null ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: _selectedConnectorIndex != null
                      ? (_isTimeSlotAvailable(_selectedTime)
                          ? Colors.green[50]
                          : Colors.orange[50])
                      : Colors.grey[100],
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedConnectorIndex != null
                          ? (_isTimeSlotAvailable(_selectedTime)
                              ? Icons.check_circle
                              : Icons.schedule)
                          : Icons.access_time,
                      color: _selectedConnectorIndex != null
                          ? (_isTimeSlotAvailable(_selectedTime)
                              ? Colors.green
                              : Colors.orange)
                          : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedTime.format(context),
                            style: const TextStyle(fontSize: 16),
                          ),
                          if (_selectedConnectorIndex != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _isTimeSlotAvailable(_selectedTime)
                                  ? 'Available at this time'
                                  : 'Booked at this time - Tap to see available slots',
                              style: TextStyle(
                                fontSize: 12,
                                color: _isTimeSlotAvailable(_selectedTime)
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 4),
                            Text(
                              'Select a connector first',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_selectedConnectorIndex != null)
                      Icon(
                        _isTimeSlotAvailable(_selectedTime)
                            ? Icons.check_circle
                            : Icons.arrow_forward_ios,
                        color: _isTimeSlotAvailable(_selectedTime)
                            ? Colors.green
                            : Colors.orange,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
            if (_selectedConnectorIndex != null && _isLoadingTimeSlots)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Loading time slots...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Connector Selection
            const Text(
              'Select Connector',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_connectors.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No connectors available for this station. Please contact the station administrator.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...(_connectors.asMap().entries.map((entry) {
                final index = entry.key;
                final connector = entry.value;
                final isAvailableAtCurrentTime = _connectorAvailability[index] ?? false;
                final isSelected = _selectedConnectorIndex == index;
                final connectorType = connector['type'] ?? 'Type 2';
                final connectorPower = connector['power'] ?? 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                    onTap: () async {
                      // Allow selection even if booked at current time
                      // User can choose a different time slot
                      setState(() {
                        _selectedConnectorIndex = index;
                      });
                      // Load booked time slots to show available times
                      await _loadBookedTimeSlots();
                      // If current time is not available, suggest selecting a time
                      if (!_isTimeSlotAvailable(_selectedTime)) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Connector ${index + 1} is booked at ${_selectedTime.format(context)}. Tap "Select Time" to see available time slots.',
                              ),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.green[50]
                            : Colors.white,
                        border: Border.all(
                          color: isSelected
                              ? Colors.green
                              : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          // Availability indicator (red/green signal)
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isAvailableAtCurrentTime ? Colors.green : Colors.orange,
                            ),
                            child: isAvailableAtCurrentTime
                                ? const Icon(Icons.check, color: Colors.white, size: 14)
                                : const Icon(Icons.schedule, color: Colors.white, size: 14),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Connector ${index + 1}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$connectorType • ${connectorPower.toStringAsFixed(0)} kW',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (!isAvailableAtCurrentTime && !isSelected) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Booked at selected time - Select to see available times',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange[700],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle, color: Colors.green, size: 24)
                          else if (!isAvailableAtCurrentTime)
                            Column(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  color: Colors.orange[700],
                                  size: 20,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Select',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              })),
            if (_isCheckingAvailability)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Checking availability...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Duration Selection
            const Text(
              'Duration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<int>(
                value: _selectedDuration,
                isExpanded: true,
                underline: const SizedBox(),
                items: _durationOptions.map((duration) {
                  final hours = duration ~/ 60;
                  final minutes = duration % 60;
                  String displayText;
                  if (hours > 0 && minutes > 0) {
                    displayText = '${hours}h ${minutes}m';
                  } else if (hours > 0) {
                    displayText = '${hours}h';
                  } else {
                    displayText = '${minutes}m';
                  }
                  return DropdownMenuItem<int>(
                    value: duration,
                    child: Text(displayText),
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedDuration = newValue;
                    });
                    // Reload availability and time slots
                    _checkConnectorAvailability();
                    if (_selectedConnectorIndex != null) {
                      _loadBookedTimeSlots();
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 24),

            // Notes
            const Text(
              'Notes (Optional)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add any special instructions or notes...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.green),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Reminder Toggle
            Row(
              children: [
                const Text(
                  'Remind me before charging',
                  style: TextStyle(fontSize: 16),
                ),
                const Spacer(),
                Switch(
                  value: _remindMe,
                  activeThumbColor: Colors.green,
                  onChanged: (value) {
                    setState(() {
                      _remindMe = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Reward points redemption
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reward Points',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLoadingRewardPoints
                        ? 'Loading your points...'
                        : 'Available points: $_userRewardPoints',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${RewardConfig.minRedeemPoints} points = ${(RewardConfig.redeemDiscountPercent * 100).toInt()}% off',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Use reward points for discount'),
                    subtitle: !_canRedeem()
                        ? const Text('You need at least 100 points to redeem.')
                        : null,
                    value: _useRewardPoints && _canRedeem(),
                    onChanged: _canRedeem()
                        ? (v) {
                            setState(() {
                              _useRewardPoints = v ?? false;
                            });
                          }
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Booking Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Booking Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Date & Time:'),
                      Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year} at ${_selectedTime.format(context)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Connector:'),
                      Text(_selectedConnectorIndex != null
                          ? 'Connector ${_selectedConnectorIndex! + 1} (${_connectors[_selectedConnectorIndex!]['type']} • ${(_connectors[_selectedConnectorIndex!]['power'] ?? 0.0).toStringAsFixed(0)} kW)'
                          : 'Not selected'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Duration:'),
                      Text(_selectedDuration < 60 
                          ? '${_selectedDuration}m' 
                          : '${_selectedDuration ~/ 60}h ${_selectedDuration % 60}m'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Base Amount:'),
                      Text('Rs ${_calculateBaseAmount().toStringAsFixed(2)}'),
                    ],
                  ),
                  if (_calculateDiscountAmount() > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Discount (${(RewardConfig.redeemDiscountPercent * 100).toInt()}%):'),
                        Text(
                          '- Rs ${_calculateDiscountAmount().toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payable Amount:'),
                      Text(
                        'Rs ${_calculateAmount().toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Create Booking Button
            SizedBox(
              width: double.infinity,
              child: Consumer<BookingProvider>(
                builder: (context, bookingProvider, child) {
                  return ElevatedButton(
                    onPressed: bookingProvider.isLoading ? null : _createBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: bookingProvider.isLoading
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
                              Text('Creating Booking...'),
                            ],
                          )
                        : const Text(
                            'Create Booking',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
