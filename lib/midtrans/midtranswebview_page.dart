import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'status_payment/success_page.dart';

class WebViewPage extends StatefulWidget {
  final String snapToken;
  final String? firebaseBookingPath;

  const WebViewPage({
    super.key,
    required this.snapToken,
    this.firebaseBookingPath,
  });

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool _pageFinishedLoading = false;
  bool _paymentProcessed = false;

  final String midtransClientKey = "SB-Mid-client-vg4cnVugHB1XykgM";
  final String midtransSnapJsUrl =
      "https://app.sandbox.midtrans.com/snap/snap.js";

  Future<void> _updateStatusInFirebase(
    String newStatus, // Menerima status baru, misal "success"
    Map<String, dynamic>? midtransResponseData,
  ) async {
    if (widget.firebaseBookingPath == null ||
        widget.firebaseBookingPath!.isEmpty) {
      print('Firebase booking path not provided, cannot update status.');
      return;
    }
    try {
      final DatabaseReference bookingRef = FirebaseDatabase.instance
          .ref()
          .child(widget.firebaseBookingPath!);
      // PERBAIKAN: Hanya update field 'status' dan field relevan lainnya
      Map<String, dynamic> updates = {
        'status': newStatus,
        'payment_completion_timestamp': ServerValue.timestamp,
      };
      if (midtransResponseData != null) {
        updates['midtrans_response'] = midtransResponseData;
        // Ambil info dari respons Midtrans jika perlu
        updates['midtrans_status'] = midtransResponseData['transaction_status'];
        updates['midtrans_fraud_status'] = midtransResponseData['fraud_status'];
      }
      await bookingRef.update(updates);
      print(
        'Status updated to "$newStatus" in Firebase for path: ${widget.firebaseBookingPath}',
      );
    } catch (e) {
      print('Error updating status in Firebase: $e');
    }
  }

  Future<void> _deletePendingBookingFromFirebase() async {
    if (widget.firebaseBookingPath == null ||
        widget.firebaseBookingPath!.isEmpty) {
      print('Firebase booking path not provided, cannot delete booking.');
      return;
    }
    try {
      final DatabaseReference bookingRef = FirebaseDatabase.instance
          .ref()
          .child(widget.firebaseBookingPath!);
      await bookingRef.remove();
      print(
        'Pending booking deleted from Firebase: ${widget.firebaseBookingPath}',
      );
    } catch (e) {
      print('Error deleting pending booking from Firebase: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // ... (Logika initState & HTML content tetap sama seperti sebelumnya)
    final String htmlContent = """
    <html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1.0, user-scalable=no">
        <title>Midtrans Payment</title>
        <script type="text/javascript"
                src="$midtransSnapJsUrl"
                data-client-key="$midtransClientKey"></script>
        <style>
            body { margin: 0; padding: 0; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #f0f0f0; }
            #payment-container { width: 100%; height: 100%; }
        </style>
    </head>
    <body> 
        <div id="payment-container"></div>
        <script type="text/javascript">
            function initializeAndPay(token) {
                try {
                    if (typeof snap !== 'undefined') {
                        snap.embed(token, {
                            embedId: 'payment-container',
                            onSuccess: function(result){
                                if (window.MidtransMessageHandler) {
                                    window.MidtransMessageHandler.postMessage(JSON.stringify({status: "success", data: result}));
                                }
                            },
                            onPending: function(result){
                                if (window.MidtransMessageHandler) {
                                    window.MidtransMessageHandler.postMessage(JSON.stringify({status: "pending", data: result}));
                                }
                            },
                            onError: function(result){
                                if (window.MidtransMessageHandler) {
                                    window.MidtransMessageHandler.postMessage(JSON.stringify({status: "error", data: result}));
                                }
                            },
                            onClose: function(){
                                if (window.MidtransMessageHandler) {
                                    window.MidtransMessageHandler.postMessage(JSON.stringify({status: "closed"}));
                                }
                            }
                        });
                    }
                } catch (e) { /* ... */ }
            }
        </script>
    </body>
    </html>
    """;

    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..addJavaScriptChannel(
            'MidtransMessageHandler',
            onMessageReceived: (JavaScriptMessage message) {
              if (_paymentProcessed) return;

              try {
                final dynamic decodedMessage = jsonDecode(message.message);

                if (decodedMessage is Map<String, dynamic>) {
                  final responseMap = decodedMessage;
                  String status =
                      responseMap['status']?.toString() ?? 'unknown_status';
                  dynamic data = responseMap['data'];

                  _paymentProcessed = true;
                  if (!mounted) return;

                  Map<String, dynamic>? midtransResponseData =
                      (data is Map<String, dynamic>) ? data : null;

                  if (status == "success") {
                    _updateStatusInFirebase(
                      "success",
                      midtransResponseData,
                    ); // Panggil fungsi yang sudah diperbaiki
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SuccessPage(),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  } else if (status == "pending") {
                    _updateStatusInFirebase(
                      "pending",
                      midtransResponseData,
                    ); // Update status jadi pending
                    Navigator.pop(context);
                  } else {
                    // Untuk 'error', 'closed', atau status lain, hapus booking
                    _deletePendingBookingFromFirebase();
                    Navigator.pop(context);
                  }
                }
              } catch (e) {
                print("Error parsing message from WebView: $e");
                if (mounted) {
                  _paymentProcessed = true;
                  _deletePendingBookingFromFirebase(); // Hapus juga jika ada error parsing
                  Navigator.pop(context);
                }
              }
            },
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (String url) {
                if (url.startsWith('data:text/html')) {
                  if (!mounted) return;
                  setState(() {
                    _pageFinishedLoading = true;
                  });
                  _controller.runJavaScript(
                    'initializeAndPay("${widget.snapToken}");',
                  );
                }
              },
              onWebResourceError: (WebResourceError error) {
                if (mounted && !_paymentProcessed) {
                  _paymentProcessed = true;
                  _deletePendingBookingFromFirebase();
                  if (Navigator.canPop(context)) Navigator.pop(context);
                }
              },
            ),
          )
          ..loadRequest(
            Uri.dataFromString(
              htmlContent,
              mimeType: 'text/html',
              encoding: Encoding.getByName('utf-8'),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        if (!_paymentProcessed && mounted) {
          _paymentProcessed = true;
          _deletePendingBookingFromFirebase();
        }
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
              if (!_paymentProcessed && mounted) {
                _paymentProcessed = true;
                _deletePendingBookingFromFirebase();
              }
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body:
            _pageFinishedLoading
                ? WebViewWidget(controller: _controller)
                : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
