import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:seconddatabase/firebase_options.dart'; // Pastikan path ini benar
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './login_choice.dart'; // Pastikan path ini benar

// Import untuk inisialisasi locale
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Pastikan ini ada di baris pertama

  // Inisialisasi locale untuk Bahasa Indonesia
  await initializeDateFormatting('id_ID', null);


  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const LoginChoice(), // Halaman awal aplikasi Anda
      debugShowCheckedModeBanner: false,
    );
  }
}
