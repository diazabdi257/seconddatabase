import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'package:seconddatabase/main_screen.dart'; // Halaman utama setelah login
import 'package:seconddatabase/daftar_akun.dart'; // Halaman pendaftaran akun
import 'lupa_password.dart';

class LoginInput extends StatefulWidget {
  const LoginInput({super.key});

  @override
  State<LoginInput> createState() => _LoginInputState();
}

class _LoginInputState extends State<LoginInput> {
  bool _rememberMe = false; // Status checkbox
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false; // State untuk visibilitas password

  @override
  void initState() {
    super.initState();
    _loadCredentials(); // Muat kredensial ketika halaman dimuat
    _isPasswordVisible = false; // Pastikan password tersembunyi saat awal
  }

  Future<void> _loadCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _emailController.text = prefs.getString('email') ?? '';
      _passwordController.text = prefs.getString('password') ?? '';
      _rememberMe = prefs.getBool('rememberMe') ?? false;
    });
  }

  Future<void> _saveCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('email', _emailController.text);
      await prefs.setString('password', _passwordController.text);
      await prefs.setBool('rememberMe', true);
    } else {
      await prefs.remove('email');
      await prefs.remove('password');
      await prefs.remove('rememberMe');
    }
  }

  Future<void> _login() async {
    if (!mounted) return;
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email atau kata sandi tidak boleh kosong'),
        ),
      );
      return;
    }

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(), // Tambahkan trim
            password: _passwordController.text.trim(),
          ); // Tambahkan trim

      User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot userData =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userData.exists && mounted) {
          // Cek mounted sebelum setState/Navigator
          String fullName = userData.get('fullName') ?? 'Nama Tidak Tersedia';
          String email = userData.get('email') ?? 'Email Tidak Tersedia';
          String phoneNumber =
              userData.get('phoneNumber') ?? 'Nomor Tidak Tersedia';

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('fullName', fullName);
          await prefs.setString('email', email);
          await prefs.setString('phoneNumber', phoneNumber);

          await _saveCredentials(); // Panggil setelah semua data SharedPreferences user utama disimpan

          if (mounted) {
            // Cek mounted lagi sebelum navigasi
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainScreen()),
            );
          }
        } else if (!userData.exists && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data pengguna tidak ditemukan di database.'),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Login Gagal: Terjadi kesalahan.";
      if (e.code == 'user-not-found') {
        errorMessage = 'Email tidak terdaftar.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Kata sandi salah.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Format email tidak valid.';
      } else if (e.code == 'network-request-failed') {
        errorMessage =
            'Gagal terhubung ke jaringan. Periksa koneksi internet Anda.';
      } else {
        errorMessage = 'Login Gagal: ${e.message}';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
      print("FirebaseAuthException: ${e.code} - ${e.message}");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Login Gagal: ${e.toString()}")));
      }
      print("Login Error: $e");
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ), // Ganti padding horizontal
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.black),
              ),
              const SizedBox(height: 35),
              Center(
                child: SizedBox(
                  // Menggunakan SizedBox agar lebih konsisten
                  height: 150,
                  width: 150,
                  child: Image.asset(
                    'assets/logo_cifut.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Center(
                child: Text(
                  "Selamat Datang",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const Center(
                child: Text(
                  "Masuk ke akun anda",
                  style: TextStyle(fontSize: 14, color: Colors.black),
                ),
              ),
              const SizedBox(height: 30),
              Form(
                // Sebaiknya tambahkan GlobalKey<FormState> jika ada validasi form
                child: Column(
                  children: [
                    // Email
                    TextFormField(
                      // Ganti Container(child: TextFormField(...)) menjadi TextFormField langsung
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.email),
                        hintText: 'Email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          // Tambahkan border yang lebih jelas
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                            color: Colors.grey.shade400,
                            width: 1.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Password
                    TextFormField(
                      // Ganti Container(child: TextFormField(...)) menjadi TextFormField langsung
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible, // Kontrol visibilitas
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.lock),
                        hintText: 'Kata Sandi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                            color: Colors.grey.shade400,
                            width: 1.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2.0,
                          ),
                        ),
                        suffixIcon: IconButton(
                          // Tambahkan IconButton untuk toggle
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (val) {
                            if (mounted) {
                              setState(() {
                                _rememberMe = val!;
                              });
                            }
                          },
                          checkColor: Colors.white,
                          activeColor: Colors.blue, // Lebih kontras
                        ),
                        const Text(
                          "Ingat Saya",
                          style: TextStyle(color: Colors.black),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LupaPassword(),
                              ),
                            );
                          },
                          child: const Text(
                            "Lupa Sandi?",
                            style: TextStyle(
                              color: Colors.blue,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, // Agar tombol full width
                      height: 50, // Tinggi tombol yang konsisten
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ), // Sesuaikan padding
                        ),
                        child: const Text(
                          "Masuk",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Belum punya akun?",
                    style: TextStyle(color: Colors.black),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DaftarAkun(),
                        ),
                      );
                    },
                    child: const Text(
                      "Buat akun",
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ), // Tekankan
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
