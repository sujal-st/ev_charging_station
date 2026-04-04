import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import '../config/imgbb_config.dart';

class ChargingStationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> addStation(Map<String, dynamic> data) async {
    try {
      final payload = {
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final doc = await _firestore.collection('charging_stations').add(payload);
      return doc.id;
    } catch (e) {
      throw Exception('Failed to add station: $e');
    }
  }

  Future<void> updateStation(String id, Map<String, dynamic> data) async {
    try {
      final payload = {
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _firestore.collection('charging_stations').doc(id).update(payload);
    } catch (e) {
      throw Exception('Failed to update station: $e');
    }
  }

  /// Uploads image to ImgBB and returns the image URL
  /// Optionally compresses the image before upload for faster uploads
  /// Returns the direct image URL from ImgBB
  Future<String> uploadStationPhoto(File imageFile, String stationId) async {
    try {
      // Check if file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }
      
      // Check API key is configured
      if (ImgBBConfig.apiKey == 'YOUR_IMGBB_API_KEY_HERE' || ImgBBConfig.apiKey.isEmpty) {
        throw Exception('ImgBB API key not configured. Please set your API key in lib/config/imgbb_config.dart');
      }
      
      // Check original file size (32MB is ImgBB free tier limit)
      final originalSize = await imageFile.length();
      if (originalSize > ImgBBConfig.maxFileSizeBytes) {
        throw Exception('Image file is too large. Maximum size is ${ImgBBConfig.maxFileSizeBytes ~/ (1024 * 1024)}MB');
      }
      
      // Read original image bytes
      final originalBytes = await imageFile.readAsBytes();
      
      // Optionally compress image if it's larger than recommended size (for faster uploads)
      Uint8List imageBytesToUpload = originalBytes;
      if (originalSize > ImgBBConfig.recommendedMaxSizeBytes) {
        // Compress the image in memory for faster upload
        Uint8List? compressedBytes = await FlutterImageCompress.compressWithList(
          originalBytes,
          minHeight: 1080,
          minWidth: 1920,
          quality: 85,
          format: CompressFormat.jpeg,
        );
        
        if (compressedBytes != null && compressedBytes.isNotEmpty) {
          imageBytesToUpload = compressedBytes;
          print('Image compressed from ${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB to ${(compressedBytes.length / 1024 / 1024).toStringAsFixed(2)}MB');
        }
      }
      
      // Prepare multipart request to ImgBB
      final uri = Uri.parse('${ImgBBConfig.uploadEndpoint}?key=${ImgBBConfig.apiKey}');
      
      final request = http.MultipartRequest('POST', uri);
      
      // ImgBB accepts base64 encoded image in the 'image' field
      final base64Image = base64Encode(imageBytesToUpload);
      request.fields['image'] = base64Image;
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      // Parse response
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          // Return the direct image URL
          final imageUrl = jsonResponse['data']['url'] as String?;
          if (imageUrl != null && imageUrl.isNotEmpty) {
            return imageUrl;
          } else {
            throw Exception('ImgBB returned success but no image URL');
          }
        } else {
          // Handle ImgBB error response
          final errorMessage = jsonResponse['error']?['message'] ?? 
                              jsonResponse['error']?['code'] ?? 
                              'Unknown error from ImgBB';
          throw Exception('ImgBB upload failed: $errorMessage');
        }
      } else {
        // Handle HTTP error
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['error']?['message'] ?? 
                             errorData['error']?['code'] ?? 
                             'HTTP ${response.statusCode}';
          throw Exception('ImgBB upload failed: $errorMessage');
        } catch (_) {
          throw Exception('ImgBB upload failed: HTTP ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      // Re-throw with more context if it's not already an Exception
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to upload station photo: $e');
    }
  }

  /// Fetches all approved charging stations for user side
  /// Only stations with verificationStatus == 'approved' are shown to users
  Future<List<Map<String, dynamic>>> fetchAllStations() async {
    try {
      final snapshot = await _firestore
          .collection('charging_stations')
          .where('verificationStatus', isEqualTo: 'approved')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final connectors = data['connectors'];
        final int connectorsCount = connectors is List ? connectors.length : (connectors is int ? connectors : 0);
        return {
          'id': data['id'] ?? doc.id,
          'firestoreId': doc.id,
          'name': data['name'],
          'address': data['address'],
          'lat': data['lat'] ?? data['latitude'],
          'lng': data['lng'] ?? data['longitude'],
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          'plug_type': data['plug_type'] ?? data['plugType'],
          'price': data['price'],
          'available': data['available'] ?? true,
          'status': data['status'] ?? 'active',
          'description': data['description'],
          'contact': data['contact'],
          'parking': data['parking'],
          'connectors': connectors,
          'connectorsCount': connectorsCount,
          'ownerId': data['ownerId'],
          'verificationStatus': data['verificationStatus'] ?? 'approved',
        };
      }).toList();
    } catch (e) {
      // If index doesn't exist, fallback to filtering in memory
      if (e.toString().contains('index') || e.toString().contains('failed-precondition')) {
        final allSnapshot = await _firestore.collection('charging_stations').get();
        return allSnapshot.docs
            .where((doc) {
              final data = doc.data();
              final status = data['verificationStatus'] ?? 'pending';
              return status == 'approved';
            })
            .map((doc) {
              final data = doc.data();
              final connectors = data['connectors'];
              final int connectorsCount = connectors is List ? connectors.length : (connectors is int ? connectors : 0);
              return {
                'id': data['id'] ?? doc.id,
                'firestoreId': doc.id,
                'name': data['name'],
                'address': data['address'],
                'lat': data['lat'] ?? data['latitude'],
                'lng': data['lng'] ?? data['longitude'],
                'latitude': data['latitude'],
                'longitude': data['longitude'],
                'plug_type': data['plug_type'] ?? data['plugType'],
                'price': data['price'],
                'available': data['available'] ?? true,
                'status': data['status'] ?? 'active',
                'description': data['description'],
                'contact': data['contact'],
                'parking': data['parking'],
                'connectors': connectors,
                'connectorsCount': connectorsCount,
                'ownerId': data['ownerId'],
                'verificationStatus': data['verificationStatus'] ?? 'approved',
              };
            }).toList();
      }
      throw Exception('Failed to fetch charging stations: $e');
    }
  }
}
