import 'package:flutter/material.dart';
import '../../main_screen.dart'; // Pastikan path ke MainScreen benar

class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Transaksi'),
        automaticallyImplyLeading:
            false, // Menghilangkan tombol kembali default
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 135.0,
            ),
            const SizedBox(height: 24.0),
            const Text(
              'Transaksi Berhasil!',
              style: TextStyle(fontSize: 26.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            const Text(
              'Terima kasih telah melakukan pembayaran.',
              style: TextStyle(fontSize: 18.0),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48.0),
            ElevatedButton(
              onPressed: () {
                // Mengarahkan pengguna kembali ke MainScreen dan menghapus semua halaman sebelumnya
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const MainScreen()),
                  (Route<dynamic> route) =>
                      false, // Ini akan menghapus semua route di stack
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
              ),
              child: const Text(
                'Kembali ke Beranda', // Teks tombol disesuaikan
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
