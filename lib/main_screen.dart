import 'package:flutter/material.dart';
import 'beranda_page.dart';
import 'pemesanan_page.dart';
import 'profile_page.dart';
import 'membership_page.dart';
import 'status_lapangan.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const BerandaPage(),
    const StatusLapanganPage(),
    const MembershipPage(),
    const PemesananPage(),
    const ProfilePage(),
  ];

  void _onNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey,
                width: 1.0,
              ),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.lightBlue,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Image.asset(
                    "assets/logo_cifut.png",
                    height: 50, // Atur tinggi logo
                    fit: BoxFit.contain, // Jaga agar tetap proporsional
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
            color: Colors.grey, // Warna border
            width: 1.0, // Ketebalan border
            ),
          ),
        ),

        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onNavTapped,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Beranda"),
            BottomNavigationBarItem(icon: Icon(Icons.info), label: "Status"),
            BottomNavigationBarItem(icon: Icon(Icons.card_membership), label: "Member"),
            BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "Pemesanan"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
          ],
        ),
      ),
    );
  }
}
