class Roles {
  static const String evChargingUser = 'ev_charging_user';
  static const String chargingStationUser = 'charging_station_user';
  static const String superUser = 'super_user';

  static const List<String> all = <String>[
    evChargingUser,
    chargingStationUser,
    superUser,
  ];

  static bool isValid(String role) => all.contains(role);
}


