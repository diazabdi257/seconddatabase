import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:async'; // Import untuk TimeoutException
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math'; // Diperlukan untuk Random
import 'package:firebase_database/firebase_database.dart';
import 'midtrans/midtranswebview_page.dart'; // Sesuaikan path jika berbeda
import 'models/BookingOrder.dart'; // Impor model BookingOrder Anda

class Lapangan1BadmintonPage extends StatefulWidget {
  const Lapangan1BadmintonPage({Key? key}) : super(key: key);

  @override
  State<Lapangan1BadmintonPage> createState() => _Lapangan1BadmintonPageState();
}

class _Lapangan1BadmintonPageState extends State<Lapangan1BadmintonPage> {
  // --- Parameter Spesifik Lapangan (UBAH INI UNTUK LAPANGAN LAIN) ---
  final String fieldId = 'lapangan1'; //
  final int pricePerHour = 60000; //
  final String sportNodeName = 'bookings_badminton'; // 'bookings_futsal' untuk futsal //
  final String orderPrefix = 'BADMINTON-L1'; // Misal 'FUTSAL-L1' untuk futsal lapangan 1 //
  final String defaultItemIdForPayload = 'B1'; // Misal 'F1' untuk futsal lapangan 1 //
  final String assetImagePath = 'assets/lapangan1badminton.jpg'; //
  final String pageTitle = "Lapangan 1 - Badminton"; //
  // --- Akhir Parameter Spesifik Lapangan ---

  final int openingHour = 7; //
  final int closingHour = 22; //
  bool _isLoading = false; //
  final String _backendUrl =
      'https://diazmidtransbackendtest.netlify.app/api/create-midtrans-transaction'; // URL Backend Anda //

  int selectedDateIndex = 0; //
  List<int> selectedHourIndexes = []; //
  int totalPrice = 0; //
  DateTime? startTime; //
  DateTime? endTime; //
  DateTime? dateBooking; //
  String fullName = ''; //
  String email = ''; //

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref(); //
  Set<int> _bookedHoursForSelectedDate = {}; //
  Set<int> _memberReservedHours = {}; // Untuk menyimpan jadwal member //

  String _generate19RandomChars() { //
    const String chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'; //
    Random rnd = Random(); //
    const int length = 19; //
    return String.fromCharCodes( //
      Iterable.generate( //
        length,
        (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
      ),
    );
  }

  @override
  void initState() { //
    super.initState();
    _getUserDataFromSharedPreferences(); //
    if (getUpcomingDays(21).isNotEmpty) { //
      _fetchBookedAndMemberSlots(getUpcomingDays(21)[selectedDateIndex]); //
    }
  }

  Future<void> _getUserDataFromSharedPreferences() async { //
    SharedPreferences prefs = await SharedPreferences.getInstance(); //
    if (!mounted) return; //
    setState(() { //
      fullName = prefs.getString('fullName') ?? 'Nama Tidak Tersedia'; //
      email = prefs.getString('email') ?? 'Email Tidak Tersedia'; //
    });
  }

  Future<void> _fetchBookedAndMemberSlots(DateTime selectedDate) async {
    if (!mounted) return; //
    setState(() { //
      _isLoading = true; //
      _bookedHoursForSelectedDate.clear(); //
      _memberReservedHours.clear(); //
    });

    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate); //
    String firebaseBookingPath = '$sportNodeName/$fieldId/$formattedDate'; //
    String firebaseMemberPath = 'memberSchedules_badminton'; //

    print('Fetching regular bookings from path: $firebaseBookingPath'); //
    if (sportNodeName == 'bookings_badminton') { //
      print('Fetching member schedules from path: $firebaseMemberPath for fieldId: $fieldId and date: $formattedDate'); //
    }

    try { //
      Set<int> tempBookedHours = {}; //
      Set<int> tempMemberHours = {}; //

      // 1. Fetch booking biasa
      final eventBooking = await _databaseRef.child(firebaseBookingPath).once().timeout(const Duration(seconds: 15)); //
      final snapshotBooking = eventBooking.snapshot; //
      if (snapshotBooking.value != null && snapshotBooking.value is Map) { //
        Map<dynamic, dynamic> bookingsOnDate = snapshotBooking.value as Map<dynamic, dynamic>; //
        bookingsOnDate.forEach((uniqueBookingKey, bookingData) { //
          if (bookingData is Map) { //
            final booking = bookingData; //

            // MODIFIED: Check payment status from mobile app OR website format
            bool isPaymentSuccess = (booking['payment_status'] == 'success' || booking['payment_status'] == 'confirmed') || //
                                    (booking['status'] == 'success'); 

            if (isPaymentSuccess) { //
              String startTimeStr = booking['startTime']?.toString() ?? ''; //
              String endTimeStr = booking['endTime']?.toString() ?? ''; //
              if (startTimeStr.isNotEmpty && endTimeStr.isNotEmpty) { //
                List<String> startParts = startTimeStr.split(':'); //
                List<String> endParts = endTimeStr.split(':'); //
                if (startParts.length == 2 && endParts.length == 2) { //
                  DateTime bookingStartTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, int.tryParse(startParts[0]) ?? 0, int.tryParse(startParts[1]) ?? 0); //
                  DateTime bookingEndTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, int.tryParse(endParts[0]) ?? 0, int.tryParse(endParts[1]) ?? 0); //
                  for (int hour = bookingStartTime.hour; hour < bookingEndTime.hour; hour++) { //
                    tempBookedHours.add(hour); //
                  }
                }
              }
            }
          }
        });
      }

      // 2. Fetch jadwal member (HANYA JIKA SPORTNYA BADMINTON, SESUAIKAN JIKA PERLU UNTUK FUTSAL)
      if (sportNodeName == 'bookings_badminton') { //
        Query memberQuery = _databaseRef.child(firebaseMemberPath).orderByChild('fieldId').equalTo(fieldId); //
        final eventMember = await memberQuery.once().timeout(const Duration(seconds: 15)); //
        final snapshotMember = eventMember.snapshot; //

        if (snapshotMember.value != null && snapshotMember.value is Map) { //
          Map<dynamic, dynamic> memberSchedules = snapshotMember.value as Map<dynamic, dynamic>; //
          memberSchedules.forEach((key, value) { //
            if (value is Map) { //
              final scheduleMap = value as Map<dynamic, dynamic>; //
              String schedulePaymentStatus = scheduleMap['payment_status'] ?? 'pending'; //
              int scheduleDayOfWeek = (scheduleMap['dayOfWeek'] as num?)?.toInt() ?? 0; //
              String scheduleFirstDateStr = scheduleMap['firstDate'] ?? ''; //
              int scheduleValidityMonths = (scheduleMap['validityMonths'] as num?)?.toInt() ?? 0; //
              String scheduleStartTimeStr = scheduleMap['startTime'] ?? ''; //
              String scheduleEndTimeStr = scheduleMap['endTime'] ?? ''; //
              
              bool isActiveMemberSchedule = (schedulePaymentStatus == 'success' || schedulePaymentStatus == 'confirmed'); //

              if (isActiveMemberSchedule && scheduleDayOfWeek == selectedDate.weekday && scheduleFirstDateStr.isNotEmpty) { //
                DateTime firstDate = DateFormat('yyyy-MM-dd').parse(scheduleFirstDateStr); //
                DateTime memberScheduleEndDate = DateTime(firstDate.year, firstDate.month + scheduleValidityMonths, firstDate.day); //

                if (!selectedDate.isBefore(firstDate) && selectedDate.isBefore(memberScheduleEndDate)) { //
                  if (scheduleStartTimeStr.isNotEmpty && scheduleEndTimeStr.isNotEmpty) { //
                     List<String> startParts = scheduleStartTimeStr.split(':'); //
                     List<String> endParts = scheduleEndTimeStr.split(':'); //
                     if (startParts.length == 2 && endParts.length == 2) { //
                        int startHour = int.tryParse(startParts[0]) ?? 0; //
                        // int endHour = int.tryParse(endParts[0]) ?? 0; // Variabel endHour tidak terpakai di loop bawahnya
                        
                        DateTime memberSlotStartTime = DateTime(selectedDate.year,selectedDate.month,selectedDate.day, startHour, int.tryParse(startParts[1])??0); //
                        DateTime memberSlotEndTime = DateTime(selectedDate.year,selectedDate.month,selectedDate.day, int.tryParse(endParts[0])??0, int.tryParse(endParts[1])??0); //

                        for (int hour = memberSlotStartTime.hour; hour < memberSlotEndTime.hour; hour++) { //
                            tempMemberHours.add(hour); //
                        }
                     }
                  }
                }
              }
            }
          });
        }
      }

      if (mounted) { //
        setState(() { //
          _bookedHoursForSelectedDate = tempBookedHours; //
          _memberReservedHours = tempMemberHours; //
        });
      }
    } on TimeoutException catch (_) { //
        print('Error fetching slots: Timeout'); //
        if (mounted) { //
        ScaffoldMessenger.of(context).showSnackBar( //
            const SnackBar(content: Text('Gagal memuat jadwal: Server tidak merespons.'), backgroundColor: Colors.orange), //
        );
        }
    } catch (e) { //
      print('Error fetching slots: $e'); //
      if (mounted) { //
        ScaffoldMessenger.of(context).showSnackBar( //
          SnackBar(content: Text('Gagal memuat jadwal: ${e.toString()}')), //
        );
      }
    } finally { //
      if (mounted) { //
        setState(() { //
          _isLoading = false; //
        });
      }
    }
  }


  Future<void> _saveBookingToFirebase({ //
    required Map<String, dynamic> bookingData, //
    required String fieldIdValue, //
    required String bookingDateValue, //
    required String bookingKeyValue, //
  }) async {
    try { //
      String firebasePath = '$sportNodeName/$fieldIdValue/$bookingDateValue/$bookingKeyValue'; //
      await _databaseRef.child(firebasePath).set(bookingData).timeout(const Duration(seconds:10)); //
      print('Booking data saved to Firebase successfully! Path: $firebasePath'); //
    } on TimeoutException catch(_){ //
       print('Failed to save booking data to Firebase: Timeout'); //
        if (mounted) { //
        ScaffoldMessenger.of(context).showSnackBar( //
            const SnackBar(content: Text('Gagal menyimpan booking: Server tidak merespons'), backgroundColor: Colors.red), //
        );
        }
    } 
    catch (e) { //
      print('Failed to save booking data to Firebase: $e'); //
      if (mounted) { //
        ScaffoldMessenger.of(context).showSnackBar( //
          SnackBar( //
            content: Text('Gagal menyimpan detail booking: ${e.toString()}'), //
            backgroundColor: Colors.red, //
          ),
        );
      }
    }
  }

  Future<void> _initiatePayment() async { //
    print("--- _initiatePayment: START for $fieldId ---"); //
    if (dateBooking == null || startTime == null || endTime == null) { //
      print("_initiatePayment: ERROR - Tanggal/waktu booking belum lengkap."); //
      if (mounted) { /* ... SnackBar ... */ } //
      return; //
    }
    if (email.isEmpty || email == 'Email Tidak Tersedia') { //
      print("_initiatePayment: ERROR - Email pengguna tidak valid."); //
      if (mounted) { /* ... SnackBar ... */ } //
      return; //
    }
    if (totalPrice <= 0) { //
      print("_initiatePayment: ERROR - Total harga tidak valid."); //
      if (mounted) { /* ... SnackBar ... */ } //
      return; //
    }

    if (!mounted) return; //
    setState(() { _isLoading = true; }); //
    print("_initiatePayment: _isLoading set to true."); //

    String pureRandomChars = _generate19RandomChars(); //
    String randomKey = "-$pureRandomChars";  //
    String orderIdForMidtrans = '$orderPrefix-${DateFormat('yyyyMMdd').format(dateBooking!)}$randomKey'; //
    
    String itemNameForPayload = 'Booking ${pageTitle.split(" - ")[0]} (${selectedHourIndexes.length} Jam)'; //

    String formattedStartTimeForBackend = DateFormat('HH:mm').format(startTime!); //
    String formattedEndTimeForBackend = DateFormat('HH:mm').format(endTime!); //
    String formattedDateBookingForBackend = DateFormat('yyyy-MM-dd').format(dateBooking!); //

    String bookingDateForFirebase = DateFormat('yyyy-MM-dd').format(dateBooking!); //
    String startTimeForFirebase = DateFormat('HH:mm').format(startTime!);  //
    String endTimeForFirebase = DateFormat('HH:mm').format(endTime!);      //
    String keyForFirebase = randomKey;  //

    Map<String, dynamic> bookingDataForFirebase = { //
      'B_id': orderIdForMidtrans, //
      'bookingDate': bookingDateForFirebase, //
      'endTime': endTimeForFirebase, //
      'fieldId': fieldId,  //
      'gross_amount': totalPrice, //
      'key': keyForFirebase, //
      'midtrans_order_id': orderIdForMidtrans, //
      'startTime': startTimeForFirebase, //
      'timestamp': ServerValue.timestamp,  //
      'userName': email, //
      'payment_status': 'pending',  //
      'scheduleChangeCount': 1, // Default kesempatan ganti jadwal //
    };
    String firebaseBookingPathForWebView = '$sportNodeName/$fieldId/$bookingDateForFirebase/$randomKey'; //

    try { //
      print("_initiatePayment: Making HTTP POST request to backend: $_backendUrl"); //
      final response = await http.post( //
        Uri.parse(_backendUrl), //
        headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8'}, //
        body: jsonEncode(<String, dynamic>{ //
          'order_id': orderIdForMidtrans, //
          'gross_amount': totalPrice, //
          'user_email': email, //
          'item_id': defaultItemIdForPayload,  //
          'item_name': itemNameForPayload,  //
          'quantityitem': selectedHourIndexes.length,  //
          'priceperitem': pricePerHour,  //
          'start_time_info': formattedStartTimeForBackend,  //
          'end_time_info': formattedEndTimeForBackend,      //
          'booking_date_info': formattedDateBookingForBackend,  //
        }),
      ).timeout(const Duration(seconds: 20)); //
      print("_initiatePayment: Backend response statusCode: ${response.statusCode}"); //

      if (mounted) { //
        if (response.statusCode == 200) { //
          final responseData = jsonDecode(response.body); //
          final String? snapToken = responseData['snapToken']; //
          print("_initiatePayment: SnapToken received: $snapToken"); //

          if (snapToken != null) { //
            print("_initiatePayment: Attempting to save to Firebase..."); //
            await _saveBookingToFirebase( //
              bookingData: bookingDataForFirebase, //
              fieldIdValue: fieldId, //
              bookingDateValue: bookingDateForFirebase, //
              bookingKeyValue: randomKey //
            );
            print("_initiatePayment: Firebase save logic completed. Navigating to WebViewPage..."); //
            Navigator.push( //
              context,
              MaterialPageRoute(builder: (context) => WebViewPage( //
                snapToken: snapToken, //
                firebaseBookingPath: firebaseBookingPathForWebView, //
                )),
            );
          } else {  //
            print("_initiatePayment: ERROR - SnapToken is null."); //
            ScaffoldMessenger.of(context).showSnackBar( //
              const SnackBar(content: Text('Gagal mendapatkan Snap Token dari backend.'), backgroundColor: Colors.red), //
            );
          }
        } else {  //
            print("_initiatePayment: ERROR - Backend responded with ${response.statusCode}. Body: ${response.body}"); //
            final errorData = jsonDecode(response.body); //
            ScaffoldMessenger.of(context).showSnackBar( //
              SnackBar(content: Text('Error dari server: ${errorData['error'] ?? 'Gagal membuat transaksi'}'), backgroundColor: Colors.red), //
            );
        }
      }
    } on TimeoutException catch (e) { //
      print("_initiatePayment: ERROR - TimeoutException: $e"); //
      if (mounted) { //
        ScaffoldMessenger.of(context).showSnackBar( //
          const SnackBar(content: Text('Koneksi ke server timeout. Silakan coba lagi.'), backgroundColor: Colors.red), //
        );
      }
    } catch (e) {  //
      print("_initiatePayment: ERROR - General Exception: $e"); //
      if (mounted) { //
        ScaffoldMessenger.of(context).showSnackBar( //
          SnackBar(content: Text('Terjadi kesalahan: ${e.toString()}'), backgroundColor: Colors.red), //
        );
      }
    } 
    finally {  //
      print("_initiatePayment: FINALLY block. Setting _isLoading to false."); //
      if (mounted) {  //
        setState(() { _isLoading = false; });  //
      } 
    }
    print("--- _initiatePayment: END for $fieldId ---"); //
  }

  List<DateTime> getUpcomingDays(int days) { //
    final today = DateTime.now(); //
    return List.generate(days, (index) => today.add(Duration(days: index))); //
  }

  bool isSequentialSelection(List<int> selected) { //
    if (selected.length <= 1) return true; //
    selected.sort(); //
    for (int i = 1; i < selected.length; i++) { //
      if (selected[i] != selected[i - 1] + 1) return false; //
    }
    return true; //
  }

  void _updateBookingTimesAndDate() { //
    final upcomingDates = getUpcomingDays(21); //
    if (selectedHourIndexes.isNotEmpty) { //
      selectedHourIndexes.sort(); //
      final DateTime selectedDate = upcomingDates[selectedDateIndex]; //
      dateBooking = DateTime(selectedDate.year, selectedDate.month, selectedDate.day); //
      startTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, openingHour + selectedHourIndexes.first); //
      endTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, openingHour + selectedHourIndexes.last + 1); //
    } else { //
      startTime = null; //
      endTime = null; //
      dateBooking = null; //
    }
    if(mounted){ //
      setState(() { //
        totalPrice = pricePerHour * selectedHourIndexes.length; //
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