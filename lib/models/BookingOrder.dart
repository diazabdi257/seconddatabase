// lib/models/BookingOrder.dart
import 'package:intl/intl.dart';

class BookingOrder {
  final String bookingDate;
  final String endTime;
  final String fieldId;
  final int grossAmount;
  final String key;
  final String midtransOrderId;
  final String paymentStatus;
  final String startTime;
  final num timestamp;
  final String userName;
  final int scheduleChangeCount;

  // Derived properties
  late String sportType;
  late String fieldDisplayName;

  BookingOrder({
    required this.bookingDate,
    required this.endTime,
    required this.fieldId,
    required this.grossAmount,
    required this.key,
    required this.midtransOrderId,
    required this.paymentStatus,
    required this.startTime,
    required this.timestamp,
    required this.userName,
    required this.scheduleChangeCount,
  }) {
    if (midtransOrderId.toUpperCase().startsWith('BADMINTON')) {
      sportType = 'Badminton';
      fieldDisplayName = fieldId.replaceFirstMapped(
        RegExp(r'lapangan(\d+)'),
        (match) => 'Lapangan ${match.group(1)}',
      );
    } else if (midtransOrderId.toUpperCase().startsWith('FUTSAL')) {
      sportType = 'Futsal';
      fieldDisplayName = fieldId.replaceFirstMapped(
        RegExp(r'lapangan(\d+)'),
        (match) => 'Lapangan ${match.group(1)}',
      );
    } else {
      sportType = 'Olahraga Lain';
      fieldDisplayName = fieldId;
    }
  }

  factory BookingOrder.fromMap(String key, Map<dynamic, dynamic> map) {
    return BookingOrder(
      key: key,
      bookingDate: map['bookingDate'] ?? '',
      endTime: map['endTime'] ?? '',
      fieldId: map['fieldId']?.toString() ?? '',
      grossAmount: (map['gross_amount'] as num?)?.toInt() ?? 0,
      midtransOrderId: map['midtrans_order_id'] ?? '',

      // PERBAIKAN UTAMA DI SINI:
      // Membaca field 'status' DULU, jika tidak ada baru 'payment_status'.
      // Jika keduanya tidak ada, baru default ke 'unknown'.
      paymentStatus:
          (map['status'] ?? map['payment_status'] ?? 'unknown').toString(),

      startTime: map['startTime'] ?? '',
      timestamp: map['timestamp'] as num? ?? 0,
      userName: map['userName'] ?? '',
      scheduleChangeCount: (map['scheduleChangeCount'] as num?)?.toInt() ?? 0,
    );
  }

  String get formattedDisplayDate {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(bookingDate);
      return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
    } catch (e) {
      print("Error parsing date for display: $bookingDate - $e");
      return bookingDate;
    }
  }

  String get timeRangeDisplay {
    return "$startTime - $endTime";
  }

  int get durationInHours {
    try {
      final startHour = int.parse(startTime.split(':')[0]);
      final startMinute = int.parse(startTime.split(':')[1]);
      final endHour = int.parse(endTime.split(':')[0]);
      final endMinute = int.parse(endTime.split(':')[1]);

      final startDate = DateTime(2000, 1, 1, startHour, startMinute);
      final endDate = DateTime(2000, 1, 1, endHour, endMinute);

      final difference = endDate.difference(startDate);
      return difference.inHours > 0 ? difference.inHours : 1;
    } catch (e) {
      print("Error parsing durationInHours: $e");
      return 1;
    }
  }
}
