import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'login_choice.dart'; // Arahkan ke halaman login_choice setelah berhasil mendaftar
import 'package:flutter/services.dart'; // Untuk validasi input

class DaftarAkun extends StatefulWidget {
  const DaftarAkun({super.key});

  @override
  _DaftarAkunState createState() => _DaftarAkunState();
}

class _DaftarAkunState extends State<DaftarAkun> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State untuk visibilitas password
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    // Pastikan password tersembunyi saat awal
    _isPasswordVisible = false;
    _isConfirmPasswordVisible = false;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!mounted) return; // Pastikan widget masih mounted

    // Validasi input kosong (opsional tapi direkomendasikan)
    if (_fullNameController.text.isEmpty ||
        _phoneNumberController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Semua field harus diisi.")));
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kata sandi dan konfirmasi kata sandi tidak cocok"),
        ),
      );
      return;
    }

    // Validasi panjang password (minimal 6 karakter adalah standar Firebase Auth)
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kata sandi minimal 6 karakter.")),
      );
      return;
    }

    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      if (userCredential.user != null) {
        // Update display name di Firebase Auth (opsional)
        await userCredential.user!.updateDisplayName(
          _fullNameController.text.trim(),
        );

        // Simpan data pengguna ke Firestore
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': _emailController.text.trim(),
          'fullName': _fullNameController.text.trim(),
          'phoneNumber': _phoneNumberController.text.trim(),
          'createdAt': DateTime.now().toIso8601String(),
          'uid': userCredential.user!.uid,
        });

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Akun berhasil dibuat!")));

        Navigator.pushAndRemoveUntil(
          // Gunakan pushAndRemoveUntil untuk kembali ke login dan hapus stack
          context,
          MaterialPageRoute(builder: (context) => const LoginChoice()),
          (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      print("Error during sign-up: ${e.code} - ${e.message}");
      String errorMessage = "Terjadi error dalam membuat akun.";
      if (e.code == 'weak-password') {
        errorMessage = 'Kata sandi yang diberikan terlalu lemah.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Email sudah digunakan oleh akun lain.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Format email tidak valid.';
      } else {
        errorMessage = e.message ?? errorMessage;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    } catch (e) {
      print("Generic error during sign-up: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Terjadi error tidak diketahui: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: SizedBox(
                    // Gunakan SizedBox agar konsisten
                    height: 120,
                    width: 120,
                    child: Image.asset(
                      'assets/logo_cifut.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    "Daftar",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    "Buat akun anda",
                    style: TextStyle(fontSize: 14, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 30),
                _buildInputField(
                  icon: Icons.person,
                  hintText: 'Nama Lengkap',
                  controller: _fullNameController,
                ),
                const SizedBox(height: 15),
                _buildInputField(
                  icon: Icons.phone,
                  hintText: 'No Telepon',
                  controller: _phoneNumberController,
                  isPhone: true,
                ),
                const SizedBox(height: 15),
                _buildInputField(
                  icon: Icons.email,
                  hintText: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),
                _buildInputField(
                  icon: Icons.lock,
                  hintText: 'Kata Sandi (min. 6 karakter)',
                  controller: _passwordController,
                  isPassword: true,
                  obscureTextToggle: _isPasswordVisible,
                  onToggleObscureText: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                const SizedBox(height: 15),
                _buildInputField(
                  icon: Icons.lock,
                  hintText: 'Konfirmasi Kata Sandi',
                  controller: _confirmPasswordController,
                  isPassword: true,
                  obscureTextToggle: _isConfirmPasswordVisible,
                  onToggleObscureText: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity, // Agar tombol full width
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Daftar",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20), // Tambahan spasi di bawah
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required IconData icon,
    required String hintText,
    required TextEditingController controller,
    bool isPassword = false,
    bool isPhone = false,
    TextInputType? keyboardType, // Tambahkan ini untuk fleksibilitas
    // Parameter untuk toggle password
    bool obscureTextToggle = false,
    VoidCallback? onToggleObscureText,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !obscureTextToggle, // Logika untuk obscureText
      keyboardType:
          isPhone ? TextInputType.phone : keyboardType ?? TextInputType.text,
      inputFormatters: isPhone ? [FilteringTextInputFormatter.digitsOnly] : [],
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(
          icon,
          color: Colors.grey[700],
        ), // Warna ikon yang lebih lembut
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[500]), // Warna hint
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ), // Border default lebih lembut
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 1.5,
          ), // Border saat fokus
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14.0,
          horizontal: 12.0,
        ), // Sesuaikan padding
        suffixIcon:
            isPassword
                ? IconButton(
                  icon: Icon(
                    obscureTextToggle ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey[600],
                  ),
                  onPressed: onToggleObscureText,
                )
                : null,
      ),
    );
  }
}
