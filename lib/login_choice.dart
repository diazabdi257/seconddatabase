import 'package:flutter/material.dart';
import 'package:seconddatabase/daftar_akun.dart';
import 'package:seconddatabase/login_input.dart';




class LoginChoice extends StatelessWidget {
  const LoginChoice({super.key});

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
                // LOGO
                Container(
                  height: 200,
                  width: 200,
                  child: Center(
                    child: Image.asset('assets/logo_cifut.png'),
                    // Ganti nanti dengan: Image.asset('assets/logo.png')
                  ),
                ),

                const SizedBox(height: 65),

                // Button Masuk
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                          context, MaterialPageRoute(builder: (context) => const LoginInput())
                        );
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
                  child: const Text(
                    "Masuk",
                    style: TextStyle(color: Colors.white),
                  ),
                ),

                const SizedBox(height: 10),

                const Text("atau", style: TextStyle(color: Colors.black)),

                const SizedBox(height: 10),

                // Button Buat Akun
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                          context, MaterialPageRoute(builder: (context) => const DaftarAkun())
                        );
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
                  child: const Text(
                    "Buat Akun",
                    style: TextStyle(color: Colors.white),
                  ),
                ),

                const SizedBox(height: 35),

                // Garis pembatas dan teks "Atau masuk dengan"
                Row(
                  children: const [
                    Expanded(child: Divider(color: Colors.black)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        "Atau masuk dengan",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.black)),
                  ],
                ),

                const SizedBox(height: 15),

                // Tombol Google
                GestureDetector(
                  onTap: () {
                    print("Tombol Google diklik!");
                    // Tambahkan navigasi/login di sini nanti kalau butuh
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.grey, // Warna border
                        width: 1.0, // Ketebalan border
                      ),
                    ),
                    child: Image.asset(
                      'assets/google.png', 
                      height: 25,
                    ),
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
