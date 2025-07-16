import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'midtrans/midtranswebview_page.dart';
import 'models/member_schedule.dart'; // Impor ini mungkin tidak digunakan langsung tapi relevan

class LapanganFutsalPage extends StatefulWidget {
  const LapanganFutsalPage({Key? key}) : super(key: key);

  @override
  State<LapanganFutsalPage> createState() => _LapanganFutsalPageState();
}

class _LapanganFutsalPageState extends State<LapanganFutsalPage> {
  final String fieldId = 'lapangan1';
  final int pricePerHour = 60000;
  final String sportNodeName = 'bookings_futsal';
  final String orderPrefix = 'FUTSAL';
  final String defaultItemIdForPayload = 'F1';
  final String assetImagePath = 'assets/lapanganfutsal.jpg';
  final String pageTitle = "Lapangan 1 - Futsal";

  final int openingHour = 7;
  final int closingHour = 22;
  bool _isLoading = false;
  
  // PERBAIKAN 1: Mengubah URL Backend
  final String _backendUrl =
      'https://booking-gor.site/api/create-midtrans-transaction';

  int selectedDateIndex = 0;
  List<int> selectedHourIndexes = [];
  int totalPrice = 0;
  DateTime? startTime;
  DateTime? endTime;
  DateTime? dateBooking;
  String fullName = '';
  String email = '';
  String phoneNumber = ''; // Tambahkan variabel untuk nomor HP

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  Set<int> _bookedHoursForSelectedDate = {};
  Set<int> _memberReservedHours = {};

  @override
  void initState() {
    super.initState();
    _getUserDataFromSharedPreferences();
    if (getUpcomingDays(21).isNotEmpty) {
      _fetchBookedAndMemberSlots(getUpcomingDays(21)[selectedDateIndex]);
    }
  }

  Future<void> _getUserDataFromSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      fullName = prefs.getString('fullName') ?? 'Nama Tidak Tersedia';
      email = prefs.getString('email') ?? 'Email Tidak Tersedia';
      // Ambil juga nomor telepon dari SharedPreferences
      phoneNumber = prefs.getString('phoneNumber') ?? '';
    });
  }

  // ... (Fungsi _fetchBookedAndMemberSlots tidak berubah)
  Future<void> _fetchBookedAndMemberSlots(DateTime selectedDate) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _bookedHoursForSelectedDate.clear();
      _memberReservedHours.clear();
    });

    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
    String firebaseBookingPath = '$sportNodeName/$fieldId/$formattedDate';
    String firebaseMemberPath = 'memberSchedules_futsal';

    try {
      Set<int> tempBookedHours = {};
      Set<int> tempMemberHours = {};

      // 1. Fetch booking biasa
      final eventBooking = await _databaseRef
          .child(firebaseBookingPath)
          .once()
          .timeout(const Duration(seconds: 15));
      final snapshotBooking = eventBooking.snapshot;
      if (snapshotBooking.value != null && snapshotBooking.value is Map) {
        Map<dynamic, dynamic> bookingsOnDate =
            snapshotBooking.value as Map<dynamic, dynamic>;
        bookingsOnDate.forEach((uniqueBookingKey, bookingData) {
          if (bookingData is Map) {
            final booking = bookingData;
            String status =
                (booking['status'] ?? booking['payment_status'] ?? '')
                    .toString()
                    .toLowerCase();

            if (status == 'success' ||
                status == 'confirmed' ||
                status == 'capture') {
              String startTimeStr = booking['startTime']?.toString() ?? '';
              String endTimeStr = booking['endTime']?.toString() ?? '';

              if (startTimeStr.isNotEmpty && endTimeStr.isNotEmpty) {
                try {
                  DateTime bookingStartTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, int.parse(startTimeStr.split(':')[0]));
                  DateTime bookingEndTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, int.parse(endTimeStr.split(':')[0]));
                  for (int hour = bookingStartTime.hour; hour < bookingEndTime.hour; hour++) {
                    tempBookedHours.add(hour);
                  }
                } catch (e) {
                  print("Could not parse time for booking $uniqueBookingKey. Error: $e");
                }
              }
            }
          }
        });
      }

      // 2. Fetch jadwal member
      Query memberQuery = _databaseRef.child(firebaseMemberPath).orderByChild('fieldId').equalTo(fieldId);
      final eventMember = await memberQuery.once().timeout(const Duration(seconds: 15));
      final snapshotMember = eventMember.snapshot;

      if (snapshotMember.value != null && snapshotMember.value is Map) {
          Map<dynamic, dynamic> memberSchedules = snapshotMember.value as Map<dynamic, dynamic>;
          memberSchedules.forEach((key, value) {
              if (value is Map) {
                  final scheduleMap = value as Map<dynamic, dynamic>;
                  
                  String bookingType = (scheduleMap['bookingType'] ?? '').toString().toLowerCase();
                  String status = (scheduleMap['status'] ?? scheduleMap['payment_status'] ?? '').toString().toLowerCase();
                  bool isPaid = status == 'success' || status == 'confirmed';
                  bool isActiveMemberSchedule = (bookingType == 'admin' || isPaid);

                  if (isActiveMemberSchedule) {
                      int scheduleDayOfWeek = (scheduleMap['dayOfWeek'] as num?)?.toInt() ?? 0;

                      int dayOfWeekFromDB = scheduleDayOfWeek;
                      if (dayOfWeekFromDB == 0) {
                          dayOfWeekFromDB = 7; 
                      }
                      
                      if (dayOfWeekFromDB == selectedDate.weekday) {
                          String firstDateStr = scheduleMap['firstDate'] ?? '';
                          int validityMonths = (scheduleMap['validityMonths'] as num?)?.toInt() ?? 0;

                          if (firstDateStr.isNotEmpty && validityMonths > 0) {
                              try {
                                  DateTime firstDate = DateFormat('yyyy-MM-dd').parse(firstDateStr);
                                  DateTime memberScheduleEndDate = DateTime(firstDate.year, firstDate.month + validityMonths, firstDate.day);

                                  if (!selectedDate.isBefore(firstDate) && selectedDate.isBefore(memberScheduleEndDate)) {
                                      String scheduleStartTimeStr = scheduleMap['startTime'] ?? '';
                                      String scheduleEndTimeStr = scheduleMap['endTime'] ?? '';

                                      if (scheduleStartTimeStr.isNotEmpty && scheduleEndTimeStr.isNotEmpty) {
                                          int startHour = int.parse(scheduleStartTimeStr.split(':')[0]);
                                          int endHour = int.parse(scheduleEndTimeStr.split(':')[0]);

                                          for (int hour = startHour; hour < endHour; hour++) {
                                              tempMemberHours.add(hour);
                                          }
                                      }
                                  }
                              } catch (e) {
                                  print("Error parsing member schedule date for key $key: $e");
                              }
                          }
                      }
                  }
              }
          });
      }

      if (mounted) {
        setState(() {
          _bookedHoursForSelectedDate = tempBookedHours;
          _memberReservedHours = tempMemberHours;
        });
      }
    } catch (e) {
      print('Error fetching slots: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  // --- PERBAIKAN 2: Mengubah struktur body JSON pada fungsi ini ---
  Future<void> _initiatePayment() async {
    if (dateBooking == null ||
        startTime == null ||
        endTime == null ||
        email.isEmpty) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    String formattedDateForPath = DateFormat('yyyy-MM-dd').format(dateBooking!);
    DatabaseReference newBookingRef =
        _databaseRef
            .child(sportNodeName)
            .child(fieldId)
            .child(formattedDateForPath)
            .push();

    String firebaseKey = newBookingRef.key!;
    String dateForOrderId = DateFormat('yyyyMMdd').format(dateBooking!);
    String orderIdForMidtrans = '$orderPrefix-$dateForOrderId$firebaseKey';

    String itemName = 'Sewa ${pageTitle.split(" - ").join(" ")} (${selectedHourIndexes.length} Jam)';
    
    // Menyusun item_details
    List<Map<String, dynamic>> itemDetails = [
      {
        "id": defaultItemIdForPayload,
        "price": pricePerHour,
        "quantity": selectedHourIndexes.length,
        "name": itemName
      }
    ];

    // Menyusun customer_details
    Map<String, String> customerDetails = {
      "first_name": fullName.split(' ').first,
      "last_name": fullName.split(' ').length > 1 ? fullName.split(' ').sublist(1).join(' ') : "",
      "email": email,
      "phone": phoneNumber
    };

    // Menyusun body JSON yang baru
    Map<String, dynamic> transactionData = {
      "order_id": orderIdForMidtrans,
      "gross_amount": totalPrice,
      "user_email": email,
      "item_details": itemDetails,
      "customer_details": customerDetails
    };

    Map<String, dynamic> bookingDataForFirebase = {
      'bookingDate': formattedDateForPath,
      'endTime': DateFormat('HH:mm').format(endTime!),
      'fieldId': fieldId,
      'fullName': fullName,
      'gross_amount': totalPrice,
      'key': firebaseKey,
      'midtrans_order_id': orderIdForMidtrans,
      'phoneNumber': phoneNumber,
      'scheduleChangeCount': 1,
      'startTime': DateFormat('HH:mm').format(startTime!),
      'status': 'pending',
      'timestamp': ServerValue.timestamp,
      'userName': email,
    };

    try {
      final response = await http
          .post(
            Uri.parse(_backendUrl),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(transactionData), // Mengirim body JSON yang baru
          )
          .timeout(const Duration(seconds: 20));

      if (mounted) {
        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          final String? snapToken = responseData['snapToken'];
          if (snapToken != null) {
            await newBookingRef.set(bookingDataForFirebase).timeout(const Duration(seconds:10));
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => WebViewPage(
                      snapToken: snapToken,
                      firebaseBookingPath: newBookingRef.path,
                    ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gagal mendapatkan token pembayaran.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          final errorData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error dari server: ${errorData['error'] ?? 'Gagal membuat transaksi'}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan koneksi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ... (Sisa kode tidak berubah)
  List<DateTime> getUpcomingDays(int days) {
    final today = DateTime.now();
    return List.generate(days, (index) => today.add(Duration(days: index)));
  }

  bool isSequentialSelection(List<int> selected) {
    if (selected.length <= 1) return true;
    selected.sort();
    for (int i = 1; i < selected.length; i++) {
      if (selected[i] != selected[i - 1] + 1) return false;
    }
    return true;
  }

  void _updateBookingTimesAndDate() {
    final upcomingDates = getUpcomingDays(21);
    if (selectedHourIndexes.isNotEmpty) {
      selectedHourIndexes.sort();
      final DateTime selectedDate = upcomingDates[selectedDateIndex];
      dateBooking = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
      startTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        openingHour + selectedHourIndexes.first,
      );
      endTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        openingHour + selectedHourIndexes.last + 1,
      );
    } else {
      startTime = null;
      endTime = null;
      dateBooking = null;
    }
    if (mounted) {
      setState(() {
        totalPrice = pricePerHour * selectedHourIndexes.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) { //
    final upcomingDates = getUpcomingDays(21); //
    final DateTime now = DateTime.now(); //

    return Scaffold( //
      backgroundColor: Colors.white, //
      appBar: AppBar( //
        backgroundColor: Colors.white, //
        elevation: 0, //
        leading: IconButton( //
          icon: const Icon(Icons.arrow_back, color: Colors.black), //
          onPressed: () => Navigator.pop(context), //
        ),
        title: Text(pageTitle, style: const TextStyle(color: Colors.black)), // Menggunakan pageTitle //
        centerTitle: true, //
      ),
      body: SafeArea( //
        child: SingleChildScrollView( //
          padding: const EdgeInsets.all(20), //
          child: Column( //
            crossAxisAlignment: CrossAxisAlignment.start, //
            children: [ //
              ClipRRect(  //
                borderRadius: BorderRadius.circular(12), //
                child: Image.asset( // Menggunakan assetImagePath //
                  assetImagePath, //
                  height: 180, //
                  width: double.infinity, //
                  fit: BoxFit.cover, //
                ),
              ),
              const SizedBox(height: 10), //
              Text(  //
                "Rp ${NumberFormat('#,###').format(pricePerHour)} / jam", //
                style: const TextStyle(fontSize: 16, color: Colors.black), //
              ),
              const SizedBox(height: 20), //
              const Text("Pilih Tanggal:", style: TextStyle(color: Colors.black, fontSize: 16)), //
              const SizedBox(height: 10), //
              SizedBox(  //
                height: 80, //
                child: ListView.builder( //
                  scrollDirection: Axis.horizontal, //
                  itemCount: upcomingDates.length, //
                  itemBuilder: (context, index) { //
                    final date = upcomingDates[index]; //
                    final isSelectedDate = selectedDateIndex == index; //
                    return GestureDetector( //
                      onTap: () { //
                        if (!mounted) return; //
                        setState(() { //
                          selectedDateIndex = index; //
                          selectedHourIndexes.clear(); //
                          _updateBookingTimesAndDate(); //
                          _fetchBookedAndMemberSlots(upcomingDates[selectedDateIndex]); // Fetch untuk tanggal baru //
                        });
                      },
                      child: Container(  //
                        width: 60, //
                        margin: const EdgeInsets.symmetric(horizontal: 5), //
                        padding: const EdgeInsets.all(8), //
                        decoration: BoxDecoration( //
                          color: isSelectedDate ? Colors.blue : Colors.grey, //
                          borderRadius: BorderRadius.circular(12), //
                        ),
                        child: Column( //
                          mainAxisAlignment: MainAxisAlignment.center, //
                          children: [ //
                            Text( //
                              DateFormat('E', 'id_ID').format(date), //
                              style: TextStyle( //
                                color: isSelectedDate ? Colors.white : Colors.black, //
                                fontWeight: FontWeight.bold, //
                              ),
                            ),
                            const SizedBox(height: 5), //
                            Text( //
                              date.day.toString(), //
                              style: TextStyle( //
                                color: isSelectedDate ? Colors.white : Colors.black, //
                                fontSize: 16, //
                                fontWeight: FontWeight.bold, //
                              ),
                            ),
                          ],
                        ),
                       ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20), //
              const Text("Pilih Jam:", style: TextStyle(color: Colors.black, fontSize: 16)), //
              const SizedBox(height: 10), //
              if (_isLoading && selectedHourIndexes.isEmpty)  //
                const Center(child: Padding( //
                  padding: EdgeInsets.all(16.0), //
                  child: CircularProgressIndicator(), //
                ))
              else
                Wrap( //
                spacing: 10, //
                runSpacing: 10, //
                children: List.generate(closingHour - openingHour + 1, (idx) {  //
                  final hour = openingHour + idx;  //
                  final isCurrentlySelected = selectedHourIndexes.contains(idx);  //
                  
                  final DateTime currentSelectedDate = upcomingDates[selectedDateIndex]; //
                  final DateTime slotDateTime = DateTime( //
                    currentSelectedDate.year, //
                    currentSelectedDate.month, //
                    currentSelectedDate.day, //
                    hour, //
                  );

                  bool isPastSlot = false; //
                  if (currentSelectedDate.year == now.year && //
                      currentSelectedDate.month == now.month && //
                      currentSelectedDate.day == now.day && //
                      slotDateTime.isBefore(now)) { //
                    isPastSlot = true; //
                  }

                  bool isBookedByOthers = _bookedHoursForSelectedDate.contains(hour); //
                  bool isReservedByMember = _memberReservedHours.contains(hour); //
                  bool isSlotDisabled = isPastSlot || isBookedByOthers || isReservedByMember; //

                  return GestureDetector( //
                    onTap: isSlotDisabled //
                        ? null
                        : () { //
                            if (!mounted) return; //
                            setState(() { //
                              if (isCurrentlySelected) { //
                                selectedHourIndexes.remove(idx); //
                              } else { //
                                selectedHourIndexes.add(idx); //
                              }
                              if (!isSequentialSelection(List.from(selectedHourIndexes))) { //
                                selectedHourIndexes.remove(idx);  //
                                if(mounted){ //
                                  ScaffoldMessenger.of(context).showSnackBar( //
                                    const SnackBar( //
                                      content: Text("Pilih jam secara berurutan!"), //
                                      backgroundColor: Colors.red, //
                                    ),
                                  );
                                }
                              }
                              _updateBookingTimesAndDate(); //
                            });
                          },
                    child: Container( //
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), //
                      decoration: BoxDecoration( //
                        color: isReservedByMember  //
                               ? Colors.purple.shade200 // Warna untuk slot member //
                               : isBookedByOthers //
                                 ? Colors.red.shade400  //
                                 : isPastSlot //
                                     ? Colors.grey.shade300 //
                                     : (isCurrentlySelected ? Colors.lightBlue : Colors.grey), //
                        borderRadius: BorderRadius.circular(10), //
                      ),
                      child: Text( //
                        "${hour.toString().padLeft(2, '0')}:00", //
                        style: TextStyle( //
                          color: (isReservedByMember || isBookedByOthers) //
                                 ? Colors.white  //
                                 : isPastSlot //
                                     ? Colors.grey.shade500 //
                                     : (isCurrentlySelected ? Colors.white : Colors.black), //
                          fontWeight: FontWeight.bold, //
                          decoration: isPastSlot && !isBookedByOthers && !isReservedByMember  //
                                      ? TextDecoration.lineThrough  //
                                      : null, //
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 30), //
              Container(  //
                padding: const EdgeInsets.all(16), //
                decoration: BoxDecoration( //
                  color: Colors.white, //
                  borderRadius: BorderRadius.circular(12), //
                  boxShadow: [ //
                    BoxShadow( //
                      color: Colors.black.withOpacity(0.1), //
                      blurRadius: 6, //
                      offset: const Offset(0, 3), //
                    ),
                  ],
                ),
                child: Row( //
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, //
                  children: [ //
                    const Text( //
                      "Total Bayar:", //
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), //
                    ),
                    Text( //
                      "Rp ${NumberFormat('#,###').format(totalPrice)} ,-", //
                      style: const TextStyle( //
                        fontSize: 18, //
                        fontWeight: FontWeight.bold, //
                        color: Colors.green, //
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10), //
              if (dateBooking != null && startTime != null && endTime != null)  //
                Padding( //
                  padding: const EdgeInsets.symmetric(vertical: 8.0), //
                  child: Column( //
                    crossAxisAlignment: CrossAxisAlignment.start, //
                    children: [ //
                      Text( //
                        "Tanggal: ${DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(dateBooking!)}", //
                        style: const TextStyle( //
                          fontSize: 16, //
                          fontWeight: FontWeight.normal, //
                        ),
                      ),
                      const SizedBox(height: 4), //
                      Text( //
                        "Waktu: ${DateFormat('HH:mm').format(startTime!)} - ${DateFormat('HH:mm').format(endTime!)}", //
                        style: const TextStyle( //
                          fontSize: 16, //
                          fontWeight: FontWeight.normal, //
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20), //
              SizedBox(  //
                width: double.infinity, //
                child: ElevatedButton( //
                  onPressed: //
                      (selectedHourIndexes.isNotEmpty && //
                              isSequentialSelection(List.from(selectedHourIndexes)) && //
                              !_isLoading) //
                          ? _initiatePayment  //
                          : null,  //
                  style: ElevatedButton.styleFrom( //
                    backgroundColor: Colors.lightBlue, //
                    padding: const EdgeInsets.symmetric(vertical: 15), //
                    shape: RoundedRectangleBorder( //
                      borderRadius: BorderRadius.circular(10), //
                    ),
                  ),
                  child: _isLoading && selectedHourIndexes.isNotEmpty  //
                      ? const SizedBox( //
                          height: 20, //
                          width: 20, //
                          child: CircularProgressIndicator( //
                            color: Colors.white, //
                            strokeWidth: 3, //
                          ),
                        )
                      : const Text( //
                          "Konfirmasi & Bayar", //
                          style: TextStyle(fontSize: 16, color: Colors.white), //
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}