import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:seconddatabase/edit_profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'login_input.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Mendeklarasikan variabel untuk menampung data pengguna
  String fullName = '';
  String email = '';
  String phoneNumber = '';

  // Fungsi untuk mengambil data pengguna dari SharedPreferences
  Future<void> _getUserDataFromSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedName = prefs.getString('fullName');
    String? savedEmail = prefs.getString('email');
    

    setState(() {
      // Jika data fullName ada di SharedPreferences, tampilkan
      if (savedName != null && savedName.isNotEmpty && savedEmail != null && savedEmail.isNotEmpty) {
        fullName = savedName;
        email = savedEmail;
          // Use saved fullName if available
      } else {
        // Jika fullName tidak ada di SharedPreferences, ambil dari Firestore
        // Anda dapat menambahkan logika untuk mengambil data dari Firestore di sini
        // Misalnya, Anda dapat menambahkan fungsi untuk memuat data dari Firestore dan kemudian memanggil setState()
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _getUserDataFromSharedPreferences(); // Panggil fungsi untuk ambil data saat halaman dimuat
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
                radius: 50,  // Ukuran dari CircleAvatar
                backgroundImage: AssetImage("assets/gambar6.jpg"), // Ganti dengan gambar profil
                backgroundColor: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),

            // Tampilkan nama dan email pengguna
            Text(
              fullName,  // Tampilkan fullName yang diambil dari Firestore
              style: const TextStyle(fontSize: 22, color: Colors.black, fontWeight: FontWeight.bold),
            ),
            Text(
              email,  // Tampilkan email yang diambil dari Firestore
              style: const TextStyle(fontSize: 14, color: Colors.black),
            ),
            const SizedBox(height: 30),

            // Info Akun
            _profileOption(icon: Icons.edit, label: "Edit Profil", onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfilePage()));
            }),
            _profileOption(icon: Icons.help_outline, label: "Bantuan", onTap: () {}),
            _profileOption(icon: Icons.logout, label: "Keluar", onTap: () async {
              // Menghapus data pengguna dari SharedPreferences saat logout
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.remove('fullName');
              await prefs.remove('phoneNumber');
              // Navigasi ke halaman login atau logout logic
              FirebaseAuth.instance.signOut(); // Logout pengguna
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginInput()),
              ); // Contoh logout dan kembali ke halaman login
            }),
          ],
        ),
      ),
    );
  }

  Widget _profileOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: 
      BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(label),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
