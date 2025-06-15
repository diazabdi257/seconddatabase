// lib/models/member_schedule.dart
import 'package:intl/intl.dart';

class MemberSchedule {
  final String key; // Kunci unik Firebase (misal: -XYZ123)
  final String bookingType;
  final int dayOfWeek; // 1 (Senin) - 7 (Minggu)
  final String endTime; // Format "HH:mm"
  final String fieldId; // e.g., "lapangan1"
  final String firstDate; // "yyyy-MM-dd", tanggal mulai membership
  final String fullName;
  final String phoneNumber;
  final String startTime; // Format "HH:mm"
  final num timestamp;
  final int validityMonths; // Durasi dalam bulan
  final String userId; // UID pengguna Firebase Auth
  final String email; // Email pengguna
  final String paymentStatus;
  final String midtransOrderId;

  late DateTime endDate; // Tanggal berakhirnya membership

  MemberSchedule({
    required this.key,
    required this.bookingType,
    required this.dayOfWeek,
    required this.endTime,
    required this.fieldId,
    required this.firstDate,
    required this.fullName,
    required this.phoneNumber,
    required this.startTime,
    required this.timestamp,
    required this.validityMonths,
    required this.userId,
    required this.email,
    required this.paymentStatus,
    required this.midtransOrderId,
  }) {
    try {
      DateTime first = DateFormat('yyyy-MM-dd').parse(firstDate);
      // Kalkulasi endDate yang lebih akurat
      int year = first.year;
      int month = first.month + validityMonths;
      int day = first.day;

      while (month > 12) {
        month -= 12;
        year += 1;
      }
      // Cek validitas hari di bulan baru
      int daysInNewMonth = DateTime(year, month + 1, 0).day;
      if (day > daysInNewMonth) {
        day = daysInNewMonth;
      }
      endDate = DateTime(year, month, day);
    } catch (e) {
      endDate = DateTime.now().add(
        Duration(days: validityMonths * 30),
      ); // Fallback
      print(
        "Error parsing firstDate ('$firstDate') in MemberSchedule: $e. Using fallback endDate: $endDate",
      );
    }
  }

  factory MemberSchedule.fromMap(String key, Map<dynamic, dynamic> map) {
    return MemberSchedule(
      key: key,
      bookingType: map['bookingType'] ?? 'member',
      dayOfWeek: (map['dayOfWeek'] as num?)?.toInt() ?? 1,
      endTime: map['endTime'] ?? '00:00',
      fieldId: map['fieldId'] ?? '',
      firstDate: map['firstDate'] ?? '',
      fullName: map['fullName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      startTime: map['startTime'] ?? '00:00',
      timestamp: map['timestamp'] as num? ?? 0,
      validityMonths: (map['validityMonths'] as num?)?.toInt() ?? 0,
      userId: map['userId'] ?? '',
      email: map['email'] ?? '',
      paymentStatus:
          map['payment_status'] ?? 'pending', // Sesuai dengan field di Firebase
      midtransOrderId: map['midtrans_order_id'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookingType': bookingType,
      'dayOfWeek': dayOfWeek,
      'endTime': endTime,
      'fieldId': fieldId,
      'firstDate': firstDate,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'startTime': startTime,
      'timestamp': timestamp,
      'validityMonths': validityMonths,
      'userId': userId,
      'email': email,
      'payment_status': paymentStatus,
      'midtrans_order_id': midtransOrderId,
    };
  }

  bool get isActive {
    DateTime today = DateTime.now();
    DateTime todayDateOnly = DateTime(today.year, today.month, today.day);
    DateTime endDateDateOnly = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );

    return (paymentStatus == 'success' || paymentStatus == 'confirmed') &&
        !todayDateOnly.isAfter(endDateDateOnly);
  }
}
