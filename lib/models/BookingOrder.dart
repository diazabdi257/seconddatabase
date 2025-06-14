// lib/models/BookingOrder.dart
import 'package:intl/intl.dart';

class BookingOrder {
  final String bookingDate; // Disimpan sebagai "yyyy-MM-dd"
  final String endTime; // Disimpan sebagai "HH:mm"
  final String fieldId;
  final int grossAmount;
  final String key; // Key unik dari Firebase path
  final String midtransOrderId;
  final String paymentStatus;
  final String startTime; // Disimpan sebagai "HH:mm"
  final num timestamp; // Disimpan sebagai millisecondsSinceEpoch
  final String userName; // Email pengguna
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
    // Logika untuk mendapatkan sportType dan fieldDisplayName dari B_id atau fieldId
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
      // Anda bisa menambahkan logika untuk sport lain jika ada
    } else {
      sportType = 'Olahraga Lain'; // Default jika tidak dikenali
      fieldDisplayName = fieldId;
    }
  }

  factory BookingOrder.fromMap(String key, Map<dynamic, dynamic> map) {
    return BookingOrder(
      key: key,
      bookingDate: map['bookingDate'] ?? '',
      endTime: map['endTime'] ?? '',
      fieldId: map['fieldId'] ?? '',
      grossAmount: (map['gross_amount'] as num?)?.toInt() ?? 0,
      midtransOrderId: map['midtrans_order_id'] ?? '',
      paymentStatus: map['payment_status'] ?? 'unknown',
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
      return bookingDate; // Fallback jika parsing gagal
    }
  }

  String get timeRangeDisplay {
    return "$startTime - $endTime";
  }

  int get durationInHours {
    try {
      // Asumsi startTime dan endTime adalah string "HH:mm"
      final startHour = int.parse(startTime.split(':')[0]);
      final startMinute = int.parse(startTime.split(':')[1]);
      final endHour = int.parse(endTime.split(':')[0]);
      final endMinute = int.parse(endTime.split(':')[1]);

      // Buat objek DateTime dengan tanggal dummy (karena hanya butuh selisih waktu)
      final startDate = DateTime(2000, 1, 1, startHour, startMinute);
      final endDate = DateTime(2000, 1, 1, endHour, endMinute);
      
      final difference = endDate.difference(startDate);
      return difference.inHours > 0 ? difference.inHours : 1;
    } catch (e) {
      print("Error parsing durationInHours: $e");
      return 1; // default 1 jam jika parse gagal
    }
  }
}