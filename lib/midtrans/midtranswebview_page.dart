import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart'; // Import Firebase
import 'status_payment/success_page.dart'; // Halaman sukses Anda
// import '../../main_screen.dart'; // Jika Anda ingin navigasi kembali ke MainScreen

class WebViewPage extends StatefulWidget {
  final String snapToken;
  final String? firebaseBookingPath; // Path untuk update status atau delete di Firebase

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
  bool _paymentProcessed = false; // Flag untuk mencegah multiple callback/action

  final String midtransClientKey =
      "SB-Mid-client-vg4cnVugHB1XykgM"; // PASTIKAN INI BENAR
  final String midtransSnapJsUrl =
      "https://app.sandbox.midtrans.com/snap/snap.js";

  // Fungsi untuk mengupdate status jika bukan pembatalan total
  Future<void> _updatePaymentStatusInFirebase(
    String status,
    Map<String, dynamic>? midtransResponseData,
  ) async {
    if (widget.firebaseBookingPath == null ||
        widget.firebaseBookingPath!.isEmpty) {
      print('Firebase booking path not provided, cannot update status.');
      return;
    }
    try {
      final DatabaseReference bookingRef =
          FirebaseDatabase.instance.ref().child(widget.firebaseBookingPath!);
      Map<String, dynamic> updates = {
        'payment_status': status,
        'payment_completion_timestamp': ServerValue.timestamp,
      };
      if (midtransResponseData != null) {
        updates['midtrans_response'] = midtransResponseData;
      }
      await bookingRef.update(updates);
      print(
          'Payment status updated to "$status" in Firebase for path: ${widget.firebaseBookingPath}');
    } catch (e) {
      print('Error updating payment status in Firebase: $e');
    }
  }

  // Fungsi baru untuk menghapus booking dari Firebase jika dibatalkan
  Future<void> _deletePendingBookingFromFirebase() async {
    if (widget.firebaseBookingPath == null ||
        widget.firebaseBookingPath!.isEmpty) {
      print('Firebase booking path not provided, cannot delete booking.');
      return;
    }
    try {
      final DatabaseReference bookingRef =
          FirebaseDatabase.instance.ref().child(widget.firebaseBookingPath!);
      await bookingRef.remove();
      print('Pending booking deleted from Firebase: ${widget.firebaseBookingPath}');
    } catch (e) {
      print('Error deleting pending booking from Firebase: $e');
      // Anda bisa menampilkan SnackBar di sini jika gagal hapus, tapi mungkin tidak krusial bagi user
    }
  }


  @override
  void initState() {
    super.initState();

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
            .loader { border: 8px solid #f3f3f3; border-top: 8px solid #3498db; border-radius: 50%; width: 60px; height: 60px; animation: spin 2s linear infinite; position: absolute; top: 50%; left: 50%; margin-top: -30px; margin-left: -30px; }
            @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        </style>
    </head>
    <body> 
        <div id="payment-loading" class="loader"></div>
        <div id="payment-container"></div>
        <script type="text/javascript">
            function initializeAndPay(token) {
                try {
                    var loader = document.getElementById('payment-loading');
                    if (loader) { loader.style.display = 'none'; }

                    if (typeof snap !== 'undefined') {
                        snap.embed(token, {
                            embedId: 'payment-container',
                            onSuccess: function(result){
                                console.log('Success:', JSON.stringify(result));
                                if (window.MidtransMessageHandler) {
                                    window.MidtransMessageHandler.postMessage(JSON.stringify({status: "success", data: result}));
                                }
                            },
                            onPending: function(result){
                                console.log('Pending:', JSON.stringify(result));
                                if (window.MidtransMessageHandler) {
                                    window.MidtransMessageHandler.postMessage(JSON.stringify({status: "pending", data: result}));
                                }
                            },
                            onError: function(result){
                                console.log('Error:', JSON.stringify(result));
                                if (window.MidtransMessageHandler) {
                                    window.MidtransMessageHandler.postMessage(JSON.stringify({status: "error", data: result}));
                                }
                            },
                            onClose: function(){ // Ketika pengguna menutup UI Snap
                                console.log('customer closed the Snap UI');
                                if (window.MidtransMessageHandler) {
                                    window.MidtransMessageHandler.postMessage(JSON.stringify({status: "closed"}));
                                }
                            }
                        });
                    } else {
                        console.error('Snap.js is not loaded yet or snap is undefined.');
                        if (window.MidtransMessageHandler) {
                           window.MidtransMessageHandler.postMessage(JSON.stringify({status: "js_error", data: {message: "Snap.js not loaded"}}));
                        }
                    }
                } catch (e) {
                    console.error('Error in initializeAndPay:', e);
                    if (window.MidtransMessageHandler) {
                        window.MidtransMessageHandler.postMessage(JSON.stringify({status: "js_exception", data: {message: e.toString()}}));
                    }
                }
            }
        </script>
    </body>
    </html>
    """;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'MidtransMessageHandler',
        onMessageReceived: (JavaScriptMessage message) {
          if (_paymentProcessed) return;

          print("Pesan dari WebView: ${message.message}");
          try {
            final dynamic decodedMessage = jsonDecode(message.message);

            if (decodedMessage is Map<String, dynamic>) {
              final responseMap = decodedMessage;
              String status = responseMap['status']?.toString() ?? 'unknown_status';
              dynamic data = responseMap['data'];

              _paymentProcessed = true; 
              if (!mounted) return;

              Map<String, dynamic>? midtransResponseData = (data is Map<String, dynamic>) ? data : null;
              String errorMessageDetail = 'Error tidak diketahui dari Midtrans.';
              
              if (midtransResponseData != null && midtransResponseData['validation_messages'] is List && (midtransResponseData['validation_messages'] as List).isNotEmpty) {
                  errorMessageDetail = (midtransResponseData['validation_messages'] as List).join(", ");
              } else if (midtransResponseData != null && midtransResponseData['error_messages'] is List && (midtransResponseData['error_messages'] as List).isNotEmpty) {
                  errorMessageDetail = (midtransResponseData['error_messages'] as List).join(", ");
              } else if (data is Map && data.containsKey('message') && data['message'] != null) {
                errorMessageDetail = data['message'].toString();
              } else if (data is List && data.isNotEmpty && data[0] is Map && data[0].containsKey('message') && data[0]['message'] != null) {
                errorMessageDetail = data[0]['message'].toString();
              } else if (data is String && data.isNotEmpty) {
                errorMessageDetail = data;
              }

              if (status == "success") {
                _updatePaymentStatusInFirebase("success", midtransResponseData);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const SuccessPage()),
                  (Route<dynamic> route) => false,
                );
              } else if (status == "pending") {
                _updatePaymentStatusInFirebase("pending", midtransResponseData);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Pembayaran Anda tertunda."), backgroundColor: Colors.orange),
                );
                Navigator.pop(context); 
              } else if (status == "error" || status == "js_error" || status == "js_exception") {
                _updatePaymentStatusInFirebase("error", midtransResponseData); 
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Pembayaran gagal: $errorMessageDetail"), backgroundColor: Colors.red),
                );
                Navigator.pop(context);
              } else if (status == "closed") {
                // Jika pengguna menutup UI Snap, hapus booking 'pending'
                _deletePendingBookingFromFirebase(); 
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Anda menutup jendela pembayaran."), backgroundColor: Colors.grey),
                );
                Navigator.pop(context);
              } else {
                print("Unknown payment status received: $status with data: $data");
                _updatePaymentStatusInFirebase("unknown_status ($status)", midtransResponseData);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Menerima status pembayaran tidak diketahui."), backgroundColor: Colors.orange),
                );
                Navigator.pop(context);
              }
            } else {
              print("Received non-map or invalid message from WebView: ${message.message}");
              if(mounted){
                _paymentProcessed = true; 
                _updatePaymentStatusInFirebase("invalid_message_format", {"raw_message": message.message});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Format pesan pembayaran tidak valid dari WebView."), backgroundColor: Colors.red),
                );
                Navigator.pop(context);
              }
            }
          } catch (e) {
            print("Error parsing message from WebView: $e. Original message: ${message.message}");
            if (mounted) {
              _paymentProcessed = true;
              _updatePaymentStatusInFirebase("client_parsing_error", {"raw_message": message.message, "error": e.toString()});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Terjadi kesalahan internal saat memproses respons pembayaran."), backgroundColor: Colors.red),
              );
              Navigator.pop(context);
            }
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            print('Page finished loading: $url');
            if (url.startsWith('data:text/html')) {
              if (!mounted) return;
              setState(() {
                _pageFinishedLoading = true;
              });
              _controller.runJavaScript('initializeAndPay("${widget.snapToken}");');
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('''Page resource error: url: ${error.url} errorCode: ${error.errorCode} description: ${error.description} errorType: ${error.errorType} isForMainFrame: ${error.isForMainFrame}''');
            if (error.isForMainFrame == true || 
               (error.description.contains("net::ERR_BLOCKED_BY_ORB") && error.url != null && error.url!.contains("snap.js"))
            ) {
              if (mounted && !_paymentProcessed) {
                _paymentProcessed = true;
                // Jika gagal memuat webview, anggap gagal dan hapus data pending jika ada path
                _deletePendingBookingFromFirebase(); 
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Gagal memuat halaman pembayaran: ${error.description}"), backgroundColor: Colors.red),
                );
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            print('WebView is navigating to: ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
        Uri.dataFromString(
          _getHtmlContent(),
          mimeType: 'text/html',
          encoding: Encoding.getByName('utf-8'),
        ),
      );
  }

  String _getHtmlContent() {
    // Konten HTML Anda
    return """
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
            .loader { border: 8px solid #f3f3f3; border-top: 8px solid #3498db; border-radius: 50%; width: 60px; height: 60px; animation: spin 2s linear infinite; position: absolute; top: 50%; left: 50%; margin-top: -30px; margin-left: -30px; }
            @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        </style>
    </head>
    <body> 
        <div id="payment-loading" class="loader"></div>
        <div id="payment-container"></div>
        <script type="text/javascript">
            function initializeAndPay(token) {
                try {
                    var loader = document.getElementById('payment-loading');
                    if (loader) { loader.style.display = 'none'; }

                    if (typeof snap !== 'undefined') {
                        snap.embed(token, {
                            embedId: 'payment-container',
                            onSuccess: function(result){
                                console.log('Success:', JSON.stringify(result));
                                if (window.MidtransMessageHandler) {
                                    window.MidtransMessageHandler.postMessage(JSON.stringify({status: "success", data: result}));
                                }
                            },
                            onPending: function(result){
                                console.log('Pending:', JSON.stringify(result));
                                if (window.MidtransMessageHandler) {
                                    window.MidtransMessageHandler.postMessage(JSON.stringify({status: "pending", data: result}));
                                }
                            },
                            onError: function(result){
                                console.log('Error:', JSON.stringify(result));
                                if (window.MidtransMessageHandler) {
                                    window.MidtransMessageHandler.postMessage(JSON.stringify({status: "error", data: result}));
                                }
                            },
                            onClose: function(){
                                console.log('customer closed the Snap UI');
                                if (window.MidtransMessageHandler) {
                                    window.MidtransMessageHandler.postMessage(JSON.stringify({status: "closed"}));
                                }
                            }
                        });
                    } else {
                        console.error('Snap.js is not loaded yet or snap is undefined.');
                        if (window.MidtransMessageHandler) {
                           window.MidtransMessageHandler.postMessage(JSON.stringify({status: "js_error", data: {message: "Snap.js not loaded"}}));
                        }
                    }
                } catch (e) {
                    console.error('Error in initializeAndPay:', e);
                    if (window.MidtransMessageHandler) {
                        window.MidtransMessageHandler.postMessage(JSON.stringify({status: "js_exception", data: {message: e.toString()}}));
                    }
                }
            }
        </script>
    </body>
    </html>
    """;
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, 
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        
        if (!_paymentProcessed && mounted) {
          _paymentProcessed = true; 
          _deletePendingBookingFromFirebase(); // Hapus jika dibatalkan via back press
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Pembayaran dibatalkan."), backgroundColor: Colors.grey),
          );
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
                _deletePendingBookingFromFirebase(); // Hapus jika dibatalkan via tombol AppBar
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Pembayaran dibatalkan via tombol kembali."), backgroundColor: Colors.grey),
                );
              }
              if (Navigator.canPop(context)) {
                 Navigator.pop(context);
              }
            },
          ),
        ),
        body: Stack(
          children: [
            if (_pageFinishedLoading)
              WebViewWidget(controller: _controller)
            else 
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Memuat halaman pembayaran..."),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}