import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_auth_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  User? _currentUser;
  UserModel? _userData;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  UserModel? get userData => _userData;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  int get rewardPoints => _userData?.rewardPoints ?? 0;
  String get subscriptionTier => _userData?.subscriptionTier ?? 'basic';
  String get subscriptionStatus => _userData?.subscriptionStatus ?? 'inactive';

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((User? user) {
      _currentUser = user;
      if (user != null) {
        _loadUserData(user.uid);
      } else {
        _userData = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserData(String uid) async {
    try {
      final data = await _authService.getUserData(uid);
      if (data != null) {
        _userData = UserModel.fromFirestore(data);
        notifyListeners();
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    String? gender,
    DateTime? dateOfBirth,
    String? phoneNumber,
    String? role,
  }) async {
    _setLoading(true);
    try {
      await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
        gender: gender,
        dateOfBirth: dateOfBirth,
        phoneNumber: phoneNumber,
        role: role,
      );
    } finally {
      _setLoading(false);
    }
  }

  bool get isEvChargingUser => _userData?.role == 'ev_charging_user';
  bool get isChargingStationUser => _userData?.role == 'charging_station_user';
  bool get isSuperUser => _userData?.role == 'super_user';

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    if (_currentUser != null) {
      try {
        await _authService.updateUserProfile(
          uid: _currentUser!.uid,
          data: data,
        );
        await _loadUserData(_currentUser!.uid);
      } catch (e) {
        print('Error updating profile: $e');
        rethrow;
      }
    }
  }

  Future<void> reloadUserData() async {
    if (_currentUser != null) {
      await _loadUserData(_currentUser!.uid);
    }
  }

  Future<void> updateSubscriptionPlan({
    required String tier,
    required String status,
  }) async {
    final effectiveUser = _currentUser ?? _authService.currentUser;
    if (effectiveUser == null) {
      throw Exception('No authenticated user found. Please login again.');
    }

    final normalizedTier = tier.trim().toLowerCase();
    final normalizedStatus = status.trim().toLowerCase();

    await _authService.updateUserProfile(
      uid: effectiveUser.uid,
      data: {
        'subscriptionTier': normalizedTier,
        'subscriptionStatus': normalizedStatus,
        'subscriptionUpdatedAt': DateTime.now().toIso8601String(),
      },
    );

    // Read back immediately so UI reflects the persisted server value.
    final updatedData = await _authService.getUserData(effectiveUser.uid);
    if (updatedData == null) {
      throw Exception('Subscription updated, but failed to read user data.');
    }

    final savedTier = (updatedData['subscriptionTier'] ?? 'basic').toString().trim().toLowerCase();
    final savedStatus = (updatedData['subscriptionStatus'] ?? 'inactive').toString().trim().toLowerCase();

    _userData = UserModel.fromFirestore(updatedData);
    notifyListeners();

    if (savedTier != normalizedTier || savedStatus != normalizedStatus) {
      throw Exception('Subscription was not persisted correctly. Please try again.');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
