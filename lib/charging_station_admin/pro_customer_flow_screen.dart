import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/booking_model.dart';
import '../providers/auth_provider.dart' as app_auth;
import 'services/station_admin_service.dart';
import 'subscription_plan_screen.dart';

class ProCustomerFlowScreen extends StatefulWidget {
  const ProCustomerFlowScreen({super.key});

  @override
  State<ProCustomerFlowScreen> createState() => _ProCustomerFlowScreenState();
}

class _ProCustomerFlowScreenState extends State<ProCustomerFlowScreen> {
  final StationAdminService _adminService = StationAdminService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<BookingModel>>? _bookingsFuture;
  RangeValues _timeRange = const RangeValues(6, 21);

  @override
  void initState() {
    super.initState();
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _bookingsFuture = _adminService.getAllOwnerBookings(currentUser.uid);
    }
  }

  Future<void> _reloadBookings() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return;
    }

    setState(() {
      _bookingsFuture = _adminService.getAllOwnerBookings(currentUser.uid);
    });

    await _bookingsFuture;
  }

  bool _hasProAccess(app_auth.AuthProvider authProvider) {
    final tier = authProvider.subscriptionTier.trim().toLowerCase();
    final status = authProvider.subscriptionStatus.trim().toLowerCase();
    return tier == 'pro' && (status == 'active' || status == 'live');
  }

  List<BookingModel> _activeBookings(List<BookingModel> bookings) {
    return bookings.where((booking) => booking.status != 'cancelled').toList();
  }

  List<int> _buildHourlyCounts(List<BookingModel> bookings) {
    final counts = List<int>.filled(24, 0);
    for (final booking in bookings) {
      if (booking.status == 'cancelled') {
        continue;
      }
      counts[booking.startTime.hour] += 1;
    }
    return counts;
  }

  List<List<int>> _buildHeatMapCounts(List<BookingModel> bookings) {
    final counts = List.generate(7, (_) => List<int>.filled(24, 0));
    for (final booking in bookings) {
      if (booking.status == 'cancelled') {
        continue;
      }
      final dayIndex = booking.startTime.weekday - 1;
      final hourIndex = booking.startTime.hour;
      counts[dayIndex][hourIndex] += 1;
    }
    return counts;
  }

  int _selectedStartHour() => _timeRange.start.round().clamp(0, 23);

  int _selectedEndHour() => _timeRange.end.round().clamp(0, 23);

  List<int> _selectedWindowCounts(List<int> hourlyCounts) {
    final startHour = _selectedStartHour();
    final endHour = _selectedEndHour();
    return [
      for (int hour = startHour; hour <= endHour; hour++) hourlyCounts[hour]
    ];
  }

  int _totalCustomersForRange(List<int> hourlyCounts) {
    return _selectedWindowCounts(hourlyCounts)
        .fold<int>(0, (sum, count) => sum + count);
  }

  int _peakHour(List<int> hourlyCounts) {
    var peakHour = 0;
    var peakCount = -1;
    for (var hour = 0; hour < hourlyCounts.length; hour++) {
      final count = hourlyCounts[hour];
      if (count > peakCount) {
        peakCount = count;
        peakHour = hour;
      }
    }
    return peakHour;
  }

  int _peakDay(List<List<int>> heatMapCounts) {
    var peakDay = 0;
    var peakCount = -1;
    for (var day = 0; day < heatMapCounts.length; day++) {
      final dayCount =
          heatMapCounts[day].fold<int>(0, (sum, count) => sum + count);
      if (dayCount > peakCount) {
        peakCount = dayCount;
        peakDay = day;
      }
    }
    return peakDay;
  }

  int _maxHeatMapCount(List<List<int>> heatMapCounts) {
    var maxCount = 0;
    for (final row in heatMapCounts) {
      for (final count in row) {
        if (count > maxCount) {
          maxCount = count;
        }
      }
    }
    return math.max(1, maxCount);
  }

  int _maxCount(List<int> values) {
    var maxCount = 0;
    for (final value in values) {
      if (value > maxCount) {
        maxCount = value;
      }
    }
    return maxCount;
  }

  String _formatHour(int hour) {
    final normalizedHour = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12 ? 'AM' : 'PM';
    return '$normalizedHour$period';
  }

  String _dayLabel(int index) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[index];
  }

  Color _heatMapColor(int count, int maxCount) {
    final normalized = count / maxCount;
    return Color.lerp(
      Colors.green.shade50,
      Colors.green.shade800,
      normalized,
    )!;
  }

  String _customerLabel(int count) {
    return count == 1 ? '1 customer' : '$count customers';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<app_auth.AuthProvider>(
      builder: (context, authProvider, child) {
        final hasProAccess = _hasProAccess(authProvider);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Customer Flow Analytics'),
          ),
          body: hasProAccess ? _buildProView() : _buildLockedView(context),
        );
      },
    );
  }

  Widget _buildLockedView(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline,
                size: 40,
                color: Colors.deepOrange.shade700,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pro analytics are locked',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Upgrade your station admin account to Pro to view customer-flow heat maps and custom time-range bar charts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SubscriptionPlanScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.workspace_premium),
                label: const Text('View Subscription Plan'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProView() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(
        child: Text('User not authenticated.'),
      );
    }

    final bookingsFuture =
        _bookingsFuture ?? _adminService.getAllOwnerBookings(currentUser.uid);

    return FutureBuilder<List<BookingModel>>(
      future: bookingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade400, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load analytics',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _reloadBookings,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final bookings = _activeBookings(snapshot.data ?? const []);
        final hourlyCounts = _buildHourlyCounts(bookings);
        final heatMapCounts = _buildHeatMapCounts(bookings);
        final peakHour = _peakHour(hourlyCounts);
        final peakDay = _peakDay(heatMapCounts);
        final maxHeatMapCount = _maxHeatMapCount(heatMapCounts);
        final selectedStartHour = _selectedStartHour();
        final selectedEndHour = _selectedEndHour();
        final selectedCounts = _selectedWindowCounts(hourlyCounts);
        final totalCustomers = _totalCustomersForRange(hourlyCounts);
        final peakWindowCount =
            selectedCounts.isEmpty ? 0 : _maxCount(selectedCounts);
        final peakWindowHour = selectedCounts.isEmpty
            ? selectedStartHour
            : selectedStartHour + selectedCounts.indexOf(peakWindowCount);

        return RefreshIndicator(
          onRefresh: _reloadBookings,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(
                  totalCustomers: bookings.length,
                  peakHour: peakHour,
                  peakDay: peakDay,
                ),
                const SizedBox(height: 16),
                if (bookings.isEmpty)
                  _buildEmptyState()
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeatMapSection(heatMapCounts, maxHeatMapCount),
                      const SizedBox(height: 16),
                      _buildTimeWindowChart(
                        hourlyCounts: hourlyCounts,
                        selectedCounts: selectedCounts,
                        totalCustomers: totalCustomers,
                        selectedStartHour: selectedStartHour,
                        selectedEndHour: selectedEndHour,
                        peakWindowHour: peakWindowHour,
                        peakWindowCount: peakWindowCount,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard({
    required int totalCustomers,
    required int peakHour,
    required int peakDay,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pro Customer Flow',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track peak hour flow and time-based customer volume across your stations.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _valueChip('Total customers', totalCustomers.toString()),
              _valueChip('Peak hour', _formatHour(peakHour)),
              _valueChip('Busiest day', _dayLabel(peakDay)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valueChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No customer activity yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'The heat map and bar chart will populate as bookings are created for your stations.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatMapSection(
      List<List<int>> heatMapCounts, int maxHeatMapCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Peak hour heat map',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Darker cells indicate higher booking density by day and hour.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 52),
                    ...List.generate(24, (hour) {
                      return SizedBox(
                        width: 24,
                        child: Text(
                          hour % 3 == 0 ? hour.toString().padLeft(2, '0') : '',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(7, (dayIndex) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            _dayLabel(dayIndex),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...List.generate(24, (hourIndex) {
                          final count = heatMapCounts[dayIndex][hourIndex];
                          return Tooltip(
                            message:
                                '${_dayLabel(dayIndex)} ${_formatHour(hourIndex)}: ${_customerLabel(count)}',
                            child: Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: _heatMapColor(count, maxHeatMapCount),
                                borderRadius: BorderRadius.circular(5),
                                border:
                                    Border.all(color: Colors.white, width: 0.5),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Low',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.green.shade800],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('High',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeWindowChart({
    required List<int> hourlyCounts,
    required List<int> selectedCounts,
    required int totalCustomers,
    required int selectedStartHour,
    required int selectedEndHour,
    required int peakWindowHour,
    required int peakWindowCount,
  }) {
    final maxSelectedCount = math.max(1, _maxCount(selectedCounts));
    final chartHours = [
      for (int hour = selectedStartHour; hour <= selectedEndHour; hour++) hour
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer volume by selected time',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Adjust the time window to see how many customers arrived in that period.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),
          RangeSlider(
            values: _timeRange,
            min: 0,
            max: 23,
            divisions: 23,
            labels: RangeLabels(
              _formatHour(selectedStartHour),
              _formatHour(selectedEndHour),
            ),
            onChanged: (values) {
              setState(() {
                _timeRange = values;
              });
            },
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricChip('Window',
                  '${_formatHour(selectedStartHour)} - ${_formatHour(selectedEndHour)}'),
              _metricChip('Customers', totalCustomers.toString()),
              _metricChip('Peak hour in window', _formatHour(peakWindowHour)),
              _metricChip('Peak count', peakWindowCount.toString()),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(360.0, chartHours.length * 54.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 220,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(chartHours.length, (index) {
                        final hour = chartHours[index];
                        final count = hourlyCounts[hour];
                        final barHeight = 16 + (count / maxSelectedCount) * 160;
                        return SizedBox(
                          width: 48,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                count.toString(),
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 24,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green.shade300,
                                      Colors.green.shade800
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatHour(hour),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: Colors.green.shade800,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
