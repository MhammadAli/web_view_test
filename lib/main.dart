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
  bool _hasRedirected = false;

  // Step 1: Load the wrapper to establish session cookies via mcok
  final String wrapperUrl =
      'https://pp.medicacloudcare.com/newPatientPortal/IframeWrapper.html?mcok=HBHZBZDZJEHAEZCJAKFZJHIJFTBCDFEH&pgUrl=/lisorderentry/orderentry.html?PatId=1000&EpsKey=215975&UserID=616&lang=0&hospitalid=1&IsNurse=0&ModeView=1&ROnly=0&dbcode=3&MP=-1&mfa_src=cpoe&eoc_problemid=0&cpoe_sessionid=1905';

  // Step 2: The actual inner page to load directly (no iframe)
  final String directUrl =
      'https://pp.medicacloudcare.com/lisorderentry/orderentry.html?PatId=1000&EpsKey=215975&UserID=616&lang=0&hospitalid=1&IsNurse=0&ModeView=1&ROnly=0&dbcode=3&MP=-1&mfa_src=cpoe&eoc_problemid=0&cpoe_sessionid=1905';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
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
          onPageFinished: (String url) {
            debugPrint('PAGE_FINISHED: $url');

            // Strategy B: Two-step iframe bypass
            // Step 1: Wrapper loaded -> session cookies set -> redirect to inner URL
            if (url.contains('IframeWrapper') && !_hasRedirected) {
              _hasRedirected = true;
              debugPrint('SESSION_ESTABLISHED: Redirecting to inner URL directly...');

              // Small delay to ensure cookies are fully set
              Future.delayed(const Duration(milliseconds: 500), () {
                _controller.loadRequest(Uri.parse(directUrl));
              });
              return;
            }

            // Step 2: Inner page loaded directly (no iframe!) -> apply minimal touch fix
            if (url.contains('orderentry.html')) {
              debugPrint('DIRECT_PAGE_LOADED: Applying iOS touch fix...');
              _injectTouchFix();
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WEBVIEW_NATIVE_ERROR: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(wrapperUrl));
  }

  void _injectTouchFix() {
    _controller.runJavaScript('''
      (function() {
        var selectors = 'div, li, tr, td, th, span, label, p, ul, ol, a, img';
        var allEls = document.querySelectorAll(selectors);
        var patched = 0;
        for (var i = 0; i < allEls.length; i++) {
          if (!allEls[i].getAttribute('onclick')) {
            allEls[i].setAttribute('onclick', '');
            patched++;
          }
        }

        document.addEventListener('touchstart', function(){}, {passive: true});

        var style = document.createElement('style');
        style.innerHTML = '* { touch-action: manipulation !important; }';
        if (document.head) document.head.appendChild(style);

        if (document.body) {
          var observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(m) {
              m.addedNodes.forEach(function(node) {
                if (node.nodeType === 1) {
                  if (!node.getAttribute('onclick')) node.setAttribute('onclick', '');
                  var ch = node.querySelectorAll(selectors);
                  for (var j = 0; j < ch.length; j++) {
                    if (!ch[j].getAttribute('onclick')) ch[j].setAttribute('onclick', '');
                  }
                }
              });
            });
          });
          observer.observe(document.body, {childList: true, subtree: true});
        }

        document.addEventListener('touchstart', function(e) {
          console.log('[iOS-Touch] ' + e.target.tagName +
            (e.target.id ? '#' + e.target.id : '') +
            (e.target.className ? '.' + String(e.target.className).split(' ')[0] : ''));
        }, true);

        console.log('[iOS-Fix] Direct page: patched ' + patched + ' elements (NO IFRAME!)');
      })();
    ''');
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
