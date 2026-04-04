import 'user_model.dart';
import 'roles.dart';

class EvChargingUser extends UserModel {
  EvChargingUser({
    required super.uid,
    required super.email,
    required super.name,
    super.gender,
    super.dateOfBirth,
    super.createdAt,
    super.updatedAt,
    super.isLoggedIn,
    super.hasSeenOnboarding,
    super.lastLoginAt,
    super.lastLogoutAt,
  }) : super(role: Roles.evChargingUser);

  factory EvChargingUser.fromUserModel(UserModel user) {
    return EvChargingUser(
      uid: user.uid,
      email: user.email,
      name: user.name,
      gender: user.gender,
      dateOfBirth: user.dateOfBirth,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
      isLoggedIn: user.isLoggedIn,
      hasSeenOnboarding: user.hasSeenOnboarding,
      lastLoginAt: user.lastLoginAt,
      lastLogoutAt: user.lastLogoutAt,
    );
  }
}


