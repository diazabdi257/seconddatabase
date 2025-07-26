import 'package:intl/intl.dart';

class MemberSchedule {
  final String key;
  final String bookingType;
  final int dayOfWeek;
  final String endTime;
  final String fieldId;
  final String firstDate;
  final String fullName;
  final String phoneNumber;
  final String startTime;
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
    if (bookingType.toLowerCase() == 'admin') {
      endDate = DateTime.now().add(const Duration(days: 365 * 100));
    } else {
      try {
        DateTime first = DateFormat('yyyy-MM-dd').parse(firstDate);
        int year = first.year;
        int month = first.month + validityMonths;
        int day = first.day;

        while (month > 12) {
          month -= 12;
          year += 1;
        }
        
        int daysInNewMonth = DateTime(year, month + 1, 0).day;
        if (day > daysInNewMonth) {
          day = daysInNewMonth;
        }
        endDate = DateTime(year, month, day);
      } catch (e) {
        endDate = DateTime.now().add(Duration(days: validityMonths * 30)); 
      }
    }
  }

  // --- FUNGSI INI TELAH DIPERBAIKI ---
  factory MemberSchedule.fromMap(String key, Map<dynamic, dynamic> map) {
    // Fungsi helper untuk parsing yang aman
    int _parseDayOfWeek(dynamic dayValue, dynamic fixedDayValue) {
      var valueToParse = dayValue ?? fixedDayValue;
      if (valueToParse == null) return 1; // Default ke Senin jika tidak ada
      if (valueToParse is int) return valueToParse;
      if (valueToParse is String) return int.tryParse(valueToParse) ?? 1;
      return 1;
    }

    return MemberSchedule(
      key: key,
      bookingType: map['bookingType'] ?? 'member',
      // PERBAIKAN: Gunakan fungsi parsing yang aman
      dayOfWeek: _parseDayOfWeek(map['dayOfWeek'], map['fixedDayOfWeek']),
      endTime: map['endTime'] ?? '00:00',
      fieldId: map['fieldId']?.toString() ?? '',
      firstDate: map['firstDate'] ?? '',
      fullName: map['fullName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      startTime: map['startTime'] ?? '00:00',
      timestamp: map['timestamp'] as num? ?? 0,
      validityMonths: (map['validityMonths'] as num?)?.toInt() ?? 0,
      userId: map['userId'] ?? '',
      email: map['email'] ?? '',
      paymentStatus: (map['status'] ?? map['payment_status'] ?? 'pending').toString(),
      midtransOrderId: map['midtrans_order_id'] ?? '',
    );
  }

  bool get isActive {
    if (bookingType.toLowerCase() == 'admin') {
      return true;
    }

    DateTime today = DateTime.now();
    DateTime todayDateOnly = DateTime(today.year, today.month, today.day);
    DateTime endDateDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
    bool isPaid = paymentStatus.toLowerCase() == 'success' || paymentStatus.toLowerCase() == 'confirmed';

    return isPaid && !todayDateOnly.isAfter(endDateDateOnly);
  }
}