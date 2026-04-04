import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? phoneNumber;
  final String? citizenshipNumber;
  final DateTime? citizenshipIssueDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isLoggedIn;
  final bool hasSeenOnboarding;
  final String role;
  final int rewardPoints;
  final String subscriptionTier;
  final String subscriptionStatus;
  final DateTime? subscriptionUpdatedAt;
  final DateTime? lastLoginAt;
  final DateTime? lastLogoutAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.gender,
    this.dateOfBirth,
    this.phoneNumber,
    this.citizenshipNumber,
    this.citizenshipIssueDate,
    this.createdAt,
    this.updatedAt,
    this.isLoggedIn = false,
    this.hasSeenOnboarding = false,
    this.role = 'user',
    this.rewardPoints = 0,
    this.subscriptionTier = 'basic',
    this.subscriptionStatus = 'inactive',
    this.subscriptionUpdatedAt,
    this.lastLoginAt,
    this.lastLogoutAt,
  });

  // Create from Firestore document
  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      gender: data['gender'],
      phoneNumber: data['phoneNumber'],
      citizenshipNumber: data['citizenshipNumber'],
      citizenshipIssueDate: data['citizenshipIssueDate'] is Timestamp
          ? (data['citizenshipIssueDate'] as Timestamp).toDate()
          : data['citizenshipIssueDate'] is String
              ? DateTime.tryParse(data['citizenshipIssueDate'])
              : null,
      dateOfBirth: data['dateOfBirth'] is Timestamp
          ? (data['dateOfBirth'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      isLoggedIn: data['isLoggedIn'] ?? false,
      hasSeenOnboarding: data['hasSeenOnboarding'] ?? false,
      role: data['role'] ?? 'user',
      rewardPoints: data['rewardPoints'] ?? 0,
      subscriptionTier: data['subscriptionTier'] ?? 'basic',
      subscriptionStatus: data['subscriptionStatus'] ?? 'inactive',
      subscriptionUpdatedAt: data['subscriptionUpdatedAt'] is Timestamp
          ? (data['subscriptionUpdatedAt'] as Timestamp).toDate()
          : null,
      lastLoginAt: data['lastLoginAt'] is Timestamp
          ? (data['lastLoginAt'] as Timestamp).toDate()
          : null,
      lastLogoutAt: data['lastLogoutAt'] is Timestamp
          ? (data['lastLogoutAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'gender': gender,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'phoneNumber': phoneNumber,
      'citizenshipNumber': citizenshipNumber,
      'citizenshipIssueDate': citizenshipIssueDate?.toIso8601String(),
      'isLoggedIn': isLoggedIn,
      'hasSeenOnboarding': hasSeenOnboarding,
      'role': role,
      'rewardPoints': rewardPoints,
      'subscriptionTier': subscriptionTier,
      'subscriptionStatus': subscriptionStatus,
    };
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? gender,
    DateTime? dateOfBirth,
    String? phoneNumber,
    String? citizenshipNumber,
    DateTime? citizenshipIssueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isLoggedIn,
    bool? hasSeenOnboarding,
    String? role,
    int? rewardPoints,
    String? subscriptionTier,
    String? subscriptionStatus,
    DateTime? subscriptionUpdatedAt,
    DateTime? lastLoginAt,
    DateTime? lastLogoutAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      citizenshipNumber: citizenshipNumber ?? this.citizenshipNumber,
      citizenshipIssueDate: citizenshipIssueDate ?? this.citizenshipIssueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      role: role ?? this.role,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionUpdatedAt: subscriptionUpdatedAt ?? this.subscriptionUpdatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastLogoutAt: lastLogoutAt ?? this.lastLogoutAt,
    );
  }
}
