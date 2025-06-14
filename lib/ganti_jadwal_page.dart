// pages/ganti_jadwal_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:seconddatabase/models/BookingOrder.dart'; // Sesuaikan path jika perlu

class GantiJadwalPage extends StatefulWidget {
  final BookingOrder initialBooking;

  const GantiJadwalPage({Key? key, required this.initialBooking})
      : super(key: key);

  @override
  State<GantiJadwalPage> createState() => _GantiJadwalPageState();
}

class _GantiJadwalPageState extends State<GantiJadwalPage> {
  late BookingOrder _currentBooking;
  late int _originalDurationInHours;
  late String _sportNode; // Untuk path Firebase

  DateTime _selectedNewDate = DateTime.now();
  List<int> _selectedNewHourIndexes = [];
  Map<int, String> _bookedSlotsForNewDate = {}; // Jam -> status ('booked')

  bool _isLoadingData = true; // Untuk fetch jadwal
  bool _isRescheduling = false; // Untuk proses ganti jadwal

  final int _openingHour = 7; // Asumsi jam buka sama untuk semua
  final int _closingHour = 22; // Asumsi jam tutup sama untuk semua

  // Untuk rentang tanggal ganti jadwal (+/- 7 hari dari tanggal booking asli)
  late DateTime _minSelectableDate;
  late DateTime _maxSelectableDate;
  List<DateTime> _availableDatesForReschedule = [];


  @override
  void initState() {
    super.initState();
    _currentBooking = widget.initialBooking;
    _originalDurationInHours = _currentBooking.durationInHours;
    _sportNode = _currentBooking.midtransOrderId.toUpperCase().startsWith('BADMINTON')
        ? 'bookings_badminton'
        : 'bookings_futsal';

    _initializeDateRangeAndSelection();
    _fetchBookedSlotsForNewDate();
  }

  void _initializeDateRangeAndSelection() {
    DateTime originalBookingDate = DateFormat('yyyy-MM-dd').parse(_currentBooking.bookingDate);
    DateTime today = DateTime.now();
    DateTime todayDateOnly = DateTime(today.year, today.month, today.day);

    // Min selectable: maks dari (hari ini ATAU tanggal asli - 7 hari)
    DateTime minRange = originalBookingDate.subtract(const Duration(days: 7));
    _minSelectableDate = todayDateOnly.isAfter(minRange) ? todayDateOnly : minRange;
    
    // Max selectable: tanggal asli + 7 hari
    _maxSelectableDate = originalBookingDate.add(const Duration(days: 7));

    // Generate list tanggal yang bisa dipilih
    _availableDatesForReschedule = [];
    DateTime currentDate = _minSelectableDate;
    while (currentDate.isBefore(_maxSelectableDate.add(const Duration(days: 1)))) { // +1 karena isBefore
        _availableDatesForReschedule.add(currentDate);
        currentDate = currentDate.add(const Duration(days: 1));
    }
    
    // Set tanggal terpilih awal ke tanggal booking asli jika masih valid, jika tidak ke minSelectableDate
    if (originalBookingDate.isAfter(_minSelectableDate.subtract(const Duration(days:1))) && 
        originalBookingDate.isBefore(_maxSelectableDate.add(const Duration(days:1)))) {
      _selectedNewDate = originalBookingDate;
    } else {
      _selectedNewDate = _minSelectableDate;
    }

    // Jika _availableDatesForReschedule kosong (misal karena tanggal original sudah jauh terlewat)
    if(_availableDatesForReschedule.isEmpty && mounted){
        _availableDatesForReschedule.add(todayDateOnly); // Fallback ke hari ini
        _selectedNewDate = todayDateOnly;
    } else if (!_availableDatesForReschedule.contains(_selectedNewDate) && _availableDatesForReschedule.isNotEmpty) {
        _selectedNewDate = _availableDatesForReschedule.first; // Fallback ke tanggal pertama yang tersedia
    }
  }


  Future<void> _fetchBookedSlotsForNewDate() async {
    if (!mounted) return;
    setState(() {
      _isLoadingData = true;
      _bookedSlotsForNewDate.clear();
      _selectedNewHourIndexes.clear(); // Reset pilihan jam saat tanggal berubah
    });

    String formattedNewDate = DateFormat('yyyy-MM-dd').format(_selectedNewDate);
    DatabaseReference bookingPathRef = FirebaseDatabase.instance
        .ref()
        .child(_sportNode)
        .child(_currentBooking.fieldId)
        .child(formattedNewDate);

    try {
      DataSnapshot snapshot = await bookingPathRef.once().then((event) => event.snapshot);
      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> bookings = snapshot.value as Map<dynamic, dynamic>;
        bookings.forEach((key, value) {
          if (value is Map) {
            String paymentStatus = value['payment_status'] ?? 'unknown';
            // Slot dianggap booked jika sukses atau dikonfirmasi, dan BUKAN booking yang sedang diganti ini
            if ((paymentStatus == 'success' || paymentStatus == 'confirmed') && key != _currentBooking.key) {
              String startTime = value['startTime'] ?? '';
              String endTime = value['endTime'] ?? '';
              if (startTime.isNotEmpty && endTime.isNotEmpty) {
                int startHour = int.tryParse(startTime.split(':')[0]) ?? -1;
                int endHour = int.tryParse(endTime.split(':')[0]) ?? -1;
                for (int i = startHour; i < endHour; i++) {
                  _bookedSlotsForNewDate[i] = 'booked';
                }
              }
            }
          }
        });
      }
    } catch (error) {
      print("Error fetching booked slots for new date: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memuat jadwal untuk tanggal baru: $error")),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoadingData = false;
    });
  }

  bool _isSequentialSelection(List<int> selected) {
    if (selected.isEmpty) return false; // Harus ada yang dipilih
    if (selected.length != _originalDurationInHours) return false; // Durasi harus sama
    selected.sort();
    for (int i = 1; i < selected.length; i++) {
      if (selected[i] != selected[i - 1] + 1) return false;
    }
    return true;
  }
  
  String _formatHour(int hour) => "${hour.toString().padLeft(2, '0')}:00";


  Future<void> _confirmReschedule() async {
    if (!_isSequentialSelection(_selectedNewHourIndexes)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Pilih $_originalDurationInHours jam berurutan.")),
      );
      return;
    }

    if (!mounted) return;
    setState(() { _isRescheduling = true; });

    String formattedNewDate = DateFormat('yyyy-MM-dd').format(_selectedNewDate);
    String newStartTime = _formatHour(_selectedNewHourIndexes.first);
    String newEndTime = _formatHour(_selectedNewHourIndexes.last + 1);

    DatabaseReference dbRef = FirebaseDatabase.instance.ref();

    // Path lama dan baru
    String oldPath = '${_sportNode}/${_currentBooking.fieldId}/${_currentBooking.bookingDate}/${_currentBooking.key}';
    String newPath = '${_sportNode}/${_currentBooking.fieldId}/$formattedNewDate/${_currentBooking.key}';

    // Data baru untuk booking
    Map<String, dynamic> newBookingData = {
      'B_id': _currentBooking.midtransOrderId, // B_id (order_id) biasanya tidak berubah
      'bookingDate': formattedNewDate,
      'startTime': newStartTime,
      'endTime': newEndTime,
      'fieldId': _currentBooking.fieldId,
      'gross_amount': _currentBooking.grossAmount, // Asumsi harga tidak berubah
      'key': _currentBooking.key, // Key tetap sama
      'midtrans_order_id': _currentBooking.midtransOrderId,
      'payment_status': _currentBooking.paymentStatus, // Status pembayaran tetap sama
      'userName': _currentBooking.userName,
      'scheduleChangeCount': _currentBooking.scheduleChangeCount - 1, // Kurangi kesempatan
      'timestamp': ServerValue.timestamp, // Update timestamp
      'userId': FirebaseAuth.instance.currentUser?.uid // Simpan juga userId jika ada
    };

    try {
      // Buat operasi multi-path update untuk menghapus lama dan menambah baru secara atomik
      Map<String, dynamic> multiPathUpdate = {
        oldPath: null, // Hapus data lama
        newPath: newBookingData, // Tambah data baru
      };

      await dbRef.update(multiPathUpdate);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Jadwal berhasil diubah!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Kembali dan kirim true untuk refresh
      }
    } catch (error) {
      print("Error rescheduling: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengubah jadwal: $error")),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isRescheduling = false; });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Ganti Jadwal ${widget.initialBooking.sportType}"),
        centerTitle: true,
      ),
      body: _isLoadingData && _availableDatesForReschedule.isEmpty // Loading awal untuk tanggal
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Lapangan: ${widget.initialBooking.fieldDisplayName}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Jadwal Awal: ${widget.initialBooking.formattedDisplayDate}, ${widget.initialBooking.timeRangeDisplay}"),
                  Text("Durasi Booking: $_originalDurationInHours jam"),
                  const SizedBox(height: 20),
                  const Text("Pilih Tanggal Baru:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_availableDatesForReschedule.isNotEmpty)
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _availableDatesForReschedule.length,
                        itemBuilder: (context, index) {
                          DateTime date = _availableDatesForReschedule[index];
                          bool isSelected = DateUtils.isSameDay(_selectedNewDate, date);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedNewDate = date;
                                _fetchBookedSlotsForNewDate();
                              });
                            },
                            child: Container(
                              width: 80,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isSelected ? Colors.blueAccent : Colors.grey),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(DateFormat('dd MMM', 'id_ID').format(date), style: TextStyle(color: isSelected ? Colors.white : Colors.black)),
                                  Text(DateFormat('EEE', 'id_ID').format(date), style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : Colors.black54)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    const Text("Tidak ada tanggal tersedia untuk penggantian jadwal."),
                  
                  const SizedBox(height: 20),
                  const Text("Pilih Jam Baru:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _isLoadingData
                        ? const Center(child: CircularProgressIndicator())
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              childAspectRatio: 2.5,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: _closingHour - _openingHour,
                            itemBuilder: (context, index) {
                              int hour = _openingHour + index;
                              String timeSlot = "${hour.toString().padLeft(2, '0')}:00";
                              bool isBooked = _bookedSlotsForNewDate.containsKey(hour);
                              bool isSelected = _selectedNewHourIndexes.contains(hour);
                              bool isPast = _selectedNewDate.isAtSameMomentAs(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)) && hour < DateTime.now().hour;

                              return ElevatedButton(
                                onPressed: (isBooked || isPast || _isRescheduling)
                                    ? null
                                    : () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedNewHourIndexes.remove(hour);
                                          } else {
                                            // Batasi pemilihan sesuai durasi asli
                                            if (_selectedNewHourIndexes.length < _originalDurationInHours) {
                                              _selectedNewHourIndexes.add(hour);
                                            } else {
                                               ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text("Anda hanya bisa memilih $_originalDurationInHours jam.")),
                                              );
                                            }
                                          }
                                          _selectedNewHourIndexes.sort();
                                        });
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSelected
                                      ? Colors.orange
                                      : isBooked
                                          ? Colors.red[300]
                                          : isPast
                                              ? Colors.grey[400]
                                              : Colors.green[300],
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: isBooked ? Colors.red[200] : Colors.grey[300],
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(timeSlot),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isRescheduling || !_isSequentialSelection(_selectedNewHourIndexes)) ? null : _confirmReschedule,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      child: _isRescheduling
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Konfirmasi Ganti Jadwal", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}