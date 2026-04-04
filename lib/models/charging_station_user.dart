import 'user_model.dart';
import 'roles.dart';

class ChargingStationUser extends UserModel {
  ChargingStationUser({
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
  }) : super(role: Roles.chargingStationUser);

  factory ChargingStationUser.fromUserModel(UserModel user) {
    return ChargingStationUser(
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


