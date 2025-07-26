import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// Ganti dengan path model dan halaman webview Anda yang benar
import 'models/member_schedule.dart';
import 'midtrans/midtranswebview_page.dart';
// Ganti dengan path ke backend API Anda
import 'package:http/http.dart' as http;
import 'dart:convert';


class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});

  @override
  _MembershipPageState createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  // --- STATE UNTUK DATA PENGGUNA & STATUS MEMBERSHIP ---
  String _fullName = 'Memuat...';
  String _email = 'Memuat...';
  String _phoneNumber = 'Memuat...';
  User? _currentUser;
  MemberSchedule? _activeMemberSchedule;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  // --- STATE UNTUK UI & PROSES ---
  bool _isLoadingPage = true;
  bool _isRegisteringMembership = false;
  bool _isLoadingScheduleForSelectedDay = false;

  // --- STATE UNTUK FORM PENDAFTARAN ---
  int _selectedDurationMonths = 1;
  int? _selectedDayOfWeek;
  int? _selectedStartHour;
  final int _bookingDurationHours = 3;
  String? _selectedFieldId;
  Set<int> _unavailableMemberStartHours = {};

  // --- DATA STATIS ---
  final List<Map<String, String>> _badmintonFields = [
    {'id': 'lapangan1', 'name': 'Lapangan 1'},
    {'id': 'lapangan2', 'name': 'Lapangan 2'},
    {'id': 'lapangan3', 'name': 'Lapangan 3'},
    {'id': 'lapangan4', 'name': 'Lapangan 4'},
  ];
  final int _memberOpeningHour = 7;
  final int _memberLatestStartHour = 22 - 3; // Jam mulai terakhir agar durasi 3 jam tidak melebihi jam 22

  @override
  void initState() {
    super.initState();
    _loadUserDataAndMembership();
  }

  /// Memuat data pengguna dari SharedPreferences dan status membership dari Firebase.
  Future<void> _loadUserDataAndMembership() async {
    if (!mounted) return;
    setState(() => _isLoadingPage = true);

    _currentUser = FirebaseAuth.instance.currentUser;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _fullName = prefs.getString('fullName') ?? 'Nama Tidak Tersedia';
    _email = prefs.getString('email') ?? _currentUser?.email ?? 'Email Tidak Tersedia';
    _phoneNumber = prefs.getString('phoneNumber') ?? 'No. HP Tidak Tersedia';

    if (_currentUser != null) {
      await _fetchActiveMembership();
    }

    if (!mounted) return;
    setState(() => _isLoadingPage = false);
  }

  /// Mengambil data membership aktif pengguna dari Firebase.
  Future<void> _fetchActiveMembership() async {
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
            } catch (e) { print("Error parsing schedule: $e"); }
          }
        });
      }
      if (!mounted) return;
      setState(() => _activeMemberSchedule = foundSchedule);
    } catch (e) {
      print("Error fetching active membership: $e");
    }
  }

  /// Mengambil slot jam yang tidak tersedia berdasarkan jadwal member lain.
  Future<void> _fetchUnavailableMemberSlots() async {
  if (_selectedFieldId == null || _selectedDayOfWeek == null) {
    if (mounted) setState(() => _unavailableMemberStartHours.clear());
    return;
  }

  if (mounted) {
    setState(() {
      _isLoadingScheduleForSelectedDay = true;
      _unavailableMemberStartHours.clear();
    });
  }

  try {
    Set<int> tempUnavailableHours = {};
    final memberQuery = _dbRef
        .child('memberSchedules_badminton')
        .orderByChild('fieldId')
        .equalTo(_selectedFieldId!);

    final event = await memberQuery.once();
    final snapshot = event.snapshot;

    if (snapshot.exists && snapshot.value is Map) {
      (snapshot.value as Map<dynamic, dynamic>).forEach((key, value) {
        if (value is Map) {
          try {
            final schedule = MemberSchedule.fromMap(key, value);
            print('--- MEMERIKSA JADWAL MEMBER ---');
        print('Key: ${schedule.key}');
        print('Field ID di DB: "${schedule.fieldId}" vs Pilihan: "${_selectedFieldId}"');
        print('Day of Week di DB: ${schedule.dayOfWeek} vs Pilihan: ${_selectedDayOfWeek}');
        print('Status Aktif?: ${schedule.isActive}');
        print('--- AKHIR PEMERIKSAAN ---');
            // PERBAIKAN KRUSIAL DI SINI:
            // Langsung gunakan schedule.dayOfWeek dari model yang sudah cerdas
            // menangani 'dayOfWeek' atau 'fixedDayOfWeek'.
            int dayOfWeekFromDB = schedule.dayOfWeek;
            
            // Normalisasi hari Minggu jika data lama menggunakan 0
            if (dayOfWeekFromDB == 0) {
              dayOfWeekFromDB = 7;
            }

            if (schedule.isActive && dayOfWeekFromDB == _selectedDayOfWeek) {
              int otherStart = int.parse(schedule.startTime.split(':')[0]);
              int otherEnd = int.parse(schedule.endTime.split(':')[0]);

              for (int bookedHour = otherStart; bookedHour < otherEnd; bookedHour++) {
                tempUnavailableHours.add(bookedHour);
                tempUnavailableHours.add(bookedHour - 1);
                tempUnavailableHours.add(bookedHour - 2);
              }
            }
          } catch (e) {
            print("Error parsing schedule for slot check: $e");
          }
        }
      });
    }

    if (mounted) {
      setState(() {
        _unavailableMemberStartHours = tempUnavailableHours;
      });
    }
  } catch (e) {
    print("Error fetching unavailable slots: $e");
  } finally {
    if (mounted) {
      setState(() {
        _isLoadingScheduleForSelectedDay = false;
      });
    }
  }
}

  /// Proses pendaftaran dan pembayaran membership.
  Future<void> _processMembershipRegistration() async {
    if (_currentUser == null || _selectedDayOfWeek == null || _selectedStartHour == null || _selectedFieldId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap lengkapi semua pilihan.')));
      return;
    }
    
    if (_unavailableMemberStartHours.contains(_selectedStartHour)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jadwal yang dipilih tidak tersedia.'), backgroundColor: Colors.orange));
        return;
    }

    setState(() => _isRegisteringMembership = true);
    
    final firebaseKey = _dbRef.child('memberSchedules_badminton').push().key!;
    final dataToSave = {
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
      'status': 'pending',
    };

    final shortFieldId = _selectedFieldId!.replaceFirst('lapangan', 'L');
    final dateForOrderId = DateFormat('yyMMdd').format(DateTime.now());
    final orderIdSuffix = firebaseKey.substring(firebaseKey.length - 8);
    final orderId = 'MBR-B$shortFieldId-$dateForOrderId-$orderIdSuffix';
    dataToSave['midtrans_order_id'] = orderId;

    final grossAmount = 300000 * _selectedDurationMonths;
    final firebaseMembershipPath = 'memberSchedules_badminton/$firebaseKey';

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
        Uri.parse('https://booking-gor.site/api/create-midtrans-transaction'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(transactionData),
      ).timeout(const Duration(seconds: 25));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final String? redirectUrl = responseData['redirect_url'];

        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          await _dbRef.child(firebaseMembershipPath).set(dataToSave).timeout(const Duration(seconds: 15));
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebViewPage(
                    url: redirectUrl,
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
  String _dayOfWeekToString(int day) {
    const days = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"];
    if (day >= 1 && day <= 7) return days[day - 1];
    return "Tidak Valid";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoadingPage
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserDataAndMembership,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildMemberInfoCard(),
                    const SizedBox(height: 24),
                    // Tampilkan form pendaftaran hanya jika pengguna belum menjadi member aktif
                    if (_activeMemberSchedule == null)
                      _buildMembershipRegistrationForm(),
                  ],
                ),
              ),
            ),
    );
  }

  /// Widget untuk menampilkan kartu informasi membership pengguna.
  Widget _buildMemberInfoCard() {
    bool isActive = _activeMemberSchedule?.isActive ?? false;
    Color cardColor = isActive ? Colors.indigo.shade50 : Colors.blueGrey.shade50;
    Color accentColor = isActive ? Colors.indigo.shade800 : Colors.blueGrey.shade700;
    String statusText = isActive ? "Member Aktif" : "Non-Member";
    String validityInfo = "Anda belum terdaftar sebagai member.";

    if (isActive && _activeMemberSchedule != null) {
      int dayOfWeekFromDB = _activeMemberSchedule!.dayOfWeek == 0 ? 7 : _activeMemberSchedule!.dayOfWeek;
      validityInfo =
          "Berlaku hingga: ${DateFormat('dd MMMM yyyy', 'id_ID').format(_activeMemberSchedule!.endDate)}\n"
          "Jadwal: ${_dayOfWeekToString(dayOfWeekFromDB)}, ${_activeMemberSchedule!.startTime} - ${_activeMemberSchedule!.endTime}";
    }

    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Membership Card",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: accentColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.person_outline, "Nama", _fullName, accentColor),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.email_outlined, "Email", _email, accentColor),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.phone_outlined, "Nomor HP", _phoneNumber, accentColor),
            if(isActive) ...[
              const Divider(height: 24),
              _buildInfoRow(Icons.calendar_today_outlined, "Info Jadwal", validityInfo, accentColor),
            ]
          ],
        ),
      ),
    );
  }

  /// Widget helper untuk baris informasi di dalam kartu.
  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ],
    );
  }

  /// Widget untuk menampilkan form pendaftaran membership.
  Widget _buildMembershipRegistrationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Daftar Membership Badminton", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        const SizedBox(height: 8),
        Text("Harga: Rp 300.000 / bulan", style: TextStyle(fontSize: 16, color: Colors.grey[700])),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text("Benefit: 4x main/bulan, @3 jam per pertemuan, jadwal tetap.", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ),
        const Divider(height: 32),
        
        Text("Durasi Membership:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.primary),
              onPressed: _selectedDurationMonths > 1 ? () => setState(() => _selectedDurationMonths--) : null,
            ),
            Text("$_selectedDurationMonths Bulan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
              onPressed: () => setState(() => _selectedDurationMonths++),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        _buildDropdown("Pilih Lapangan:", "Pilih Lapangan Badminton", _selectedFieldId, _badmintonFields, (value) {
          if (mounted) setState(() {
            _selectedFieldId = value;
            _selectedStartHour = null; // Reset pilihan jam saat ganti lapangan
            _fetchUnavailableMemberSlots();
          });
        }),
        const SizedBox(height: 16),

        _buildDropdown("Pilih Hari Jadwal Tetap:", "Pilih Hari", _selectedDayOfWeek, 
          List.generate(7, (index) => {'id': index + 1, 'name': _dayOfWeekToString(index + 1)}), 
          (value) {
          if (mounted) setState(() {
            _selectedDayOfWeek = value;
            _selectedStartHour = null; // Reset pilihan jam saat ganti hari
            _fetchUnavailableMemberSlots();
          });
        }),
        const SizedBox(height: 16),

        Text("Pilih Jam Mulai Jadwal Tetap (Durasi 3 Jam):", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        
        _isLoadingScheduleForSelectedDay
            ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
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
                      final bool isTaken = _unavailableMemberStartHours.contains(hour);

                      return ElevatedButton(
                        onPressed: isTaken ? null : () {
                          if (mounted) setState(() => _selectedStartHour = hour);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? Colors.indigo : isTaken ? Colors.grey.shade300 : Colors.white,
                          foregroundColor: isSelected ? Colors.white : isTaken ? Colors.grey.shade500 : Colors.black,
                          side: BorderSide(color: isTaken ? Colors.transparent : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: Text("${hour.toString().padLeft(2, '0')}:00"),
                      );
                    },
                  ),
                ),
              ),
        if (_selectedStartHour != null)
          Padding(
            padding: const EdgeInsets.only(top: 12.0, left: 4.0),
            child: Center(child: Text("Jadwal Anda: ${_selectedStartHour.toString().padLeft(2, '0')}:00 - ${(_selectedStartHour! + _bookingDurationHours).toString().padLeft(2, '0')}:00", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[700]))),
          ),
        const SizedBox(height: 24),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  /// Widget helper untuk membuat Dropdown yang terstandardisasi.
  Widget _buildDropdown<T>(String label, String hint, T? value, List<Map<String, dynamic>> items, ValueChanged<T?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            filled: true,
            fillColor: Colors.white,
          ),
          hint: Text(hint),
          value: value,
          items: items.map((item) => DropdownMenuItem<T>(value: item['id'], child: Text(item['name']!))).toList(),
          onChanged: onChanged,
          validator: (val) => val == null ? 'Harap pilih salah satu' : null,
        ),
      ],
    );
  }
}