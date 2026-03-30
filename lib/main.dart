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

      // --- iOS Safari Date Parsing Patch ---
      // Safari strictly rejects 'YYYY-MM-DD HH:mm:ss' and the mangled format from Angular's FormatISODate.
      var _origDate = window.Date;
      window.Date = function() {
          var args = Array.prototype.slice.call(arguments);
          if (args.length === 1 && typeof args[0] === 'string') {
              var str = args[0];
              if (str.match(/^\\d{4}-\\d{2}-\\d{2}\\s+\\d{2}:\\d{2}/)) {
                  args[0] = str.replace(/-/g, '/'); // Standard SQL to Safari compatible
              } else if (str.match(/^\\d{4}\\s+\\d{2}:\\d{2}:\\d{2}-[a-zA-Z]+-\\d{1,2}\$/)) {
                  // Fix for FormatISODate mangling: "2026 16:56:00-March-30" -> "March 30, 2026 16:56:00"
                  var parts = str.split('-');
                  var fp = parts[0].split(' ');
                  args[0] = parts[1] + ' ' + parts[2] + ', ' + fp[0] + ' ' + fp[1];
              }
          }
          var instance;
          if (this instanceof window.Date) {
              if (args.length === 0) instance = new _origDate();
              else if (args.length === 1) instance = new _origDate(args[0]);
              else if (args.length === 2) instance = new _origDate(args[0], args[1]);
              else if (args.length === 3) instance = new _origDate(args[0], args[1], args[2]);
              else if (args.length === 4) instance = new _origDate(args[0], args[1], args[2], args[3]);
              else if (args.length === 5) instance = new _origDate(args[0], args[1], args[2], args[3], args[4]);
              else if (args.length === 6) instance = new _origDate(args[0], args[1], args[2], args[3], args[4], args[5]);
              else instance = new _origDate(args[0], args[1], args[2], args[3], args[4], args[5], args[6]);
              Object.setPrototypeOf(instance, window.Date.prototype);
              return instance;
          } else {
              return _origDate.apply(this, args);
          }
      };
      window.Date.prototype = _origDate.prototype;
      window.Date.now = _origDate.now;
      window.Date.parse = function(str) {
          if (typeof str === 'string') {
              if (str.match(/^\\d{4}-\\d{2}-\\d{2}\\s+\\d{2}:\\d{2}/)) {
                  str = str.replace(/-/g, '/');
              } else if (str.match(/^\\d{4}\\s+\\d{2}:\\d{2}:\\d{2}-[a-zA-Z]+-\\d{1,2}\$/)) {
                  var parts = str.split('-');
                  var fp = parts[0].split(' ');
                  str = parts[1] + ' ' + parts[2] + ', ' + fp[0] + ' ' + fp[1];
              }
          }
          return _origDate.parse(str);
      };
      window.Date.UTC = _origDate.UTC;

      // Constantly ensure Angular scope has the safe parser
      setInterval(function() {
          try {
              var appElem = document.getElementById('MyAngularApp');
              if (appElem && window.angular) {
                  var scope = window.angular.element(appElem).scope();
                  if (scope && scope.FormatISODate && !scope._iosDateFixed) {
                      var _origFormat = scope.FormatISODate;
                      scope.FormatISODate = function(date) {
                          try {
                              if (typeof date === 'string' && date.indexOf('-') > 0) {
                                  var p = date.split(' ');
                                  var d = p[0].split('-');
                                  if (d.length === 3) {
                                      var ms = {"January":1,"February":2,"March":3,"April":4,"May":5,"June":6,"July":7,"August":8,"September":9,"October":10,"November":11,"December":12};
                                      var m = ms[d[1]] || parseInt(d[1]);
                                      if (d[0].length <= 2 && m > 0) {
                                          return d[2] + "-" + (m < 10 ? '0'+m : m) + "-" + (d[0].length < 2 ? '0'+d[0] : d[0]);
                                      }
                                  }
                              }
                          } catch(e) {}
                          var res = _origFormat.apply(this, arguments);
                          if (res && res.indexOf('NaN') !== -1) {
                               var now = new Date();
                               var mn = now.getMonth() + 1;
                               var dy = now.getDate();
                               return now.getFullYear() + '-' + (mn < 10 ? '0'+mn : mn) + '-' + (dy < 10 ? '0'+dy : dy);
                          }
                          return res;
                      };
                      scope._iosDateFixed = true;
                      console.log("[iOS-DatePatch] Patched AngularJS FormatISODate gracefully");
                  }
              }
          } catch(e) {}
      }, 1000);

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
