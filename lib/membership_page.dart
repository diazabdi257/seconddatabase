import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http; // Untuk HTTP request
import 'dart:convert'; // Untuk jsonEncode
import 'dart:async'; // Untuk TimeoutException
import 'dart:math'; // Untuk Random

import 'models/member_schedule.dart'; // PASTIKAN PATH INI BENAR
import 'midtrans/midtranswebview_page.dart'; // PASTIKAN PATH INI BENAR

class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});

  @override
  _MembershipPageState createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  String _fullName = '';
  String _email = '';
  String _phoneNumber = '';
  User? _currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  MemberSchedule? _activeMemberSchedule;
  bool _isLoadingPage = true; // Loading untuk data awal halaman
  bool _isRegisteringMembership = false; // Loading untuk proses pendaftaran
  bool _isLoadingScheduleForSelectedDay = false; // Loading saat cek jadwal member

  // Untuk form pendaftaran member baru
  int _selectedDurationMonths = 1;
  int? _selectedDayOfWeek;
  int? _selectedStartHour;
  final int _bookingDurationHours = 3;
  String? _selectedFieldId;

  Set<int> _unavailableMemberStartHours = {}; // Jam mulai yang sudah diambil member lain

  final List<Map<String, String>> _badmintonFields = [
    {'id': 'lapangan1', 'name': 'Lapangan 1'},
    {'id': 'lapangan2', 'name': 'Lapangan 2'},
    {'id': 'lapangan3', 'name': 'Lapangan 3'},
    {'id': 'lapangan4', 'name': 'Lapangan 4'},
  ];

  final int _memberOpeningHour = 7;
  final int _memberLatestStartHour = 22 - 3; // Jam 19:00

  @override
  void initState() {
    super.initState();
    _loadUserDataAndMembership();
  }

  Future<void> _loadUserDataAndMembership() async {
    if (!mounted) return;
    setState(() { _isLoadingPage = true; });

    _currentUser = FirebaseAuth.instance.currentUser;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _fullName = prefs.getString('fullName') ?? 'Nama Tidak Tersedia';
    _email = prefs.getString('email') ?? _currentUser?.email ?? 'Email Tidak Tersedia';
    _phoneNumber = prefs.getString('phoneNumber') ?? '';

    if (_currentUser != null) {
      await _fetchActiveMembership();
    }

    if (!mounted) return;
    setState(() { _isLoadingPage = false; });
  }

  Future<void> _fetchActiveMembership() async {
    if (_currentUser == null) return;

    Query query = _dbRef
        .child('memberSchedules_badminton')
        .orderByChild('userId')
        .equalTo(_currentUser!.uid);

    try {
      DataSnapshot snapshot = await query.once().then((event) => event.snapshot);
      MemberSchedule? foundSchedule;

      if (snapshot.value != null && snapshot.value is Map) {
        Map<dynamic, dynamic> schedules = snapshot.value as Map<dynamic, dynamic>;
        for (var entry in schedules.entries) {
          if (entry.value is Map) {
            final schedule = MemberSchedule.fromMap(entry.key, entry.value as Map<dynamic, dynamic>);
            if (schedule.isActive) {
              foundSchedule = schedule;
              break; 
            }
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _activeMemberSchedule = foundSchedule;
      });
    } catch (e) {
      print("Error fetching active membership: $e");
       if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memuat data membership: ${e.toString()}"))
        );
      }
    }
  }
  
  Future<void> _fetchUnavailableMemberSlots() async {
    if (_selectedFieldId == null || _selectedDayOfWeek == null || !mounted) {
      setState(() => _unavailableMemberStartHours.clear());
      return;
    }

    setState(() {
      _isLoadingScheduleForSelectedDay = true;
      _unavailableMemberStartHours.clear();
    });

    print("Fetching unavailable member slots for Field: $_selectedFieldId, Day: $_selectedDayOfWeek");

    try {
      Query query = _dbRef
          .child('memberSchedules_badminton') // Hanya cek di badminton karena membership hanya untuk badminton
          .orderByChild('fieldId')
          .equalTo(_selectedFieldId);

      DataSnapshot snapshot = await query.once().then((event) => event.snapshot);
      Set<int> tempUnavailableHours = {};

      if (snapshot.value != null && snapshot.value is Map) {
        Map<dynamic, dynamic> schedules = snapshot.value as Map<dynamic, dynamic>;
        schedules.forEach((key, value) {
          if (value is Map) {
            final schedule = MemberSchedule.fromMap(key, value as Map<dynamic, dynamic>);
            if (schedule.isActive && 
                schedule.dayOfWeek == _selectedDayOfWeek &&
                schedule.fieldId == _selectedFieldId && // Double check fieldId
                (schedule.userId != _currentUser?.uid || _activeMemberSchedule == null)) { // Jangan blok jadwal sendiri jika sedang edit (belum diimplementasikan edit)
              
              try {
                int scheduleStartHour = int.parse(schedule.startTime.split(':')[0]);
                // int scheduleEndHour = int.parse(schedule.endTime.split(':')[0]);

                // Logika untuk menentukan jam mulai yang tidak bisa dipilih oleh member baru.
                // Member baru memerlukan slot kosong sepanjang _bookingDurationHours (3 jam).
                // Jika ada member lain yang jadwalnya (S hingga E), maka member baru tidak bisa memilih jam mulai J
                // dimana slot [J, J+1, J+2] akan tumpang tindih dengan [S, S+1, ..., E-1].
                // Ini berarti J tidak boleh S-2, S-1, S, S+1, ..., E-1.
                // Atau cara lain: jam mulai S dari member lain memblokir S, S-1, S-2 untuk dipilih sebagai jam mulai baru.
                
                // Jam mulai yang TIDAK BISA DIPILIH oleh pendaftar baru
                // karena akan bentrok dengan jadwal member lain (scheduleStartHour)
                for(int i=0; i < _bookingDurationHours; i++){
                    if(scheduleStartHour - i >= _memberOpeningHour){
                        tempUnavailableHours.add(scheduleStartHour - i);
                    }
                }
                // Juga, jam mulai yang berada di dalam rentang jadwal member lain
                for(int i=1; i < _bookingDurationHours; i++){ // i=1 karena startHour sudah di-cover di atas
                    if(scheduleStartHour + i < _memberLatestStartHour + _bookingDurationHours){ // Pastikan tidak melebihi jam operasional efektif
                         tempUnavailableHours.add(scheduleStartHour + i);
                    }
                }


              } catch (e) {
                  print("Error parsing time for member schedule check: $e");
              }
            }
          }
        });
      }
      if (mounted) {
        setState(() {
          _unavailableMemberStartHours = tempUnavailableHours;
          print("Unavailable member start hours: $_unavailableMemberStartHours");
        });
      }
    } catch (e) {
      print("Error fetching unavailable member slots: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memeriksa ketersediaan jadwal member: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoadingScheduleForSelectedDay = false; });
      }
    }
  }


  String _dayOfWeekToString(int day) {
    const days = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"];
    if (day >=1 && day <=7) return days[day - 1];
    return "Tidak Valid";
  }
  
  String _generateRandomKey(int length) {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
      final random = Random();
      return String.fromCharCodes(
        Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
      );
  }

  Future<void> _processMembershipRegistration() async {
    if (_currentUser == null ||
        _selectedDayOfWeek == null ||
        _selectedStartHour == null ||
        _selectedFieldId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua pilihan untuk mendaftar member.')),
      );
      return;
    }
    
    if ((_selectedStartHour! + _bookingDurationHours) > 22) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Jam yang dipilih melebihi jam operasional GOR untuk durasi 3 jam.')),
         );
         return;
    }

    // Validasi tambahan: Cek apakah slot yang dipilih sudah diambil member lain
    if (_unavailableMemberStartHours.contains(_selectedStartHour!)) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Jadwal dan jam yang dipilih sudah diambil oleh member lain. Silakan pilih jadwal lain.'), backgroundColor: Colors.orange),
        );
        return;
    }

    if(!mounted) return;
    setState(() { _isRegisteringMembership = true; });

    final String randomFirebaseKey = "-${_generateRandomKey(19)}";
    final String firstDateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    final String shortFieldId = _selectedFieldId!.replaceFirst('lapangan', 'L');
    final String dateForOrderId = DateFormat('yyMMdd').format(DateTime.now());
    final String shortRandomSuffix = _generateRandomKey(10);
    final String orderId = 'MBR-B$shortFieldId-$dateForOrderId-$shortRandomSuffix';

    final int grossAmount = 300000 * _selectedDurationMonths;

    final newMemberSchedule = MemberSchedule(
      key: randomFirebaseKey, 
      bookingType: 'member',
      dayOfWeek: _selectedDayOfWeek!,
      startTime: "${_selectedStartHour!.toString().padLeft(2, '0')}:00",
      endTime: "${(_selectedStartHour! + _bookingDurationHours).toString().padLeft(2, '0')}:00",
      fieldId: _selectedFieldId!,
      firstDate: firstDateStr,
      fullName: _fullName,
      phoneNumber: _phoneNumber,
      timestamp: 0, 
      validityMonths: _selectedDurationMonths,
      userId: _currentUser!.uid,
      email: _email,
      paymentStatus: 'pending_membership_payment',
      midtransOrderId: orderId,
    );
    
    String firebaseMembershipPath = 'memberSchedules_badminton/$randomFirebaseKey'; 
    
    Map<String, dynamic> dataToSave = newMemberSchedule.toMap();
    dataToSave['timestamp'] = ServerValue.timestamp;

    try {
      final response = await http.post(
        Uri.parse('https://diazmidtransbackendtest.netlify.app/api/create-midtrans-transaction'),
        headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(<String, dynamic>{
          'order_id': orderId,
          'gross_amount': grossAmount,
          'user_email': _email,
          'item_id': 'MBR-B$shortFieldId-$_selectedDurationMonths', 
          'item_name': 'Membership Badminton $_selectedDurationMonths Bln - Lap ${shortFieldId.substring(1)}',
          'quantityitem': 1, 
          'priceperitem': grossAmount, 
        }),
      ).timeout(const Duration(seconds: 25)); // Timeout untuk HTTP request

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final String? snapToken = responseData['snapToken'];

        if (snapToken != null) {
          await _dbRef.child(firebaseMembershipPath).set(dataToSave).timeout(const Duration(seconds:15));
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebViewPage(
                snapToken: snapToken,
                firebaseBookingPath: firebaseMembershipPath,
              ),
            ),
          ).then((_) {
            if(mounted) _loadUserDataAndMembership();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mendapatkan token pembayaran.'), backgroundColor: Colors.red));
        }
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error dari server: ${errorData['error'] ?? 'Gagal'}'), backgroundColor: Colors.red));
        print("Backend Error: ${response.body}");
      }
    } on TimeoutException catch(e){
      print("Timeout error during membership registration: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Koneksi timeout. Silakan coba lagi."), backgroundColor: Colors.orange,));
    } 
    catch (e) {
      print("Error initiating membership payment: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: ${e.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() { _isRegisteringMembership = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoadingPage
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserDataAndMembership,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      _buildMemberInfoCard(),
                      const SizedBox(height: 30),
                      if (_activeMemberSchedule == null)
                        _buildMembershipRegistrationForm(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildMemberInfoCard() {
    // ... (Implementasi _buildMemberInfoCard tetap sama seperti sebelumnya)
    bool isActive = _activeMemberSchedule?.isActive ?? false;
    Color cardColor = isActive ? Colors.amber.shade50 : Colors.grey.shade200; 
    Color textColor = isActive ? Colors.amber.shade900 : Colors.grey.shade700;
    String statusText = isActive ? "Member Aktif" : "Non-Member";
    String validityInfo = "Anda belum terdaftar sebagai member.";

    if (isActive && _activeMemberSchedule != null) {
        validityInfo = "Berlaku hingga: ${DateFormat('dd MMMM yyyy', 'id_ID').format(_activeMemberSchedule!.endDate)}\n"
                       "Jadwal Tetap: ${_dayOfWeekToString(_activeMemberSchedule!.dayOfWeek)}, ${_activeMemberSchedule!.startTime} - ${_activeMemberSchedule!.endTime}\n"
                       "Lapangan: ${_activeMemberSchedule!.fieldId.replaceFirst('lapangan', 'Lap. ')}";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 35, 
            backgroundColor: textColor.withOpacity(0.15),
            child: Icon(isActive ? Icons.star_rounded : Icons.person_outline_rounded, size: 35, color: textColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Nama: $_fullName", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 4),
                Text("Email: $_email", style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.9))),
                if (_phoneNumber.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text("No. HP: $_phoneNumber", style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.9))),
                ],
                const SizedBox(height: 8),
                Text(validityInfo, style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.9), height: 1.4)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.blueGrey.shade400,
                    borderRadius: BorderRadius.circular(20), 
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipRegistrationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Daftar Membership Badminton", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColorDark)),
        const SizedBox(height: 8),
        Text("Harga: Rp 300.000 / bulan", style: TextStyle(fontSize: 16, color: Colors.grey[800])),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text("Benefit: 4x main/bulan, @3 jam per pertemuan, jadwal tetap.", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ),
        const SizedBox(height: 20),

        Text("Durasi Membership:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.secondary), onPressed: _selectedDurationMonths > 1 ? () => setState(() => _selectedDurationMonths--) : null),
            Text("$_selectedDurationMonths Bulan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            IconButton(icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.secondary), onPressed: () => setState(() => _selectedDurationMonths++)),
          ],
        ),
        const SizedBox(height: 10),
        
        Text("Pilih Lapangan:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        DropdownButtonFormField<String>(
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            hint: const Text("Pilih Lapangan Badminton"),
            value: _selectedFieldId,
            items: _badmintonFields.map((field) {
                return DropdownMenuItem<String>(
                value: field['id'],
                child: Text(field['name']!),
                );
            }).toList(),
            onChanged: (value) {
                if(mounted) setState(() { 
                  _selectedFieldId = value; 
                  _fetchUnavailableMemberSlots();
                });
            },
            validator: (value) => value == null ? 'Harap pilih lapangan' : null,
        ),
        const SizedBox(height: 15),

        Text("Pilih Hari Jadwal Tetap:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        DropdownButtonFormField<int>(
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          hint: const Text("Pilih Hari"),
          value: _selectedDayOfWeek,
          items: List.generate(7, (index) => index + 1)
              .map((day) => DropdownMenuItem<int>(
                    value: day,
                    child: Text(_dayOfWeekToString(day)),
                  ))
              .toList(),
          onChanged: (value) {
            if(mounted) setState(() { 
              _selectedDayOfWeek = value; 
              _fetchUnavailableMemberSlots();
            });
          },
          validator: (value) => value == null ? 'Harap pilih hari' : null,
        ),
        const SizedBox(height: 15),

        Text("Pilih Jam Mulai Jadwal Tetap (Durasi 3 Jam):", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        _isLoadingScheduleForSelectedDay
          ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
          : Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8.0,
                runSpacing: 8.0,
                children: List.generate(_memberLatestStartHour - _memberOpeningHour + 1, (index) {
                  final hour = _memberOpeningHour + index;
                  final bool isSelected = _selectedStartHour == hour;
                  final bool isTakenByOtherMember = _unavailableMemberStartHours.contains(hour);

                  return ElevatedButton(
                    onPressed: isTakenByOtherMember ? null : () { // Disable jika sudah diambil
                      if(mounted) setState(() { _selectedStartHour = hour; });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected 
                                        ? Theme.of(context).colorScheme.secondary 
                                        : isTakenByOtherMember 
                                          ? Colors.red.shade200 
                                          : Colors.blueGrey[50],
                      foregroundColor: isSelected 
                                        ? Colors.white 
                                        : isTakenByOtherMember
                                          ? Colors.white70
                                          : Colors.blueGrey[800],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text("${hour.toString().padLeft(2, '0')}:00"),
                  );
                }),
              ),
            ),
        if (_selectedStartHour != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 4.0),
            child: Text(
              "Jadwal Anda: ${_selectedStartHour.toString().padLeft(2,'0')}:00 - ${(_selectedStartHour! + _bookingDurationHours).toString().padLeft(2,'0')}:00",
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[700]),
            ),
          ),
        const SizedBox(height: 25),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.payment, color: Colors.white),
            label: _isRegisteringMembership 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) 
                : const Text("Daftar Member & Bayar", style: TextStyle(color: Colors.white, fontSize: 16)),
            onPressed: _isRegisteringMembership ? null : _processMembershipRegistration,
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
            ),
          ),
        )
      ],
    );
  }
}