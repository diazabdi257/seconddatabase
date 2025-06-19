import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seconddatabase/daftar_akun.dart';
import 'package:seconddatabase/login_input.dart';
import 'package:seconddatabase/main_screen.dart'; // Import halaman utama

// Mengubah menjadi StatefulWidget
class LoginChoice extends StatefulWidget {
  const LoginChoice({super.key});

  @override
  State<LoginChoice> createState() => _LoginChoiceState();
}

class _LoginChoiceState extends State<LoginChoice> {
  bool _isLoading = false; // State untuk mengelola loading indicator

  // Fungsi untuk menangani proses login dengan Google
  Future<void> signInWithGoogle() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true; // Tampilkan loading
    });

    try {
      // 1. Memulai proses Google Sign-In
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        // Pengguna membatalkan proses login
        setState(() => _isLoading = false);
        return;
      }

      // 2. Mendapatkan detail otentikasi dari akun Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 3. Login ke Firebase dengan kredensial Google
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // 4. Cek apakah pengguna baru & simpan data ke Firestore jika perlu
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        final docSnapshot = await userDoc.get();

        if (!docSnapshot.exists) {
          // Pengguna baru, simpan datanya ke Firestore
          await userDoc.set({
            'email': user.email,
            'fullName': user.displayName,
            'phoneNumber': user.phoneNumber ?? '', // Nomor HP mungkin null
            'createdAt': DateTime.now().toIso8601String(),
            'uid': user.uid,
          });
        }

        // 5. Simpan data ke SharedPreferences agar bisa diakses di halaman lain
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('fullName', user.displayName ?? 'Nama Tidak Tersedia');
        await prefs.setString('email', user.email ?? 'Email Tidak Tersedia');
        // Ambil no HP dari firestore jika sudah ada
        final freshData = await userDoc.get();
        await prefs.setString('phoneNumber', freshData.data()?['phoneNumber'] ?? '');


        if (!mounted) return;
        // 6. Navigasi ke halaman utama
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login Google Gagal: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Sembunyikan loading
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 200,
                  width: 200,
                  child: Center(
                    child: Image.asset('assets/logo_cifut.png'),
                  ),
                ),
                const SizedBox(height: 65),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                        context, MaterialPageRoute(builder: (context) => const LoginInput()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text("Masuk", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 10),
                const Text("atau", style: TextStyle(color: Colors.black)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                        context, MaterialPageRoute(builder: (context) => const DaftarAkun()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text("Buat Akun", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 35),
                Row(
                  children: const [
                    Expanded(child: Divider(color: Colors.black)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text("Atau masuk dengan", style: TextStyle(color: Colors.black)),
                    ),
                    Expanded(child: Divider(color: Colors.black)),
                  ],
                ),
                const SizedBox(height: 15),
                
                // PERBAIKAN: Tombol Google dengan Indikator Loading
                _isLoading
                    ? const CircularProgressIndicator()
                    : GestureDetector(
                        onTap: signInWithGoogle, // Panggil fungsi login google
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.grey, width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 2,
                                blurRadius: 5
                              )
                            ]
                          ),
                          child: Image.asset('assets/google.png', height: 25),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}