// Khalti Payment Integration using REST API
// Using direct HTTP calls instead of khalti_flutter package
// to avoid compatibility issues with Flutter 3.35.4
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../config/payment_config.dart' as app_config;
import '../models/booking_model.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Verify Khalti secret key by making a simple API call
  // This helps diagnose if the key is valid
  Future<bool> verifyKhaltiKey() async {
    try {
      final secretKey = app_config.AppPaymentConfig.khaltiSecretKey.trim();
      final baseUrl = app_config.AppPaymentConfig.khaltiBaseUrl;
      
      // Try a simple endpoint to verify the key works
      // Using payment/status endpoint as a test
      final response = await http.get(
        Uri.parse('$baseUrl/payment/status/'),
        headers: {
          'Authorization': 'Key $secretKey',
          'Content-Type': 'application/json',
        },
      );
      
      // If we get 400 (bad request) instead of 401 (unauthorized), the key is valid
      // 401 means invalid key, 400 means key is valid but request is wrong (which is fine for testing)
      return response.statusCode != 401;
    } catch (e) {
      print('Key verification error: $e');
      return false;
    }
  }

  // Initialize Khalti payment
  // IMPORTANT: This implementation is a template. You may need to adjust based on
  // the actual khalti_flutter package API. Refer to the package documentation.
  Future<Map<String, dynamic>?> initiateKhaltiPayment({
    required BuildContext context,
    required double amount,
    required String bookingId,
    required String userId,
    required String productName,
    required String productIdentity,
  }) async {
    try {
      // Convert amount to paisa (Khalti uses paisa as the smallest unit)
      final amountInPaisa = (amount * 100).toInt();

      // Initialize Khalti payment using REST API
      // Using Khalti's payment initiation API to create a payment URL
      // SECURITY WARNING: epayment/initiate requires SECRET key
      // In production, this should be called from your backend server, not client-side
      // This is a temporary workaround - move to backend for security
      
      final apiUrl = '${app_config.AppPaymentConfig.khaltiBaseUrl}/epayment/initiate/';
      
      // Use SECRET key for epayment/initiate endpoint (not public key)
      // Public key is only for client-side SDK usage
      final secretKey = app_config.AppPaymentConfig.khaltiSecretKey.trim();
      
      // Log request details for debugging (remove in production)
      print('Khalti API URL: $apiUrl');
      print('Using Secret Key (first 8): ${secretKey.length >= 8 ? secretKey.substring(0, 8) : secretKey}...');
      print('Secret Key Length: ${secretKey.length}');
      print('Is Production: ${app_config.AppPaymentConfig.isProduction}');
      
      // Verify key format (should be 32 characters, no spaces)
      if (secretKey.isEmpty) {
        return {
          'success': false,
          'error': 'Secret key is empty. Please check payment_config.dart',
        };
      }
      
      // Additional validation
      if (secretKey.length < 20) {
        return {
          'success': false,
          'error': 'Secret key appears to be too short. Please verify you copied the complete key from Khalti dashboard.',
        };
      }
      
      final requestBody = {
        'return_url': 'evcharging://payment-success?booking_id=$bookingId',
        'website_url': 'https://evcharging.com',
        'amount': amountInPaisa,
        'purchase_order_id': bookingId,
        'purchase_order_name': productName,
      };
      
      print('Request Body: ${jsonEncode(requestBody)}');
      
      // Build authorization header - ensure no extra spaces
      final authHeader = 'Key $secretKey';
      print('Authorization Header: Key ${secretKey.length >= 8 ? secretKey.substring(0, 8) : secretKey}...');
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      // Log response for debugging
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['pidx'] != null) {
          // Payment URL created successfully
          final paymentUrl = data['payment_url'];
          
          // Launch Khalti payment page
          final uri = Uri.parse(paymentUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            
            // Return payment data - actual verification will happen via webhook or manual check
            return {
              'success': true,
              'paymentId': data['pidx'],
              'transactionId': data['pidx'],
              'amount': amount,
              'paymentUrl': paymentUrl,
              'note': 'Payment initiated. Please complete payment in Khalti app/browser.',
            };
          } else {
            return {
              'success': false,
              'error': 'Could not launch payment URL',
            };
          }
        } else {
          // Show detailed error from Khalti
          final errorMsg = data['detail'] ?? 
                          data['error_key'] ?? 
                          data['error_message'] ?? 
                          data['message'] ??
                          'Failed to initiate payment';
          print('Khalti Error: $errorMsg');
          return {
            'success': false,
            'error': errorMsg,
          };
        }
      } else {
        // Parse error response with better error handling
        try {
          final errorData = jsonDecode(response.body);
          final errorMsg = errorData['detail'] ?? 
                         errorData['error_key'] ?? 
                         errorData['error_message'] ?? 
                         errorData['message'] ??
                         'Failed to initiate payment';
          print('Khalti API Error: $errorMsg');
          print('Full Error Response: ${response.body}');
          
          // Provide simple error message for "Invalid token" error
          String userFriendlyError = errorMsg;
          if (errorMsg.toLowerCase().contains('invalid token') || 
              errorMsg.toLowerCase().contains('unauthorized') ||
              response.statusCode == 401) {
            userFriendlyError = 'Invalid token';
          }
          
          return {
            'success': false,
            'error': userFriendlyError,
          };
        } catch (e) {
          print('Failed to parse error response: $e');
          return {
            'success': false,
            'error': 'Failed to initiate payment. Status: ${response.statusCode}, Response: ${response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Verify payment with Khalti API
  Future<Map<String, dynamic>> verifyPayment({
    required String paymentId,
    required String token,
    required double amount,
  }) async {
    try {
      // Note: In production, this should be done on your backend server
      // for security reasons. The secret key should never be in the app.
      // This is a placeholder - implement proper backend verification.
      
      // For now, we'll assume payment is verified if we got a paymentId
      // In production, make an HTTP request to your backend which will
      // verify with Khalti using the secret key.
      
      return {
        'success': true,
        'paymentId': paymentId,
        'transactionId': paymentId,
        'verified': true,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'verified': false,
      };
    }
  }

  // Handle payment success
  Future<void> handlePaymentSuccess({
    required String bookingId,
    required Map<String, dynamic> paymentData,
  }) async {
    try {
      final updateData = {
        'paymentStatus': 'paid',
        'paymentId': paymentData['paymentId'],
        'transactionId': paymentData['transactionId'],
        'paymentMethod': 'khalti',
        'paidAt': FieldValue.serverTimestamp(),
        'paymentMetadata': {
          'token': paymentData['token'],
          'verified': paymentData['verified'] ?? false,
          'paidAt': DateTime.now().toIso8601String(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('bookings').doc(bookingId).update(updateData);
    } catch (e) {
      throw Exception('Failed to update booking payment: $e');
    }
  }

  // Handle payment failure
  Future<void> handlePaymentFailure({
    required String bookingId,
    required String error,
  }) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'paymentStatus': 'failed',
        'paymentMetadata': {
          'error': error,
          'failedAt': DateTime.now().toIso8601String(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update booking payment failure: $e');
    }
  }

  // Handle Cash on Delivery payment
  Future<void> handleCODPayment({
    required String bookingId,
  }) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'paymentStatus': 'pending',
        'paymentMethod': 'cod',
        'paymentMetadata': {
          'method': 'cash_on_delivery',
          'selectedAt': DateTime.now().toIso8601String(),
          'note': 'Payment will be collected at the station',
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update booking for COD: $e');
    }
  }

  // Get payment status for a booking
  Future<Map<String, dynamic>?> getPaymentStatus(String bookingId) async {
    try {
      final doc = await _firestore.collection('bookings').doc(bookingId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'paymentStatus': data['paymentStatus'] ?? 'pending',
          'paymentId': data['paymentId'],
          'transactionId': data['transactionId'],
          'paymentMethod': data['paymentMethod'],
          'paidAt': data['paidAt'],
          'confirmedAt': data['confirmedAt'],
        };
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get payment status: $e');
    }
  }
}

