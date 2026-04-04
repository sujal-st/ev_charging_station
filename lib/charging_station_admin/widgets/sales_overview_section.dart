import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/station_admin_service.dart';
import 'sales_info_card.dart';

class SalesOverviewSection extends StatefulWidget {
  const SalesOverviewSection({super.key});

  @override
  State<SalesOverviewSection> createState() => _SalesOverviewSectionState();
}

class _SalesOverviewSectionState extends State<SalesOverviewSection> {
  final StationAdminService _adminService = StationAdminService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic> _salesStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSalesStats();
  }

  Future<void> _loadSalesStats() async {
    if (!mounted) return;

    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final stats = await _adminService.getOwnerSalesStatistics(user.uid);
      if (!mounted) return;
      setState(() {
        _salesStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load sales data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatCurrency(double amount) {
    return 'Rs ${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sales & Revenue',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadSalesStats,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Total Revenue Card (Large)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[400]!, Colors.green[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Revenue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatCurrency(_salesStats['totalRevenue'] ?? 0.0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_salesStats['totalTransactions'] ?? 0} confirmed transactions',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Time-based Revenue Cards
            const Text(
              'Revenue by Period',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 16) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: SalesInfoCard(
                        title: 'Today',
                        value: _formatCurrency(_salesStats['todayRevenue'] ?? 0.0),
                        icon: Icons.today,
                        color: Colors.blue,
                        subtitle: '${_salesStats['todayTransactions'] ?? 0} transactions',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: SalesInfoCard(
                        title: 'This Week',
                        value: _formatCurrency(_salesStats['thisWeekRevenue'] ?? 0.0),
                        icon: Icons.calendar_view_week,
                        color: Colors.orange,
                        subtitle: '${_salesStats['thisWeekTransactions'] ?? 0} transactions',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: SalesInfoCard(
                        title: 'This Month',
                        value: _formatCurrency(_salesStats['thisMonthRevenue'] ?? 0.0),
                        icon: Icons.calendar_month,
                        color: Colors.purple,
                        subtitle: '${_salesStats['thisMonthTransactions'] ?? 0} transactions',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: SalesInfoCard(
                        title: 'Avg Transaction',
                        value: _formatCurrency(_salesStats['averageTransactionValue'] ?? 0.0),
                        icon: Icons.trending_up,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Payment Status Cards
            const Text(
              'Payment Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SalesInfoCard(
                    title: 'Confirmed',
                    value: _formatCurrency(_salesStats['confirmedRevenue'] ?? 0.0),
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SalesInfoCard(
                    title: 'Pending',
                    value: _formatCurrency(_salesStats['pendingRevenue'] ?? 0.0),
                    icon: Icons.pending,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        );
  }
}
