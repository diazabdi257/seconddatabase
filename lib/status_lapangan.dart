import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// Model untuk informasi lampu lapangan dengan path aset ikon
class LampuLapanganInfo {
  final String firebaseKey; // e.g., "lampu_1"
  final String displayName; // e.g., "Badminton - Lapangan 1"
  final String assetIconPath; // Path ke aset ikon, misal: "assets/badminton_icon.png"

  LampuLapanganInfo({
    required this.firebaseKey,
    required this.displayName,
    required this.assetIconPath,
  });
}

class StatusLapanganPage extends StatefulWidget {
  const StatusLapanganPage({Key? key}) : super(key: key);

  @override
  State<StatusLapanganPage> createState() => _StatusLapanganPageState();
}

class _StatusLapanganPageState extends State<StatusLapanganPage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(), 
      databaseURL: 'https://gorcifut-db-default-rtdb.asia-southeast1.firebasedatabase.app'
  ).ref().child('lampu_lapangan');
  
  // Daftar semua lampu lapangan yang ingin ditampilkan statusnya
  final List<LampuLapanganInfo> _allLampu = [
    LampuLapanganInfo(firebaseKey: 'lampu_1', displayName: 'Badminton - Lapangan 1', assetIconPath: 'assets/badminton_icon.png'),
    LampuLapanganInfo(firebaseKey: 'lampu_2', displayName: 'Badminton - Lapangan 2', assetIconPath: 'assets/badminton_icon.png'),
    LampuLapanganInfo(firebaseKey: 'lampu_3', displayName: 'Badminton - Lapangan 3', assetIconPath: 'assets/badminton_icon.png'),
    // Jika Anda memiliki ikon futsal:
    // LampuLapanganInfo(firebaseKey: 'lampu_futsal_1', displayName: 'Futsal - Lapangan 1', assetIconPath: 'assets/futsal_icon.png'),
  ];

  Map<String, String> _lampuStatuses = {};
  bool _isPageLoading = true;
  Timer? _refreshTimer;
  String _lastUpdated = "Memuat...";

  @override
  void initState() {
    super.initState();
    _updateLastUpdatedTime();
    _fetchAllLampuStatuses();
    _refreshTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (mounted && !_isPageLoading) {
        print("Auto-refreshing lamp statuses...");
        _fetchAllLampuStatuses();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  void _updateLastUpdatedTime() {
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _lastUpdated = "Update Terakhir: ${DateFormat('EEEE, dd MMMM yyyy, HH:mm:ss', 'id_ID').format(now)}";
    });
  }

  Future<void> _fetchAllLampuStatuses() async {
    if (!mounted) return;
    bool isInitialFetch = _lampuStatuses.isEmpty || _lampuStatuses.values.every((s) => s == 'loading');
    if (isInitialFetch) {
      setState(() { _isPageLoading = true; });
    }
    Map<String, String> initialStatuses = {};
    for (var lampu in _allLampu) {
        initialStatuses[lampu.displayName] = 'loading';
    }
    if(mounted) setState(() => _lampuStatuses = initialStatuses);

    for (var lampuInfo in _allLampu) {
      if (!mounted) break;
      String relativePath = '${lampuInfo.firebaseKey}/status';
      String currentStatus = 'tidak_ditemukan';

      try {
        final event = await _databaseRef.child(relativePath).once().timeout(const Duration(seconds: 5));
        final snapshot = event.snapshot;

        if (snapshot.exists && snapshot.value != null) {
          if (snapshot.value is String) {
            currentStatus = (snapshot.value as String).trim().toUpperCase();
          } else {
            currentStatus = 'error_type';
          }
        }
      } on TimeoutException catch (_) {
        print("Timeout fetching status for ${lampuInfo.displayName}");
        currentStatus = 'error_timeout';
      } catch (e) {
        print("Error fetching status for ${lampuInfo.displayName}: $e");
        currentStatus = 'error';
      }

      if (mounted) {
        setState(() {
          _lampuStatuses[lampuInfo.displayName] = currentStatus;
        });
      }
    }

    if (mounted) {
      _updateLastUpdatedTime();
      setState(() {
        _isPageLoading = false;
      });
    }
  }

  Widget _buildStatusCard(LampuLapanganInfo lampu, String status) {
    Color cardColor;
    Color textColor;
    Color iconColor; // Warna untuk ikon status (NYALA/MATI)
    IconData statusIndicatorIcon;
    String statusText;

    switch (status.toUpperCase()) {
      case 'NYALA':
        cardColor = Colors.red.withOpacity(0.05); // Latar card lebih soft
        textColor = Colors.red.shade800;
        iconColor = Colors.red.shade600;
        statusIndicatorIcon = Icons.flash_on_rounded;
        statusText = 'TERPAKAI';
        break;
      case 'MATI':
        cardColor = Colors.green.withOpacity(0.05); // Latar card lebih soft
        textColor = Colors.green.shade800;
        iconColor = Colors.green.shade600;
        statusIndicatorIcon = Icons.flash_off_rounded;
        statusText = 'TERSEDIA';
        break;
      case 'LOADING':
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16.0),
            leading: SizedBox(
              width: 30, height: 30, // Ukuran untuk ikon aset
              child: Image.asset(lampu.assetIconPath, color: Colors.grey[400]), // Ikon aset saat loading
            ),
            title: Text(lampu.displayName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
            subtitle: const Text("Memuat status...", style: TextStyle(fontStyle: FontStyle.italic)),
            trailing: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
          ),
        );
      case 'ERROR':
      case 'ERROR_TYPE':
      case 'ERROR_TIMEOUT':
        cardColor = Colors.orange.withOpacity(0.05);
        textColor = Colors.orange.shade800;
        iconColor = Colors.orange.shade600;
        statusIndicatorIcon = Icons.warning_amber_rounded;
        statusText = 'Error Data';
        break;
      default: 
        cardColor = Colors.grey.withOpacity(0.05);
        textColor = Colors.grey.shade700;
        iconColor = Colors.grey.shade400;
        statusIndicatorIcon = Icons.help_outline_rounded;
        statusText = 'N/A';
    }

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      color: Colors.white, // Card putih
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.0),
            border: Border(left: BorderSide(color: iconColor, width: 5))
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          child: Row(
            children: [
              // Menggunakan Image.asset untuk ikon lapangan
              SizedBox(
                width: 36,
                height: 36,
                child: Image.asset(
                  lampu.assetIconPath,
                  color: textColor.withOpacity(0.9), // Memberi sedikit warna pada ikon aset
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.sports, size: 36, color: textColor.withOpacity(0.7)), // Fallback icon
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lampu.displayName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[850],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(statusIndicatorIcon, color: iconColor, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Indikator bulat tetap di kanan
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: status.toUpperCase() == 'NYALA' ? Colors.red.shade400 : 
                         status.toUpperCase() == 'MATI' ? Colors.green.shade400 : 
                         Colors.grey.shade400,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: (status.toUpperCase() == 'NYALA' ? Colors.red : 
                              status.toUpperCase() == 'MATI' ? Colors.green : 
                              Colors.grey).withOpacity(0.4),
                      spreadRadius: 1,
                      blurRadius: 3,
                    )
                  ]
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Lapangan'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: (_isPageLoading && _lampuStatuses.values.any((s) => s == 'loading')) 
                       ? null 
                       : _fetchAllLampuStatuses,
            tooltip: 'Refresh Status',
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.blueGrey[50],
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              _lastUpdated,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.blueGrey[700], fontStyle: FontStyle.italic),
            ),
          ),
          Expanded(
            child: _isPageLoading && _lampuStatuses.values.every((s) => s == 'loading')
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchAllLampuStatuses,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12.0),
                      itemCount: _allLampu.length,
                      itemBuilder: (context, index) {
                        final lampu = _allLampu[index];
                        final status = _lampuStatuses[lampu.displayName] ?? 'loading';
                        return _buildStatusCard(lampu, status);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}