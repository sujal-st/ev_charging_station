import 'user_model.dart';
import 'roles.dart';

class SuperUser extends UserModel {
  SuperUser({
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
  }) : super(role: Roles.superUser);

  factory SuperUser.fromUserModel(UserModel user) {
    return SuperUser(
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


