import 'package:seconddatabase/lapanganfutsal.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'lapangan1badminton_page.dart';
import 'lapangan2badminton_page.dart';
import 'lapangan3badminton_page.dart';
import 'lapangan4badminton_page.dart';

class BerandaPage extends StatefulWidget {
  const BerandaPage({super.key});

  @override
  State<BerandaPage> createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> {
  String selectedFilter = 'Badminton'; // Default filter is Badminton
  String fullName = '';  // Variable to hold the user's full name
  String email = '';
  String phoneNumber = '';


 // Function to load user data from SharedPreferences
  Future<void> _getUserDataFromSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedName = prefs.getString('fullName');
    String? savedEmail = prefs.getString('email');
    String? savedPhoneNumber = prefs.getString('phoneNumber');

    // Use setState to update UI after data is loaded
    setState(() {
      fullName = savedName ?? 'Nama Tidak Tersedia';
      email = savedEmail ?? 'Email Tidak Tersedia';
      phoneNumber = savedPhoneNumber ?? 'Nomor Tidak Tersedia';
    });
  }

  @override
  void initState() {
    super.initState();
    _getUserDataFromSharedPreferences(); // Ambil data pengguna saat halaman dimuat
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Greeting box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // CircleAvatar dengan border
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black, // Warna border
                        width: 2, // Ketebalan border
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 30,  // Ukuran dari CircleAvatar
                      backgroundImage: AssetImage("assets/gambar6.jpg"), // Ganti dengan gambar profil
                      backgroundColor: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Haloo!",
                          style: TextStyle(color: Colors.white),
                        ),
                        SizedBox(height: 7),
                        // Jika data masih loading, tampilkan indikator loading
                        Text(
                            "$fullName",  // Tampilkan fullName yang diambil dari Firestore/SharedPreferences
                            style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
      
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Filter buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FilterButton(
                  label: 'Futsal',
                  onPressed: () {
                    setState(() {
                      selectedFilter = 'Futsal'; // Update the selected filter
                    });
                  },
                  isSelected:
                      selectedFilter == 'Futsal', // Apply isSelected logic
                ),
                FilterButton(
                  label: 'Badminton',
                  onPressed: () {
                    setState(() {
                      selectedFilter =
                          'Badminton'; // Update the selected filter
                    });
                  },
                  isSelected:
                      selectedFilter == 'Badminton', // Apply isSelected logic
                ),
                FilterButton(
                  label: 'Contact Us',
                  onPressed: () {
                    setState(() {
                      selectedFilter =
                          'Contact Us'; // Update the selected filter
                    });
                  },
                  isSelected:
                      selectedFilter == 'Contact Us', // Apply isSelected logic
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Display appropriate fields based on selected filter
            if (selectedFilter == 'Futsal') ...[
              _lapanganCard(
                "Lapangan 1",
                "assets/lapanganfutsal.jpg",
                "Futsal",
                "150k/jam",
                const LapanganFutsalPage(),
              ),
            ],
            if (selectedFilter == 'Badminton') ...[
              _lapanganCard(
                "Lapangan 1",
                "assets/lapangan1badminton.jpg",
                "Badminton",
                "60k/jam",
                const Lapangan1BadmintonPage(),
              ),
              const SizedBox(height: 16), // Add spacing between cards
              _lapanganCard(
                "Lapangan 2",
                "assets/lapangan2badminton.jpg",
                "Badminton",
                "60k/jam",
                const Lapangan2BadmintonPage(),
              ),
              const SizedBox(height: 16),
              _lapanganCard(
                "Lapangan 3",
                "assets/lapangan3badminton.jpg",
                "Badminton",
                "60k/jam",
                const Lapangan3BadmintonPage(),
              ),
              const SizedBox(height: 16), // Add spacing between cards
              _lapanganCard(
                "Lapangan 4",
                "assets/lapangan4badminton.jpg",
                "Badminton",
                "60k/jam",
                const Lapangan4BadmintonPage(),
              ),
              const SizedBox(height: 16), // Add spacing between cards
            ],
            if (selectedFilter == 'Contact Us') ...[
              GestureDetector(
                onTap: () {
                  // Open WhatsApp contact page
                  print("Contacting via WhatsApp...");
                  // You can add functionality here to open WhatsApp
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.chat_bubble, size: 50, color: Colors.green),
                      Text(
                        'Hubungi Kami melalui WhatsApp',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Card to display lapangan
  Widget _lapanganCard(
    String label,
    String imagePath,
    String jenis,
    String harga,
    Widget targetPage,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey, //warna border
          width: 1, //ketebalan border
        ),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: ListTile(
        leading: Image.asset(imagePath, height: 50, width: 50),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(jenis, style: const TextStyle(color: Colors.grey)),
            Text(harga, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // Navigasi ke halaman yang sesuai
          Navigator.push(context, MaterialPageRoute(builder: (context)=> targetPage),
          );
        },
      ),
    );
  }
}

// Custom Filter Button with dynamic styles
class FilterButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isSelected;

  const FilterButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Colors.lightBlue
            : Colors.white, // Set yellow when selected, blue otherwise
        padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: Colors.grey,  // Ganti dengan warna border yang diinginkan
            width: 1, // Ketebalan border
          ),
        ),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
        ), // Set black text when selected
      ),
    );
  }
}
