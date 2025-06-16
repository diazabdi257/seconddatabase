import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Mengubah menjadi StatefulWidget untuk menangani state
class LupaPassword extends StatefulWidget {
  const LupaPassword({super.key});

  @override
  State<LupaPassword> createState() => _LupaPasswordState();
}

class _LupaPasswordState extends State<LupaPassword> {
  // Controller untuk input email
  final _emailController = TextEditingController();
  // State untuk menampilkan indikator loading
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Fungsi untuk mengirim link reset password ke email pengguna menggunakan Firebase Auth
  Future<void> _sendResetLink() async {
    // Validasi input email tidak boleh kosong
    if (_emailController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email tidak boleh kosong.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true; // Mulai loading
    });

    try {
      // Memanggil fungsi Firebase untuk mengirim email reset password
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;
      // Tampilkan pesan sukses jika berhasil
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link untuk reset password telah dikirim ke email Anda.'),
          backgroundColor: Colors.green,
        ),
      );
      // Kembali ke halaman sebelumnya setelah berhasil
      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      // Menangani error dari Firebase
      String errorMessage = "Terjadi kesalahan, silakan coba lagi.";
      if (e.code == 'user-not-found') {
        errorMessage = 'Email yang Anda masukkan tidak terdaftar.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Format email yang Anda masukkan tidak valid.';
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      // Menangani error umum lainnya
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Hentikan loading setelah proses selesai
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Latar belakang diubah menjadi putih
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Tombol Back di pojok kiri atas
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () {
                    // Jangan izinkan kembali jika sedang loading
                    if (!_isLoading) {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                ),
              ),

              const SizedBox(height: 20),

              // Logo Aplikasi
              SizedBox(
                height: 150,
                width: 150,
                child: Image.asset('assets/logo_cifut.png'),
              ),

              const SizedBox(height: 20),

              // Judul dan Subjudul
              const Text(
                "Lupa Kata Sandi?",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Masukkan email akun Anda untuk menerima link reset kata sandi.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 40),

              // Input Field untuk Email
              _buildEmailInputField(),

              const SizedBox(height: 30),

              // Tombol "Kirim Link Reset"
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  // Tombol dinonaktifkan saat loading
                  onPressed: _isLoading ? null : _sendResetLink,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      // Tampilkan CircularProgressIndicator saat loading
                      ? const SizedBox(
                          width: 25,
                          height: 25,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      // Tampilkan teks jika tidak loading
                      : const Text(
                          "Kirim Link Reset",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget khusus untuk input field email agar lebih rapi
  Widget _buildEmailInputField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[100],
        prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
        hintText: 'Email Akun Anda',
        hintStyle: TextStyle(color: Colors.grey[500]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none, // Hilangkan border default
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
