import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_input.dart'; // PASTIKAN INI ADALAH PATH YANG BENAR KE HALAMAN LOGIN ANDA

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmNewPasswordController;

  bool _isLoading = false;
  User? _currentUser;

  // Variabel state untuk visibilitas kata sandi
  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmNewPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneNumberController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmNewPasswordController = TextEditingController();
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null && mounted) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _fullNameController.text =
            prefs.getString('fullName') ?? _currentUser!.displayName ?? '';
        _phoneNumberController.text =
            prefs.getString('phoneNumber') ?? _currentUser!.phoneNumber ?? '';
      });

      try {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUser!.uid)
                .get();
        if (userDoc.exists && mounted) {
          setState(() {
            _fullNameController.text =
                userDoc.get('fullName') ?? _fullNameController.text;
            _phoneNumberController.text =
                userDoc.get('phoneNumber') ?? _phoneNumberController.text;
          });
        }
      } catch (e) {
        print("Error loading user data from Firestore: $e");
      }
    }
  }

  Future<void> _saveChanges() async {
    // ... (Logika _saveChanges Anda tetap sama seperti sebelumnya)
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengguna tidak ditemukan. Mohon login ulang.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    bool profileDataActuallyChanged = false;
    bool passwordChangeAttempted =
        _newPasswordController.text.trim().isNotEmpty;
    SharedPreferences prefs = await SharedPreferences.getInstance();

    try {
      // 1. Update Nama Lengkap dan Nomor HP (jika ada perubahan)
      Map<String, dynamic> updatedFirestoreData = {};
      String currentFullNameInPrefs = prefs.getString('fullName') ?? '';
      String currentPhoneNumberInPrefs = prefs.getString('phoneNumber') ?? '';

      if (_fullNameController.text.trim() != currentFullNameInPrefs) {
        updatedFirestoreData['fullName'] = _fullNameController.text.trim();
        profileDataActuallyChanged = true;
      }
      if (_phoneNumberController.text.trim() != currentPhoneNumberInPrefs) {
        updatedFirestoreData['phoneNumber'] =
            _phoneNumberController.text.trim();
        profileDataActuallyChanged = true;
      }

      if (updatedFirestoreData.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .update(updatedFirestoreData);

        if (updatedFirestoreData.containsKey('fullName')) {
          await prefs.setString('fullName', updatedFirestoreData['fullName']);
        }
        if (updatedFirestoreData.containsKey('phoneNumber')) {
          await prefs.setString(
            'phoneNumber',
            updatedFirestoreData['phoneNumber'],
          );
        }
      }

      // 2. Proses Ubah Kata Sandi jika diisi
      if (passwordChangeAttempted) {
        String currentPassword = _currentPasswordController.text.trim();
        String newPassword = _newPasswordController.text.trim();
        // Validasi tambahan untuk konfirmasi password sudah ada di form validator

        if (currentPassword.isEmpty) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Kata sandi saat ini harus diisi untuk mengubah kata sandi.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          setState(() => _isLoading = false);
          return;
        }
        // Validasi panjang kata sandi baru sudah ada di form validator

        // Re-autentikasi pengguna
        AuthCredential credential = EmailAuthProvider.credential(
          email: _currentUser!.email!,
          password: currentPassword,
        );
        await _currentUser!.reauthenticateWithCredential(credential);

        // Jika re-autentikasi berhasil, update kata sandi
        await _currentUser!.updatePassword(newPassword);

        profileDataActuallyChanged = true;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Kata sandi berhasil diperbarui. Anda akan logout.',
              ),
              backgroundColor: Colors.green,
            ),
          );

          await FirebaseAuth.instance.signOut();
          await prefs.remove('fullName');
          await prefs.remove('email');
          await prefs.remove('phoneNumber');
          await prefs.remove('rememberMe');

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginInput()),
              (Route<dynamic> route) => false,
            );
          }
          return;
        }
      }

      if (profileDataActuallyChanged && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil diperbarui!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else if (!passwordChangeAttempted &&
          !profileDataActuallyChanged &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada perubahan untuk disimpan.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Terjadi kesalahan saat memproses permintaan Anda.";
      if (e.code == 'wrong-password') {
        errorMessage = 'Kata sandi saat ini salah. Silakan coba lagi.';
      } else if (e.code == 'requires-recent-login') {
        errorMessage =
            'Operasi ini sensitif dan memerlukan login baru-baru ini. Silakan login ulang dan coba lagi.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Kata sandi baru terlalu lemah.';
      } else {
        errorMessage = 'Gagal memperbarui: ${e.message ?? e.code}';
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      print("FirebaseAuthException: ${e.code} - ${e.message}");
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui profil: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      print("Error saving changes: $e");
    } finally {
      if (mounted) {
        if (!(passwordChangeAttempted &&
            FirebaseAuth.instance.currentUser == null)) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[600],
      appBar: AppBar(
        backgroundColor: Colors.blue[600],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _isLoading ? null : Navigator.pop(context),
        ),
        title: const Text("Edit Profil", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Center(
                /* ... Foto Profil ... */
                child: Stack(
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 60, color: Colors.grey),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        backgroundColor: Colors.blue[900],
                        radius: 18,
                        child: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _buildInputField(
                controller: _fullNameController,
                icon: Icons.person,
                hintText: "Nama Lengkap",
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama lengkap tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              _buildInputField(
                controller: _phoneNumberController,
                icon: Icons.phone,
                hintText: "Nomor HP",
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nomor HP tidak boleh kosong';
                  }
                  if (value.length < 10 || value.length > 15) {
                    return 'Nomor HP tidak valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text(
                "Ganti Kata Sandi (Isi jika ingin diubah)",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 10),
              _buildInputField(
                controller: _currentPasswordController,
                icon: Icons.lock_clock_outlined,
                hintText: "Kata Sandi Saat Ini",
                isPassword: true,
                obscureTextToggle: _isCurrentPasswordVisible, // Gunakan state
                onToggleObscureText: () {
                  // Fungsi untuk toggle
                  setState(() {
                    _isCurrentPasswordVisible = !_isCurrentPasswordVisible;
                  });
                },
                validator: (value) {
                  if (_newPasswordController.text.isNotEmpty &&
                      (value == null || value.isEmpty)) {
                    return 'Kata sandi saat ini diperlukan';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              _buildInputField(
                controller: _newPasswordController,
                icon: Icons.lock_outline,
                hintText: "Kata Sandi Baru (min. 6 karakter)",
                isPassword: true,
                obscureTextToggle: _isNewPasswordVisible, // Gunakan state
                onToggleObscureText: () {
                  // Fungsi untuk toggle
                  setState(() {
                    _isNewPasswordVisible = !_isNewPasswordVisible;
                  });
                },
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length < 6) {
                    return 'Kata sandi baru minimal 6 karakter';
                  }
                  if (value != null &&
                      value.isNotEmpty &&
                      _confirmNewPasswordController.text.isEmpty) {
                    return 'Mohon konfirmasi kata sandi baru Anda';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              _buildInputField(
                controller: _confirmNewPasswordController,
                icon: Icons.lock,
                hintText: "Konfirmasi Kata Sandi Baru",
                isPassword: true,
                obscureTextToggle:
                    _isConfirmNewPasswordVisible, // Gunakan state
                onToggleObscureText: () {
                  // Fungsi untuk toggle
                  setState(() {
                    _isConfirmNewPasswordVisible =
                        !_isConfirmNewPasswordVisible;
                  });
                },
                validator: (value) {
                  if (_newPasswordController.text.isNotEmpty &&
                      (value == null || value.isEmpty)) {
                    return 'Mohon konfirmasi kata sandi baru Anda';
                  }
                  if (_newPasswordController.text.isNotEmpty &&
                      value != _newPasswordController.text) {
                    return 'Konfirmasi kata sandi tidak cocok';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900],
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                          : const Text(
                            "Simpan Perubahan",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    bool isPassword = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool obscureTextToggle = false, // Tambahkan parameter ini
    VoidCallback? onToggleObscureText, // Tambahkan parameter ini
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !obscureTextToggle, // Logika untuk obscureText
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: Colors.blue[700]),
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.blue.shade800, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.red, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.red, width: 2.0),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 15.0,
          horizontal: 10.0,
        ),
        // Tambahkan suffixIcon untuk toggle visibilitas kata sandi
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
      validator: validator,
      style: const TextStyle(color: Colors.black87),
      cursorColor: Colors.blue[900],
    );
  }
}
