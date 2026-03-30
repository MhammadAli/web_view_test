import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebView Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;

  final String targetUrl =
      'https://pp.medicacloudcare.com/newPatientPortal/IframeWrapper.html?mcok=HBHZBZDZJEHAEZCJAKFZJHIJFTBCDFEH&pgUrl=/lisorderentry/orderentry.html?PatId=1000&EpsKey=215975&UserID=616&lang=0&hospitalid=1&IsNurse=0&ModeView=1&ROnly=0&dbcode=3&MP=-1&mfa_src=cpoe&eoc_problemid=0&cpoe_sessionid=1905';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // 1. Listen for hidden JavaScript errors
      ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
        debugPrint(
          'WEBVIEW_JS_LOG: [${message.level.name}] ${message.message}',
        );
      })
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
          // 2. Inject CSS to force iOS to recognize taps on jQuery/Angular lists
          onPageFinished: (String url) {
            _controller.runJavaScript('''
              // 1. Fix the main wrapper
              var style = document.createElement('style');
              style.innerHTML = '* { cursor: pointer !important; touch-action: manipulation !important; }';
              document.head.appendChild(style);
              console.log("Flutter applied touch fix to main wrapper.");

              // 2. Penetrate the iframe to fix the actual buttons
              setTimeout(function() {
                var iframes = document.getElementsByTagName('iframe');
                for (var i = 0; i < iframes.length; i++) {
                  try {
                    var frameDoc = iframes[i].contentDocument || iframes[i].contentWindow.document;
                    var frameStyle = frameDoc.createElement('style');
                    frameStyle.innerHTML = '* { cursor: pointer !important; touch-action: manipulation !important; }';
                    frameDoc.head.appendChild(frameStyle);
                    console.log("Flutter successfully penetrated iframe and applied touch fix.");
                  } catch(e) {
                    console.log("Could not penetrate iframe (possible cross-origin block): " + e.message);
                  }
                }
              }, 1500); // Wait 1.5 seconds to ensure iframe content is fully loaded
            ''');
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WEBVIEW_NATIVE_ERROR: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(targetUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('iOS WebView Test')),
      body: SafeArea(
        child: WebViewWidget(
          controller: _controller,
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
        ),
      ),
    );
  }
}
