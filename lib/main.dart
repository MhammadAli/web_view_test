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

      // 1. Add onclick handlers to force WKWebView to recognize elements as interactive
      var selectors = 'div, li, tr, td, th, span, label, p, section, article, ul, ol, dl, dt, dd, a, img';
      var allEls = document.querySelectorAll(selectors);
      for (var i = 0; i < allEls.length; i++) {
        if (!allEls[i].getAttribute('onclick')) {
          allEls[i].setAttribute('onclick', '');
        }
      }

      // 2. CSS touch-action to prevent 300ms delay and highlight mapping
      var style = document.createElement('style');
      style.innerHTML = '* { touch-action: manipulation !important; -webkit-tap-highlight-color: transparent; }';
      if (document.head) document.head.appendChild(style);

      // 3. MutationObserver for dynamically rendered AngularJS content
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

      // 4. FastClick-style synthetic click dispatcher bridging the WKWebView gap
      var touchStartTarget = null;
      var touchStartX = 0;
      var touchStartY = 0;
      var TOUCH_THRESHOLD = 10;
      var NATIVE_INTERACTIVE = ['INPUT', 'BUTTON', 'SELECT', 'TEXTAREA', 'A'];

      document.addEventListener('touchstart', function(e) {
        if (e.touches.length === 1) {
          touchStartTarget = e.target;
          touchStartX = e.touches[0].clientX;
          touchStartY = e.touches[0].clientY;
        }
        var loc = window === window.top ? 'main' : 'iframe';
        console.log('[iOS-Touch] ' + loc + ': ' + e.target.tagName + (e.target.id ? '#' + e.target.id : ''));
      }, { passive: true });

      document.addEventListener('touchend', function(e) {
        if (!touchStartTarget) return;
        var target = touchStartTarget;
        touchStartTarget = null;

        var touch = e.changedTouches[0];
        if (!touch) return;
        
        var dx = Math.abs(touch.clientX - touchStartX);
        var dy = Math.abs(touch.clientY - touchStartY);

        // If movement is within threshold, it's a tap
        if (dx < TOUCH_THRESHOLD && dy < TOUCH_THRESHOLD) {
          
          if (NATIVE_INTERACTIVE.indexOf(target.tagName) >= 0) {
            return; // Let native components handle themselves natively
          }

          var loc = window === window.top ? 'main' : 'iframe';

          // Prevent the browser's delayed native click 
          if (e.cancelable) {
            e.preventDefault();
          }

          // Dispatch native click on the exact target. 
          // Event will bubble up to the ng-click listener naturally with exact proper scoping.
          var clickEvent = new MouseEvent('click', {
            bubbles: true,
            cancelable: true,
            view: window,
            clientX: touch.clientX,
            clientY: touch.clientY
          });
          target.dispatchEvent(clickEvent);
          console.log('[iOS-SyntheticClick] ' + loc + ': dispatched on ' + target.tagName + (target.id ? '#' + target.id : ''));

          // Force AngularJS digest cycle manually to ensure the UI immediately realizes the click
          if (typeof window.angular !== 'undefined') {
            try {
              var scope = window.angular.element(target).scope();
              if (scope) {
                var rootScope = scope.\$root;
                if (rootScope && !rootScope.\$\$phase) {
                  rootScope.\$apply();
                  console.log('[iOS-DigestForce] ' + loc + ': forced digest cycle');
                }
              }
            } catch(err) {
              console.log('[iOS-DigestError] ' + loc + ': ' + err.message);
            }
          }
        }
      }, false); 
      // Note: passive is false by default for touchend, which allows e.preventDefault()
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
              'WEBVIEW_JS_LOG: [${consoleMessage.messageLevel}] ${consoleMessage.message}',
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
