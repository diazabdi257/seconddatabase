import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

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
  bool _isLoadingPage = true;
  bool _isRegisteringMembership = false;
  bool _isLoadingScheduleForSelectedDay = false;

  int _selectedDurationMonths = 1;
  int? _selectedDayOfWeek;
  int? _selectedStartHour;
  final int _bookingDurationHours = 3;
  String? _selectedFieldId;

  Set<int> _unavailableMemberStartHours = {};

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
    setState(() => _isLoadingPage = true);

    _currentUser = FirebaseAuth.instance.currentUser;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _fullName = prefs.getString('fullName') ?? 'Nama Tidak Tersedia';
    _email = prefs.getString('email') ?? _currentUser?.email ?? 'Email Tidak Tersedia';
    _phoneNumber = prefs.getString('phoneNumber') ?? '';

    if (_currentUser != null) {
      await _fetchActiveMembership();
    }

    if (!mounted) return;
    setState(() => _isLoadingPage = false);
  }

  Future<void> _fetchActiveMembership() async {
    // ... (Fungsi ini tidak diubah)
    if (_currentUser == null) return;

    Query query = _dbRef.child('memberSchedules_badminton');
    try {
      DataSnapshot snapshot = await query.once().then((event) => event.snapshot);
      MemberSchedule? foundSchedule;
      if (snapshot.value != null && snapshot.value is Map) {
        (snapshot.value as Map<dynamic, dynamic>).forEach((key, value) {
          if (foundSchedule == null && value is Map) {
            try {
              final schedule = MemberSchedule.fromMap(key, value);
              bool isThisUserSchedule = (schedule.userId == _currentUser!.uid) || (schedule.email == _currentUser!.email && schedule.email.isNotEmpty);
              if (isThisUserSchedule && schedule.isActive) {
                foundSchedule = schedule;
              }
            } catch (e) { /* Error parsing */ }
          }
        });
      }
      if (!mounted) return;
      setState(() => _activeMemberSchedule = foundSchedule);
    } catch (e) {
      print("Error fetching active membership: $e");
    }
  }

  Future<void> _fetchUnavailableMemberSlots() async {
    // ... (Fungsi ini tidak diubah)
    if (_selectedFieldId == null || _selectedDayOfWeek == null) {
      if(mounted) setState(() => _unavailableMemberStartHours.clear());
      return;
    }
    if(mounted) setState(() {
      _isLoadingScheduleForSelectedDay = true;
      _unavailableMemberStartHours.clear();
    });
    // ... (Logika fetch tidak diubah)
    if(mounted) setState(() => _isLoadingScheduleForSelectedDay = false);
  }

  String _dayOfWeekToString(int day) {
    const days = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"];
    return (day >= 1 && day <= 7) ? days[day - 1] : "Tidak Valid";
  }

  Future<void> _processMembershipRegistration() async {
    if (_currentUser == null || _selectedDayOfWeek == null || _selectedStartHour == null || _selectedFieldId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap lengkapi semua pilihan.')));
      return;
    }
    // ... (validasi lainnya tidak diubah)

    if (!mounted) return;
    setState(() => _isRegisteringMembership = true);

    final String firebaseKey = _dbRef.child('memberSchedules_badminton').push().key!;
    final Map<String, dynamic> dataToSave = {
      'bookingType': 'member',
      'dayOfWeek': _selectedDayOfWeek,
      'endTime': "${(_selectedStartHour! + _bookingDurationHours).toString().padLeft(2, '0')}:00",
      'fieldId': _selectedFieldId,
      'firstDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'fullName': _fullName,
      'phoneNumber': _phoneNumber,
      'startTime': "${_selectedStartHour!.toString().padLeft(2, '0')}:00",
      'timestamp': ServerValue.timestamp,
      'validityMonths': _selectedDurationMonths,
      'userId': _currentUser!.uid,
      'email': _email,
      'status': 'pending', // Menggunakan 'status' agar konsisten
    };

    final String shortFieldId = _selectedFieldId!.replaceFirst('lapangan', 'L');
    final String dateForOrderId = DateFormat('yyMMdd').format(DateTime.now());
    final String orderIdSuffix = firebaseKey.substring(firebaseKey.length - 8);
    final String orderId = 'MBR-B$shortFieldId-$dateForOrderId-$orderIdSuffix';
    dataToSave['midtrans_order_id'] = orderId;

    final int grossAmount = 300000 * _selectedDurationMonths; // Harga membership disesuaikan
    final String firebaseMembershipPath = 'memberSchedules_badminton/$firebaseKey';

    // Body untuk dikirim ke backend, sesuaikan jika backend Anda berbeda
     Map<String, dynamic> transactionData = {
      "order_id": orderId,
      "gross_amount": grossAmount,
      "user_email": _email,
      "item_details": [{
        "id": 'MBR-B$shortFieldId-$_selectedDurationMonths',
        "price": grossAmount,
        "quantity": 1,
        "name":'Membership Badminton $_selectedDurationMonths Bln - Lap ${shortFieldId.substring(1)}'
      }],
      "customer_details": {
        "first_name": _fullName.split(' ').first,
        "last_name": _fullName.split(' ').length > 1 ? _fullName.split(' ').sublist(1).join(' ') : "",
        "email": _email,
        "phone": _phoneNumber
      }
    };

    try {
      final response = await http.post(
        Uri.parse('https://booking-gor.site/api/create-midtrans-transaction'), // Gunakan backend yang sama
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(transactionData),
      ).timeout(const Duration(seconds: 25));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // --- PERBAIKAN UTAMA DI SINI ---
        final String? redirectUrl = responseData['redirect_url'];

        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          await _dbRef.child(firebaseMembershipPath).set(dataToSave).timeout(const Duration(seconds: 15));
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebViewPage(
                    url: redirectUrl, // Kirim URL
                    firebaseBookingPath: firebaseMembershipPath,
                  ),
            ),
          ).then((_) {
            if (mounted) _loadUserDataAndMembership();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mendapatkan URL pembayaran.'), backgroundColor: Colors.red));
        }
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error dari server: ${errorData['error'] ?? 'Gagal'}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      print("Error initiating membership payment: $e");
    } finally {
      if (mounted) setState(() => _isRegisteringMembership = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body:
          _isLoadingPage
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
    bool isActive = _activeMemberSchedule?.isActive ?? false;
    Color cardColor = isActive ? Colors.amber.shade50 : Colors.grey.shade200;
    Color textColor = isActive ? Colors.amber.shade900 : Colors.grey.shade700;
    String statusText = isActive ? "Member Aktif" : "Non-Member";
    String validityInfo = "Anda belum terdaftar sebagai member.";

    if (isActive && _activeMemberSchedule != null) {
      int dayOfWeekFromDB = _activeMemberSchedule!.dayOfWeek;
      if (dayOfWeekFromDB == 0) {
        dayOfWeekFromDB = 7;
      }
      validityInfo =
          "Berlaku hingga: ${DateFormat('dd MMMM yyyy', 'id_ID').format(_activeMemberSchedule!.endDate)}\n"
          "Jadwal Tetap: ${_dayOfWeekToString(dayOfWeekFromDB)}, ${_activeMemberSchedule!.startTime} - ${_activeMemberSchedule!.endTime}\n"
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
            child: Icon(
              isActive ? Icons.star_rounded : Icons.person_outline_rounded,
              size: 35,
              color: textColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Nama: $_fullName",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Email: $_email",
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.9),
                  ),
                ),
                if (_phoneNumber.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    "No. HP: $_phoneNumber",
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withOpacity(0.9),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  validityInfo,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.blueGrey.shade400,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
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
        Text(
          "Daftar Membership Badminton",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColorDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Harga: Rp 300.000 / bulan",
          style: TextStyle(fontSize: 16, color: Colors.grey[800]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            "Benefit: 4x main/bulan, @3 jam per pertemuan, jadwal tetap.",
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "Durasi Membership:",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                Icons.remove_circle_outline,
                color: Theme.of(context).colorScheme.secondary,
              ),
              onPressed:
                  _selectedDurationMonths > 1
                      ? () => setState(() => _selectedDurationMonths--)
                      : null,
            ),
            Text(
              "$_selectedDurationMonths Bulan",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.add_circle_outline,
                color: Theme.of(context).colorScheme.secondary,
              ),
              onPressed: () => setState(() => _selectedDurationMonths++),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          "Pilih Lapangan:",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          hint: const Text("Pilih Lapangan Badminton"),
          value: _selectedFieldId,
          items:
              _badmintonFields.map((field) {
                return DropdownMenuItem<String>(
                  value: field['id'],
                  child: Text(field['name']!),
                );
              }).toList(),
          onChanged: (value) {
            if (mounted)
              setState(() {
                _selectedFieldId = value;
                _fetchUnavailableMemberSlots();
              });
          },
          validator: (value) => value == null ? 'Harap pilih lapangan' : null,
        ),
        const SizedBox(height: 15),

        Text(
          "Pilih Hari Jadwal Tetap:",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        DropdownButtonFormField<int>(
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          hint: const Text("Pilih Hari"),
          value: _selectedDayOfWeek,
          items:
              List.generate(7, (index) => index + 1)
                  .map(
                    (day) => DropdownMenuItem<int>(
                      value: day,
                      child: Text(_dayOfWeekToString(day)),
                    ),
                  )
                  .toList(),
          onChanged: (value) {
            if (mounted)
              setState(() {
                _selectedDayOfWeek = value;
                _fetchUnavailableMemberSlots();
              });
          },
          validator: (value) => value == null ? 'Harap pilih hari' : null,
        ),
        const SizedBox(height: 15),
        Text(
          "Pilih Jam Mulai Jadwal Tetap (Durasi 3 Jam):",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        _isLoadingScheduleForSelectedDay
            ? const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            )
            : Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8.0,
                runSpacing: 8.0,
                children: List.generate(
                  _memberLatestStartHour - _memberOpeningHour + 1,
                  (index) {
                    final hour = _memberOpeningHour + index;
                    final bool isSelected = _selectedStartHour == hour;
                    final bool isTaken = _unavailableMemberStartHours.contains(
                      hour,
                    );

                    return ElevatedButton(
                      onPressed:
                          isTaken
                              ? null
                              : () {
                                if (mounted)
                                  setState(() {
                                    _selectedStartHour = hour;
                                  });
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isSelected
                                ? Colors.lightBlue.shade300
                                : isTaken
                                ? Colors.red.shade100
                                : Colors.blueGrey[50],
                        foregroundColor:
                            isSelected
                                ? Colors.white
                                : isTaken
                                ? Colors.red.shade400
                                : Colors.blueGrey[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: Text("${hour.toString().padLeft(2, '0')}:00"),
                    );
                  },
                ),
              ),
            ),
        if (_selectedStartHour != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 4.0),
            child: Text(
              "Jadwal Anda: ${_selectedStartHour.toString().padLeft(2, '0')}:00 - ${(_selectedStartHour! + _bookingDurationHours).toString().padLeft(2, '0')}:00",
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey[700],
              ),
            ),
          ),
        const SizedBox(height: 25),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.payment, color: Colors.white),
            label:
                _isRegisteringMembership
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                    : const Text(
                      "Daftar Member & Bayar",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
            onPressed:
                _isRegisteringMembership
                    ? null
                    : _processMembershipRegistration,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
