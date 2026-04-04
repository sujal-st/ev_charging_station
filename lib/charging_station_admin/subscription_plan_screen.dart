import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class SubscriptionPlanScreen extends StatelessWidget {
  const SubscriptionPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Subscription Plans'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final currentTier = authProvider.subscriptionTier;
          final currentStatus = authProvider.subscriptionStatus;
          final statusLabel = _displaySubscriptionStatus(currentStatus);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade600, Colors.green.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Station Admin Subscription',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose the plan that matches how much operational insight you need.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _pill('Current: ${currentTier.toUpperCase()}', Colors.white),
                          _pill('Status: $statusLabel', Colors.white),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _planCard(
                  context: context,
                  title: 'Basic',
                  subtitle: 'Simple dashboard features for day-to-day station management.',
                  priceLabel: 'Free',
                  accentColor: Colors.blue,
                  features: const [
                    'Station overview and bookings',
                    'Standard booking management',
                    'Basic station statistics',
                    'Map of your stations',
                  ],
                  isCurrent: currentTier == 'basic',
                  actionLabel: currentTier == 'basic' ? 'Current plan' : 'Switch to Basic',
                  onTap: currentTier == 'basic'
                      ? null
                      : () => _updatePlan(context, 'basic', 'active'),
                ),
                const SizedBox(height: 16),
                _planCard(
                  context: context,
                  title: 'Pro',
                  subtitle: 'Paid plan with advanced customer-flow analytics.',
                  priceLabel: 'Paid',
                  accentColor: Colors.deepOrange,
                  features: const [
                    'Heatmap of customer flow',
                    'Peak hours analytics',
                    'Busy-day trend insights',
                    'Pro dashboard sections',
                  ],
                  isCurrent: currentTier == 'pro',
                  actionLabel: currentTier == 'pro' ? 'Current plan' : 'Upgrade to Pro',
                  onTap: currentTier == 'pro'
                      ? null
                      : () => _showProUpgradeDialog(context),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pro analytics preview',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _previewRow(Icons.area_chart, 'Customer flow heatmap', 'See station traffic density by time and location.'),
                      const SizedBox(height: 12),
                      _previewRow(Icons.access_time, 'Peak hours', 'Identify the busiest hours to plan staffing and pricing.'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _planCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String priceLabel,
    required Color accentColor,
    required List<String> features,
    required bool isCurrent,
    required String actionLabel,
    required VoidCallback? onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent ? accentColor : Colors.grey.shade200,
          width: isCurrent ? 2 : 1,
        ),
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  priceLabel,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: accentColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrent ? Colors.grey.shade300 : accentColor,
                foregroundColor: isCurrent ? Colors.black87 : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.green.shade700, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(description, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _displaySubscriptionStatus(String status) {
    if (status.toLowerCase() == 'active') {
      return 'LIVE';
    }
    return status.toUpperCase();
  }

  Future<void> _showProUpgradeDialog(BuildContext context) async {
    String selectedMethod = 'bank_transfer';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Upgrade to Pro'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Please pay the subscription fee to activate Pro analytics features.',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Text(
                      'Subscription Fee: Rs 2,999 / month',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Select payment method:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'bank_transfer',
                    groupValue: selectedMethod,
                    onChanged: (value) {
                      setState(() {
                        selectedMethod = value ?? 'bank_transfer';
                      });
                    },
                    title: const Text('Direct bank transfer'),
                    subtitle: const Text('Transfer to the official company bank account.'),
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'esewa',
                    groupValue: selectedMethod,
                    onChanged: (value) {
                      setState(() {
                        selectedMethod = value ?? 'bank_transfer';
                      });
                    },
                    title: const Text('eSewa'),
                    subtitle: const Text('Pay quickly using your eSewa wallet.'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    if (selectedMethod == 'bank_transfer') {
                      final submitted = await _showBankTransferInterface(context);
                      if (!submitted) return;
                      await _updatePlan(context, 'pro', 'live');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bank transfer details submitted. Pro is now LIVE.'),
                          backgroundColor: Colors.blue,
                          duration: Duration(seconds: 4),
                        ),
                      );
                      return;
                    }

                    await _updatePlan(context, 'pro', 'active');
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('eSewa payment selected. Pro service activated.'),
                        backgroundColor: Colors.blue,
                        duration: Duration(seconds: 4),
                      ),
                    );
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _showBankTransferInterface(BuildContext context) async {
    const accountName = 'BijuliX Energy Pvt. Ltd.';
    const bankName = 'Nepal Investment Mega Bank';
    const accountNumber = '014001234567890';
    const amount = 'Rs 2,999';

    final referenceController = TextEditingController();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            18,
            16,
            MediaQuery.of(sheetContext).viewInsets.bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Direct Bank Transfer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Use the details below to transfer the subscription fee.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                _readOnlyField(label: 'Account Name', value: accountName),
                const SizedBox(height: 10),
                _readOnlyField(label: 'Bank Name', value: bankName),
                const SizedBox(height: 10),
                _readOnlyField(label: 'Account Number', value: accountNumber),
                const SizedBox(height: 10),
                _readOnlyField(label: 'Amount', value: amount),
                const SizedBox(height: 14),
                TextField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Transaction Reference (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        child: const Text('I Have Transferred'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    referenceController.dispose();
    return result ?? false;
  }

  Widget _readOnlyField({required String label, required String value}) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _updatePlan(BuildContext context, String tier, String status) async {
    final authProvider = context.read<AuthProvider>();
    try {
      await authProvider.updateSubscriptionPlan(tier: tier, status: status);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subscription updated to ${tier.toUpperCase()}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update subscription: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
