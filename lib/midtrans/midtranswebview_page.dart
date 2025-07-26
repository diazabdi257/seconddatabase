import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'; // <-- PERUBAHAN: Import baru
import 'package:firebase_database/firebase_database.dart';
import 'status_payment/success_page.dart';

class WebViewPage extends StatefulWidget {
  final String url;
  final String? firebaseBookingPath;

  const WebViewPage({
    super.key,
    required this.url,
    this.firebaseBookingPath,
  });

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? _webViewController;
  bool _isHandlingNavigation = false;
  double _progress = 0;

  // Opsi untuk InAppWebView agar lebih optimal di Android
  final InAppWebViewSettings _options = InAppWebViewSettings(
    useHybridComposition: true, // Salah satu setelan paling penting untuk stabilitas
    javaScriptEnabled: true,
    thirdPartyCookiesEnabled: true,
    useShouldOverrideUrlLoading: true,
  );

  Future<void> _handlePaymentSuccess() async {
    await _updateStatusInFirebase("success");
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SuccessPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _updateStatusInFirebase(String newStatus) async {
    if (widget.firebaseBookingPath == null || widget.firebaseBookingPath!.isEmpty) return;
    try {
      final DatabaseReference bookingRef = FirebaseDatabase.instance.ref().child(widget.firebaseBookingPath!);
      await bookingRef.update({
        'status': newStatus,
        'payment_completion_timestamp': ServerValue.timestamp,
      });
      print('Status updated to "$newStatus"');
    } catch (e) {
      print('Error updating status in Firebase: $e');
    }
  }

  Future<void> _deletePendingBookingFromFirebase() async {
    if (widget.firebaseBookingPath == null || widget.firebaseBookingPath!.isEmpty) return;
    try {
      final DatabaseReference bookingRef = FirebaseDatabase.instance.ref().child(widget.firebaseBookingPath!);
      await bookingRef.remove();
      print('Pending booking deleted from Firebase: ${widget.firebaseBookingPath}');
    } catch (e) {
      print('Error deleting pending booking: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        _deletePendingBookingFromFirebase();
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Proses Pembayaran'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _deletePendingBookingFromFirebase();
              Navigator.pop(context);
            },
          ),
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialSettings: _options,
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onLoadError: (controller, url, code, message) {
                 print('Web resource error: $message');
                 if (!_isHandlingNavigation && mounted) {
                   _isHandlingNavigation = true;
                   _deletePendingBookingFromFirebase();
                   Navigator.pop(context);
                 }
              },
              onProgressChanged: (controller, progress) {
                if (mounted) {
                  setState(() {
                    _progress = progress / 100;
                  });
                }
              },
              // Ini adalah pengganti NavigationDelegate untuk mencegat URL
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;
                if (uri != null) {
                  print("InAppWebView is navigating to: $uri");
                  
                  // Logika yang sama untuk mendeteksi transaksi selesai
                  if (uri.toString().contains('transaction_status=capture') || 
                      uri.toString().contains('transaction_status=settlement')) {
                    if (!_isHandlingNavigation) {
                      _isHandlingNavigation = true;
                      _handlePaymentSuccess();
                    }
                    return NavigationActionPolicy.CANCEL; // Hentikan navigasi
                  }
                }
                return NavigationActionPolicy.ALLOW; // Izinkan navigasi lainnya
              },
            ),
            if (_progress < 1.0)
              LinearProgressIndicator(value: _progress),
          ],
        ),
      ),
    );
  }
}