import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/payment_service.dart';
import 'services/booking_service.dart';
import 'models/booking_model.dart';
import 'providers/auth_provider.dart';

class PaymentScreen extends StatefulWidget {
  final BookingModel booking;

  const PaymentScreen({
    super.key,
    required this.booking,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  final BookingService _bookingService = BookingService();
  bool _isProcessing = false;
  String? _errorMessage;
  String _selectedPaymentMethod = 'khalti'; // 'khalti' or 'cod'

  Future<void> _processPayment() async {
    if (!mounted) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      if (_selectedPaymentMethod == 'cod') {
        // Handle Cash on Delivery
        await _paymentService.handleCODPayment(
          bookingId: widget.booking.id,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Booking confirmed with Cash on Delivery. '
              'Please pay at the station when you arrive.'
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );

        Navigator.pop(context, true);
      } else {
        // Handle Khalti payment
        final paymentResult = await _paymentService.initiateKhaltiPayment(
          context: context,
          amount: widget.booking.amount,
          bookingId: widget.booking.id,
          userId: widget.booking.userId,
          productName: 'EV Charging - ${widget.booking.stationName}',
          productIdentity: widget.booking.id,
        );

        if (!mounted) return;

        if (paymentResult != null && paymentResult['success'] == true) {
          // Payment initiated - store payment ID for verification
          // Note: Actual payment verification will happen via webhook or admin confirmation
          await _paymentService.handlePaymentSuccess(
            bookingId: widget.booking.id,
            paymentData: paymentResult,
          );

          if (!mounted) return;

          // Show message that payment was initiated
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                paymentResult['note'] ?? 
                'Payment initiated. Please complete the payment in the Khalti app/browser. '
                'Your booking will be confirmed once payment is verified.'
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 5),
            ),
          );

          // Navigate back - payment will be verified via webhook or admin
          Navigator.pop(context, true);
        } else {
          // Payment failed or cancelled
          final error = paymentResult?['error'] ?? 'Payment was cancelled';
          
          await _paymentService.handlePaymentFailure(
            bookingId: widget.booking.id,
            error: error,
          );

          if (!mounted) return;

          setState(() {
            _errorMessage = error;
            _isProcessing = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed: $error'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
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
            // Booking Summary Card
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
                  const Text(
                    'Booking Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow('Station', widget.booking.stationName),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Address', widget.booking.stationAddress),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Date & Time', 
                    '${widget.booking.formattedDate} at ${widget.booking.formattedTime}'),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Plug Type', widget.booking.plugType),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Duration', widget.booking.formattedDuration),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.booking.formattedAmount,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment Method Selection
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            // Khalti Option
            InkWell(
              onTap: () {
                setState(() {
                  _selectedPaymentMethod = 'khalti';
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedPaymentMethod == 'khalti' 
                        ? Colors.purple 
                        : Colors.grey[300]!,
                    width: _selectedPaymentMethod == 'khalti' ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: _selectedPaymentMethod == 'khalti' 
                      ? Colors.purple[50] 
                      : Colors.white,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'KHALTI',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Khalti',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (_selectedPaymentMethod == 'khalti')
                      const Icon(Icons.check_circle, color: Colors.purple),
                  ],
                ),
              ),
            ),

            // Cash on Delivery Option
            InkWell(
              onTap: () {
                setState(() {
                  _selectedPaymentMethod = 'cod';
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedPaymentMethod == 'cod' 
                        ? Colors.green 
                        : Colors.grey[300]!,
                    width: _selectedPaymentMethod == 'cod' ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: _selectedPaymentMethod == 'cod' 
                      ? Colors.green[50] 
                      : Colors.white,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.money,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cash on Delivery',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Pay at the station',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedPaymentMethod == 'cod')
                      const Icon(Icons.check_circle, color: Colors.green),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),

            // Pay Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedPaymentMethod == 'cod' 
                      ? Colors.green 
                      : Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isProcessing
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
                          Text('Processing...'),
                        ],
                      )
                    : Text(
                        _selectedPaymentMethod == 'cod' 
                            ? 'Confirm Booking (Pay at Station)'
                            : 'Pay with Khalti',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Info text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _selectedPaymentMethod == 'cod' 
                    ? Colors.green[50] 
                    : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline, 
                    color: _selectedPaymentMethod == 'cod' 
                        ? Colors.green[700] 
                        : Colors.blue[700], 
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedPaymentMethod == 'cod'
                          ? 'You will pay in cash when you arrive at the charging station. The admin will confirm your payment.'
                          : 'Your payment will be verified and confirmed by the admin.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _selectedPaymentMethod == 'cod' 
                            ? Colors.green[700] 
                            : Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[600]),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

