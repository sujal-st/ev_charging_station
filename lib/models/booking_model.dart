import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String id;
  final String userId;
  final String stationId;
  final String stationName;
  final String stationAddress;
  final double stationLatitude;
  final double stationLongitude;
  final String plugType;
  final double maxPower;
  final int durationMinutes;
  final double amount;
  final String status; // 'upcoming', 'in_progress', 'completed', 'cancelled'
  final DateTime bookingDate;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool remindMe;
  final String? notes;
  final String? vehicleId;
  final String? vehicleModel;
  final int? connectorIndex; // Index of the connector in the station's connectors array
  // Payment fields
  final String paymentStatus; // 'pending', 'paid', 'admin_confirmed', 'failed', 'refunded'
  final String? paymentId; // Khalti payment ID
  final String? transactionId; // Khalti transaction ID
  final String? paymentMethod; // 'khalti'
  final DateTime? paidAt;
  final DateTime? confirmedAt;
  final Map<String, dynamic>? paymentMetadata; // Additional payment info
  final String? cancellationReason; // 'user_cancelled', 'no_show', 'admin_cancelled', etc.
  final int pointsEarned;
  final int pointsRedeemed;
  final double discountPercent;
  final double discountAmount;
  final bool rewardPointsGranted;
  final bool redeemedPointsRefunded;

  BookingModel({
    required this.id,
    required this.userId,
    required this.stationId,
    required this.stationName,
    required this.stationAddress,
    required this.stationLatitude,
    required this.stationLongitude,
    required this.plugType,
    required this.maxPower,
    required this.durationMinutes,
    required this.amount,
    required this.status,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
    required this.updatedAt,
    this.remindMe = true,
    this.notes,
    this.vehicleId,
    this.vehicleModel,
    this.connectorIndex,
    this.paymentStatus = 'pending',
    this.paymentId,
    this.transactionId,
    this.paymentMethod,
    this.paidAt,
    this.confirmedAt,
    this.paymentMetadata,
    this.cancellationReason,
    this.pointsEarned = 0,
    this.pointsRedeemed = 0,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.rewardPointsGranted = false,
    this.redeemedPointsRefunded = false,
  });

  // Create from Firestore document
  factory BookingModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return BookingModel(
      id: docId,
      userId: data['userId'] ?? '',
      stationId: data['stationId'] ?? '',
      stationName: data['stationName'] ?? '',
      stationAddress: data['stationAddress'] ?? '',
      stationLatitude: (data['stationLatitude'] ?? 0.0).toDouble(),
      stationLongitude: (data['stationLongitude'] ?? 0.0).toDouble(),
      plugType: data['plugType'] ?? '',
      maxPower: (data['maxPower'] ?? 0.0).toDouble(),
      durationMinutes: data['durationMinutes'] ?? 60,
      amount: (data['amount'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'upcoming',
      bookingDate: data['bookingDate'] is Timestamp
          ? (data['bookingDate'] as Timestamp).toDate()
          : DateTime.now(),
      startTime: data['startTime'] is Timestamp
          ? (data['startTime'] as Timestamp).toDate()
          : DateTime.now(),
      endTime: data['endTime'] is Timestamp
          ? (data['endTime'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(hours: 1)),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      remindMe: data['remindMe'] ?? true,
      notes: data['notes'],
      vehicleId: data['vehicleId'],
      vehicleModel: data['vehicleModel'],
      connectorIndex: data['connectorIndex'],
      paymentStatus: data['paymentStatus'] ?? 'pending',
      paymentId: data['paymentId'],
      transactionId: data['transactionId'],
      paymentMethod: data['paymentMethod'],
      paidAt: data['paidAt'] is Timestamp
          ? (data['paidAt'] as Timestamp).toDate()
          : (data['paidAt'] is DateTime ? data['paidAt'] as DateTime : null),
      confirmedAt: data['confirmedAt'] is Timestamp
          ? (data['confirmedAt'] as Timestamp).toDate()
          : (data['confirmedAt'] is DateTime ? data['confirmedAt'] as DateTime : null),
      paymentMetadata: data['paymentMetadata'] != null
          ? Map<String, dynamic>.from(data['paymentMetadata'])
          : null,
      cancellationReason: data['cancellationReason'],
      pointsEarned: data['pointsEarned'] ?? 0,
      pointsRedeemed: data['pointsRedeemed'] ?? 0,
      discountPercent: (data['discountPercent'] ?? 0.0).toDouble(),
      discountAmount: (data['discountAmount'] ?? 0.0).toDouble(),
      rewardPointsGranted: data['rewardPointsGranted'] ?? false,
      redeemedPointsRefunded: data['redeemedPointsRefunded'] ?? false,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'stationId': stationId,
      'stationName': stationName,
      'stationAddress': stationAddress,
      'stationLatitude': stationLatitude,
      'stationLongitude': stationLongitude,
      'plugType': plugType,
      'maxPower': maxPower,
      'durationMinutes': durationMinutes,
      'amount': amount,
      'status': status,
      'bookingDate': bookingDate,
      'startTime': startTime,
      'endTime': endTime,
      'remindMe': remindMe,
      'notes': notes,
      'vehicleId': vehicleId,
      'vehicleModel': vehicleModel,
      'connectorIndex': connectorIndex,
      'paymentStatus': paymentStatus,
      'paymentId': paymentId,
      'transactionId': transactionId,
      'paymentMethod': paymentMethod,
      'paidAt': paidAt,
      'confirmedAt': confirmedAt,
      'paymentMetadata': paymentMetadata,
      'cancellationReason': cancellationReason,
      'pointsEarned': pointsEarned,
      'pointsRedeemed': pointsRedeemed,
      'discountPercent': discountPercent,
      'discountAmount': discountAmount,
      'rewardPointsGranted': rewardPointsGranted,
      'redeemedPointsRefunded': redeemedPointsRefunded,
    };
  }

  // Create a copy with updated fields
  BookingModel copyWith({
    String? id,
    String? userId,
    String? stationId,
    String? stationName,
    String? stationAddress,
    double? stationLatitude,
    double? stationLongitude,
    String? plugType,
    double? maxPower,
    int? durationMinutes,
    double? amount,
    String? status,
    DateTime? bookingDate,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? remindMe,
    String? notes,
    String? vehicleId,
    String? vehicleModel,
    int? connectorIndex,
    String? paymentStatus,
    String? paymentId,
    String? transactionId,
    String? paymentMethod,
    DateTime? paidAt,
    DateTime? confirmedAt,
    Map<String, dynamic>? paymentMetadata,
    String? cancellationReason,
    int? pointsEarned,
    int? pointsRedeemed,
    double? discountPercent,
    double? discountAmount,
    bool? rewardPointsGranted,
    bool? redeemedPointsRefunded,
  }) {
    return BookingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      stationId: stationId ?? this.stationId,
      stationName: stationName ?? this.stationName,
      stationAddress: stationAddress ?? this.stationAddress,
      stationLatitude: stationLatitude ?? this.stationLatitude,
      stationLongitude: stationLongitude ?? this.stationLongitude,
      plugType: plugType ?? this.plugType,
      maxPower: maxPower ?? this.maxPower,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      bookingDate: bookingDate ?? this.bookingDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      remindMe: remindMe ?? this.remindMe,
      notes: notes ?? this.notes,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      connectorIndex: connectorIndex ?? this.connectorIndex,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentId: paymentId ?? this.paymentId,
      transactionId: transactionId ?? this.transactionId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidAt: paidAt ?? this.paidAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      paymentMetadata: paymentMetadata ?? this.paymentMetadata,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      pointsRedeemed: pointsRedeemed ?? this.pointsRedeemed,
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      rewardPointsGranted: rewardPointsGranted ?? this.rewardPointsGranted,
      redeemedPointsRefunded: redeemedPointsRefunded ?? this.redeemedPointsRefunded,
    );
  }

  // Helper methods
  bool get isUpcoming => status == 'upcoming';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[bookingDate.month - 1]} ${bookingDate.day}, ${bookingDate.year}';
  }

  String get formattedTime {
    final hour = startTime.hour;
    final minute = startTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  String get formattedDuration {
    if (durationMinutes < 60) {
      return '${durationMinutes}m';
    } else {
      final hours = durationMinutes ~/ 60;
      final minutes = durationMinutes % 60;
      if (minutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${minutes}m';
      }
    }
  }

  String get formattedAmount {
    return 'Rs${amount.toStringAsFixed(2)}';
  }

  // Payment helper methods
  bool get isPaymentPending => paymentStatus == 'pending';
  bool get isPaymentPaid => paymentStatus == 'paid';
  bool get isPaymentConfirmed => paymentStatus == 'admin_confirmed';
  bool get isPaymentFailed => paymentStatus == 'failed';
  bool get isPaymentRefunded => paymentStatus == 'refunded';
}
