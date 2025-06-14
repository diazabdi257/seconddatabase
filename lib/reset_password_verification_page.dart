import 'package:flutter/material.dart';
import 'lupa_password.dart'; // Pastikan file ini ada

class ResetPasswordVerificationPage extends StatefulWidget {
  const ResetPasswordVerificationPage({super.key});

  @override
  State<ResetPasswordVerificationPage> createState() =>
      _ResetPasswordVerificationPageState();
}

class _ResetPasswordVerificationPageState
    extends State<ResetPasswordVerificationPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  bool _showCodeField = false;
  String _errorText = '';

  void _sendCode() {
    setState(() {
      _showCodeField = true;
      _errorText = '';
    });
  }

  void _verifyCode() {
    if (_codeController.text == '123456') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LupaPassword()),
      );
    } else {
      setState(() {
        _errorText = 'Kode verifikasi salah';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[600],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tombol Back
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),

              const SizedBox(height: 20),

              // Placeholder Gambar
              Center(
                child: Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Text("Gambar")),
                ),
              ),

              const SizedBox(height: 20),

              // Judul
              const Center(
                child: Text(
                  "Reset Password",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Input Email
              _buildInputField(Icons.email, "Masukkan Email", _emailController),

              const SizedBox(height: 20),

              // Tombol kirim kode
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sendCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900],
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Kirim Kode Verifikasi",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),

              if (_showCodeField) ...[
                const SizedBox(height: 30),
                _buildInputField(Icons.verified, "Kode Verifikasi", _codeController),
                if (_errorText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _errorText,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[900],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Verifikasi",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(IconData icon, String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon),
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
