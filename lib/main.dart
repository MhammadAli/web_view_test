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
  final String targetUrl =
      'https://pp.medicacloudcare.com/newPatientPortal/IframeWrapper.html?mcok=HBHZBZDZJEHAEZCJAKFZJHIJFTBCDFEH&pgUrl=/lisorderentry/orderentry.html?PatId=1000&EpsKey=215975&UserID=616&lang=0&hospitalid=1&IsNurse=0&ModeView=1&ROnly=0&dbcode=3&MP=-1&mfa_src=cpoe&eoc_problemid=0&cpoe_sessionid=1905';

  /// The iOS touch fix JS — injected into ALL frames (main + iframes) at document end.
  /// Uses onclick="" attribute injection + MutationObserver for dynamic AngularJS content.
  static const String _iosTouchFixJS = '''
    (function() {
      if (window.__iosTouchFixApplied) return;
      window.__iosTouchFixApplied = true;

      var selectors = 'div, li, tr, td, th, span, label, p, section, article, ul, ol, dl, dt, dd, a, img';
      var allEls = document.querySelectorAll(selectors);
      var patched = 0;
      for (var i = 0; i < allEls.length; i++) {
        if (!allEls[i].getAttribute('onclick')) {
          allEls[i].setAttribute('onclick', '');
          patched++;
        }
      }

      // Force WKWebView touch responder chain registration
      document.addEventListener('touchstart', function(){}, {passive: true});

      // Touch-action CSS to prevent 300ms delay
      var style = document.createElement('style');
      style.innerHTML = '* { touch-action: manipulation !important; -webkit-tap-highlight-color: transparent; }';
      if (document.head) document.head.appendChild(style);

      // MutationObserver for dynamically rendered AngularJS content
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

      // Touch diagnostic logger
      document.addEventListener('touchstart', function(e) {
        var loc = window === window.top ? 'main' : 'iframe';
        console.log('[iOS-Touch] ' + loc + ': ' + e.target.tagName +
          (e.target.id ? '#' + e.target.id : '') +
          (e.target.className ? '.' + String(e.target.className).split(' ')[0] : ''));
      }, true);

      var loc = window === window.top ? 'main' : 'iframe';
      console.log('[iOS-Fix] Patched ' + patched + ' elements in [' + loc + '] via InAppWebView UserScript');
    })();
  ''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('iOS WebView Test')),
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(targetUrl),
          ),
          // Inject the touch fix JS into ALL frames (main + iframes) automatically
          initialUserScripts: UnmodifiableListView<UserScript>([
            UserScript(
              source: _iosTouchFixJS,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
              // KEY: false = inject into ALL frames including iframes
              forMainFrameOnly: false,
            ),
          ]),
          initialSettings: InAppWebViewSettings(
            // Enable JavaScript
            javaScriptEnabled: true,
            // Allow inline media playback
            allowsInlineMediaPlayback: true,
            // Disable content blockers that might interfere
            disallowOverScroll: false,
            // Allow universal access from file URLs (helps with same-origin)
            allowUniversalAccessFromFileURLs: true,
            // Allow file access from file URLs
            allowFileAccessFromFileURLs: true,
            // Suppress the 300ms click delay
            isFraudulentWebsiteWarningEnabled: false,
            // Enable viewport meta tag handling
            useOnLoadResource: false,
            // Prefer using WKWebView's rendering
            useShouldOverrideUrlLoading: true,
            // Transparent background
            transparentBackground: false,
          ),
          // Allow all navigation (same as before)
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            return NavigationActionPolicy.ALLOW;
          },
          // Console message logging
          onConsoleMessage: (controller, consoleMessage) {
            debugPrint(
              'WEBVIEW_JS_LOG: [${consoleMessage.messageLevel.name}] ${consoleMessage.message}',
            );
          },
          // Page finished loading
          onLoadStop: (controller, url) {
            debugPrint('PAGE_FINISHED: $url');
          },
          // Web resource errors
          onReceivedError: (controller, request, error) {
            debugPrint(
              'WEBVIEW_ERROR: ${error.description} (${request.url})',
            );
          },
        ),
      ),
    );
  }
}
