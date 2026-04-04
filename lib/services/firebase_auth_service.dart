import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if citizenship number already exists for EV users
  Future<bool> checkCitizenshipNumberExists(String citizenshipNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('citizenshipNumber', isEqualTo: citizenshipNumber)
          .where('role', isEqualTo: 'ev_charging_user')
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking citizenship number: $e');
      return false;
    }
  }

  // Sign up with email and password
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    String? gender,
    DateTime? dateOfBirth,
    String? phoneNumber,
    String? role,
  }) async {
    try {
      // Create user with email and password
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save additional user data to Firestore
      if (userCredential.user != null) {
        final userData = {
          'uid': userCredential.user!.uid,
          'email': email,
          'name': name,
          'gender': gender,
          'dateOfBirth': dateOfBirth?.toIso8601String(),
          'phoneNumber': phoneNumber,
          'phoneVerified': false, // Will be updated after phone verification
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isLoggedIn': true,
          'hasSeenOnboarding': true,
          'role': role ?? 'ev_charging_user',
          'rewardPoints': 0,
          'subscriptionTier': role == 'charging_station_user' ? 'basic' : 'basic',
          'subscriptionStatus': role == 'charging_station_user' ? 'active' : 'inactive',
        };
        
        await _firestore.collection('users').doc(userCredential.user!.uid).set(userData);
      }

      return userCredential;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      print('Attempting to sign in with email: $email');

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('Sign in successful for user: ${userCredential.user?.uid}');

      // Update login status in Firestore
      if (userCredential.user != null) {
        try {
          await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .update({
            'isLoggedIn': true,
            'lastLoginAt': FieldValue.serverTimestamp(),
          });
          print('Firestore update successful');
        } catch (firestoreError) {
          print('Firestore update failed: $firestoreError');
          // Don't throw error for Firestore update failure
        }
      }

      return userCredential;
    } catch (e) {
      print('Sign in error: $e');
      print('Error type: ${e.runtimeType}');
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Update logout status in Firestore
      if (_auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .update({
          'isLoggedIn': false,
          'lastLogoutAt': FieldValue.serverTimestamp(),
        });
      }

      await _auth.signOut();
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
      );
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Verify phone number (OTP will be sent)
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    // Ensure phone number is in E.164 format (e.g., +9779800000000)
    String formattedPhone = phoneNumber.trim();
    
    // Remove spaces from phone number
    formattedPhone = formattedPhone.replaceAll(' ', '');
    
    // Ensure it starts with +
    if (!formattedPhone.startsWith('+')) {
      throw Exception('Phone number must include country code (e.g., +977)');
    }
    
    // Validate phone number format
    if (formattedPhone.length < 10) {
      throw Exception('Invalid phone number format');
    }
    
    await _auth.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      timeout: const Duration(seconds: 60),
    );
  }

  // Sign in with phone credential
  Future<UserCredential> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Link phone number to existing user account
  Future<void> linkPhoneNumberToUser({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      await user.linkWithCredential(credential);

      // Update phone verification status in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'phoneVerified': true,
        'phoneNumber': user.phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Update phone verification status in Firestore
  Future<void> updatePhoneVerificationStatus({
    required String uid,
    required bool phoneVerified,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'phoneVerified': phoneVerified,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update phone verification status: $e');
    }
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user profile: $e');
      throw Exception('Failed to update profile');
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email address.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'An account already exists with this email address.';
        case 'weak-password':
          return 'The password provided is too weak.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'too-many-requests':
          return 'Too many requests. Please try again later.';
        case 'operation-not-allowed':
          return 'Email/password accounts are not enabled.';
        case 'invalid-credential':
          return 'Invalid credentials provided.';
        case 'missing-email':
          return 'Please provide an email address.';
        case 'invalid-phone-number':
          return 'Invalid phone number format.';
        case 'missing-phone-number':
          return 'Please provide a phone number.';
        case 'quota-exceeded':
          return 'SMS quota exceeded. Please try again later.';
        case 'invalid-verification-code':
          return 'Invalid verification code.';
        case 'invalid-verification-id':
          return 'Invalid verification ID.';
        case 'session-expired':
          return 'Verification session expired. Please request a new code.';
        default:
          // Check for billing errors in the message
          if (e.message?.contains('BILLING_NOT_ENABLED') == true) {
            return 'Phone verification requires Firebase Blaze plan. Please enable billing in Firebase Console.';
          }
          return 'Authentication failed: ${e.message}';
      }
    }
    return 'An unexpected error occurred.';
  }
}
