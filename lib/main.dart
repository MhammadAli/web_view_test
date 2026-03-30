import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InAppWebView Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const InAppWebViewScreen(),
    );
  }
}

class InAppWebViewScreen extends StatefulWidget {
  const InAppWebViewScreen({super.key});

  @override
  State<InAppWebViewScreen> createState() => _InAppWebViewScreenState();
}

class _InAppWebViewScreenState extends State<InAppWebViewScreen> {
  final String targetUrl =
      'https://pp.medicacloudcare.com/newPatientPortal/IframeWrapper.html?mcok=HBHZBZDZJEHAEZCJAKFZJHIJFTBCDFEH&pgUrl=/lisorderentry/orderentry.html?PatId=1000&EpsKey=215975&UserID=616&lang=0&hospitalid=1&IsNurse=0&ModeView=1&ROnly=0&dbcode=3&MP=-1&mfa_src=cpoe&eoc_problemid=0&cpoe_sessionid=1905';

  late InAppWebViewController webViewController;

  // This script injects the touch fix into ALL frames (main and iframes)
  // the split second they begin loading.
  final String touchFixScript = """
    var style = document.createElement('style');
    style.innerHTML = '* { cursor: pointer !important; touch-action: manipulation !important; }';
    document.head.appendChild(style);
  """;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('InAppWebView iOS Test')),
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(targetUrl)),
          initialSettings: InAppWebViewSettings(
            isInspectable:
                true, // Allows us to use Safari Web Inspector if needed
            javaScriptEnabled: true,
            supportMultipleWindows: true,
            allowsInlineMediaPlayback: true,
            iframeAllowFullscreen: true,
            // These settings tell iOS to play nice with legacy web portals
            alwaysBounceVertical: false,
            allowsBackForwardNavigationGestures: false,
          ),
          initialUserScripts: UnmodifiableListView<UserScript>([
            UserScript(
              source: touchFixScript,
              // Inject immediately before the DOM builds
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              // Apply this to the main frame AND all nested iframes
              forMainFrameOnly: false,
            ),
          ]),
          onWebViewCreated: (controller) {
            webViewController = controller;
          },
          onConsoleMessage: (controller, consoleMessage) {
            debugPrint('INAPPWEBVIEW_LOG: ${consoleMessage.message}');
          },
        ),
      ),
    );
  }
}
