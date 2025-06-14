// lib/models/member_schedule.dart
import 'package:intl/intl.dart';

class MemberSchedule {
  final String key; // Kunci unik Firebase
  final String bookingType;
  final int dayOfWeek; // 1 (Senin) - 7 (Minggu)
  final String endTime; // "HH:mm"
  final String fieldId;
  final String firstDate; // "yyyy-MM-dd", tanggal mulai membership
  final String fullName;
  final String phoneNumber;
  final String startTime; // "HH:mm"
  final num timestamp;
  final int validityMonths;
  final String userId;
  final String email;
  final String paymentStatus;
  final String midtransOrderId;

  late DateTime endDate;

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
      endDate = DateTime(first.year, first.month + validityMonths, first.day);
    } catch (e) {
      // Fallback jika parsing gagal, meskipun idealnya firstDate selalu valid
      endDate = DateTime.now().add(Duration(days: validityMonths * 30));
      print("Error parsing firstDate in MemberSchedule: $firstDate, Error: $e");
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
      paymentStatus: map['paymentStatus'] ?? // Perbaikan: Nama field di Firebase adalah payment_status
          map['payment_status'] ??
          'pending', // Sesuaikan dengan nama field di Firebase
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
      'timestamp': timestamp, // Saat membuat baru, ini bisa diisi ServerValue.timestamp
      'validityMonths': validityMonths,
      'userId': userId,
      'email': email,
      'payment_status': paymentStatus, // Sesuaikan dengan nama field di Firebase
      'midtrans_order_id': midtransOrderId,
    };
  }

  bool get isActive {
    return (paymentStatus == 'success' || paymentStatus == 'confirmed') &&
        DateTime.now().isBefore(endDate);
  }
}