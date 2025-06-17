// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'models/BookingOrder.dart'; // Pastikan path ini benar
import 'ganti_jadwal_page.dart'; // Pastikan path ini benar

class PemesananPage extends StatefulWidget {
  const PemesananPage({super.key});

  @override
  State<PemesananPage> createState() => _PemesananPageState();
}

class _PemesananPageState extends State<PemesananPage> {
  List<BookingOrder> _userBookings = [];
  bool _isLoading = true;
  String? _currentUserEmail;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndFetchBookings();
  }

  Future<void> _loadCurrentUserAndFetchBookings() async {
    if (!mounted) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserEmail = prefs.getString('email');
    });

    if (_currentUserEmail != null && _currentUserEmail!.isNotEmpty) {
      _fetchUserBookings();
    } else {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      print("Email pengguna tidak ditemukan di SharedPreferences.");
    }
  }

  Future<void> _fetchUserBookings() async {
    if (_currentUserEmail == null || _currentUserEmail!.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    List<BookingOrder> fetchedBookings = [];
    final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
    List<String> sportNodes = ['bookings_badminton', 'bookings_futsal'];

    try {
      for (String sportNode in sportNodes) {
        DataSnapshot sportSnapshot = await dbRef
            .child(sportNode)
            .once()
            .then((event) => event.snapshot);
        if (sportSnapshot.value != null && sportSnapshot.value is Map) {
          Map<dynamic, dynamic> fieldsData =
              sportSnapshot.value as Map<dynamic, dynamic>;
          fieldsData.forEach((fieldId, datesData) {
            if (datesData is Map) {
              datesData.forEach((dateStr, bookingsMap) {
                if (bookingsMap is Map) {
                  bookingsMap.forEach((bookingKey, bookingDetails) {
                    if (bookingDetails is Map) {
                      final bookingMap =
                          bookingDetails as Map<dynamic, dynamic>;

                      // PERBAIKAN: Logika untuk memeriksa status pembayaran yang lebih baik
                      // Ambil nilai dari kedua kemungkinan field ('status' atau 'payment_status')
                      String statusValue =
                          (bookingMap['status'] ??
                                  bookingMap['payment_status'] ??
                                  '')
                              .toString()
                              .toLowerCase();
                      // Tentukan apakah status tersebut termasuk kondisi "Lunas"
                      bool isPaid =
                          statusValue == 'success' ||
                          statusValue == 'confirmed' ||
                          statusValue == 'capture';

                      // Gunakan kondisi 'isPaid' yang baru
                      if (bookingMap['userName'] == _currentUserEmail &&
                          isPaid) {
                        try {
                          fetchedBookings.add(
                            BookingOrder.fromMap(
                              bookingKey.toString(),
                              bookingMap,
                            ),
                          );
                        } catch (e) {
                          print(
                            "Error parsing booking data for key $bookingKey: $e",
                          );
                        }
                      }
                    }
                  });
                }
              });
            }
          });
        }
      }
      fetchedBookings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (error) {
      print("Error fetching bookings: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Gagal memuat riwayat pemesanan: ${error.toString()}",
            ),
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _userBookings = fetchedBookings;
      _isLoading = false;
    });
  }

  Widget _bookingCardOpsi2({required BookingOrder booking}) {
    Color cardBackgroundColor;
    Color textColor;
    String displayStatus = booking.paymentStatus.toUpperCase();

    // PERBAIKAN: Logika penentuan warna dan status agar lebih konsisten
    String status = booking.paymentStatus.toLowerCase();
    bool isSuccess =
        status == 'success' || status == 'confirmed' || status == 'capture';

    if (isSuccess) {
      cardBackgroundColor = Colors.blue.shade50;
      textColor = Colors.black;
      displayStatus = "BERHASIL";
    } else if (status == 'pending') {
      cardBackgroundColor = Colors.orange.shade50;
      textColor = Colors.orange.shade800;
      displayStatus = "PENDING";
    } else if (status.contains('cancel')) {
      cardBackgroundColor = Colors.red.shade50;
      textColor = Colors.red.shade800;
      displayStatus = "DIBATALKAN";
    } else if (status.contains('error') || status == 'failed') {
      cardBackgroundColor = Colors.red.shade50;
      textColor = Colors.red.shade800;
      displayStatus = "GAGAL";
    } else {
      cardBackgroundColor = Colors.grey.shade100;
      textColor = Colors.grey.shade800;
      displayStatus =
          booking.paymentStatus.isNotEmpty
              ? booking.paymentStatus.toUpperCase()
              : "TIDAK DIKETAHUI";
    }

    bool canReschedule = false;
    try {
      String bookingDateTimeString =
          "${booking.bookingDate} ${booking.startTime}";
      DateTime bookingStartDateTime = DateFormat(
        'yyyy-MM-dd HH:mm',
      ).parse(bookingDateTimeString);

      // PERBAIKAN: Gunakan variabel 'isSuccess' yang sudah dibuat
      if (isSuccess &&
          booking.scheduleChangeCount > 0 &&
          bookingStartDateTime.isAfter(DateTime.now()) &&
          DateTime.now().isBefore(
            bookingStartDateTime.subtract(const Duration(hours: 3)),
          )) {
        canReschedule = true;
      }
    } catch (e) {
      print(
        "Error parsing booking date/time for reschedule check (CardOpsi2): $e",
      );
      canReschedule = false;
    }

    return Card(
      elevation: 1.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: textColor.withOpacity(0.3), width: 1),
      ),
      color: cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${booking.sportType} - ${booking.fieldDisplayName}",
              style: TextStyle(
                fontSize: 17.0,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Status: $displayStatus",
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Divider(height: 16, thickness: 0.5),
            Text(
              "Tanggal: ${booking.formattedDisplayDate}",
              style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.9)),
            ),
            Text(
              "Jam: ${booking.timeRangeDisplay}",
              style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.9)),
            ),
            Text(
              "Harga: Rp ${NumberFormat('#,###', 'id_ID').format(booking.grossAmount)}",
              style: TextStyle(
                fontSize: 14,
                color: textColor.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Kesempatan Ganti Jadwal: ${booking.scheduleChangeCount}x",
              style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.9)),
            ),
            if (canReschedule)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(
                      Icons.edit_calendar_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      "Ganti Jadwal",
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  GantiJadwalPage(initialBooking: booking),
                        ),
                      ).then((value) {
                        if (value == true && mounted) {
                          _loadCurrentUserAndFetchBookings();
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade400,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _userBookings.isEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_toggle_off,
                        color: Colors.grey[400],
                        size: 80,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _currentUserEmail == null
                            ? "Gagal memuat data pengguna."
                            : "Anda belum memiliki riwayat pemesanan.",
                        style: TextStyle(fontSize: 17, color: Colors.grey[700]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
              : RefreshIndicator(
                onRefresh: _fetchUserBookings,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _userBookings.length,
                  itemBuilder: (context, index) {
                    final booking = _userBookings[index];
                    return _bookingCardOpsi2(booking: booking);
                  },
                ),
              ),
    );
  }
}
