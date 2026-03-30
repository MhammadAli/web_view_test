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
          // 2. Inject the definitive iOS touch fix
          onPageFinished: (String url) {
            _controller.runJavaScript('''
              (function() {
                // === iOS Touch Fix ===
                // On iOS WKWebView, non-interactive elements (div, li, tr, td, span)
                // do NOT fire "click" events unless they have an onclick attribute.
                // cursor:pointer does NOTHING on iOS (no cursor on touch devices).
                // This is the definitive fix for AngularJS ng-click / jQuery delegated events.

                function applyIOSTouchFix(doc, label) {
                  try {
                    if (!doc || !doc.body) {
                      console.log("[iOS-Fix] Skipping " + label + " - no body yet");
                      return false;
                    }

                    // 1. Add empty onclick="" to all non-interactive elements
                    var selectors = 'div, li, tr, td, th, span, label, p, section, article, ul, ol, dl, dt, dd, a, img';
                    var allEls = doc.querySelectorAll(selectors);
                    var patched = 0;
                    for (var i = 0; i < allEls.length; i++) {
                      if (!allEls[i].getAttribute('onclick')) {
                        allEls[i].setAttribute('onclick', '');
                        patched++;
                      }
                    }

                    // 2. Force WKWebView touch responder chain registration
                    doc.addEventListener('touchstart', function(){}, {passive: true});

                    // 3. Touch-action CSS to prevent 300ms delay
                    var style = doc.createElement('style');
                    style.innerHTML = '* { touch-action: manipulation !important; -webkit-tap-highlight-color: transparent; }';
                    if (doc.head) doc.head.appendChild(style);

                    // 4. MutationObserver for dynamically rendered content (AngularJS)
                    if (doc.body) {
                      var observer = new MutationObserver(function(mutations) {
                        mutations.forEach(function(m) {
                          m.addedNodes.forEach(function(node) {
                            if (node.nodeType === 1) {
                              if (!node.getAttribute('onclick')) {
                                node.setAttribute('onclick', '');
                              }
                              var children = node.querySelectorAll(selectors);
                              for (var j = 0; j < children.length; j++) {
                                if (!children[j].getAttribute('onclick')) {
                                  children[j].setAttribute('onclick', '');
                                }
                              }
                            }
                          });
                        });
                      });
                      observer.observe(doc.body, {childList: true, subtree: true});
                    }

                    // 5. Synthetic click dispatcher (FastClick-style)
                    // iOS WKWebView registers touchstart but fails to synthesize click.
                    // This bridges the gap for AngularJS ng-click and jQuery .on('click').
                    var touchStartTarget = null;
                    var touchStartX = 0;
                    var touchStartY = 0;
                    var TOUCH_THRESHOLD = 10; // px tolerance for finger movement

                    doc.addEventListener('touchstart', function(e) {
                      if (e.touches.length === 1) {
                        touchStartTarget = e.target;
                        touchStartX = e.touches[0].clientX;
                        touchStartY = e.touches[0].clientY;
                      }
                      console.log('[iOS-Touch] ' + label + ': ' + e.target.tagName +
                        (e.target.id ? '#' + e.target.id : '') +
                        (e.target.className ? '.' + e.target.className.split(' ')[0] : ''));
                    }, true);

                    doc.addEventListener('touchend', function(e) {
                      if (!touchStartTarget) return;

                      var touch = e.changedTouches[0];
                      var dx = Math.abs(touch.clientX - touchStartX);
                      var dy = Math.abs(touch.clientY - touchStartY);

                      // Only synthesize click if finger didn't move (it's a tap, not a scroll)
                      if (dx < TOUCH_THRESHOLD && dy < TOUCH_THRESHOLD) {
                        var target = touchStartTarget;

                        // Walk up to find the nearest element with ng-click or onclick handler
                        var clickTarget = target;
                        var maxWalk = 5;
                        while (clickTarget && maxWalk > 0) {
                          if (clickTarget.getAttribute && (
                              clickTarget.getAttribute('ng-click') ||
                              clickTarget.getAttribute('data-ng-click') ||
                              clickTarget.getAttribute('onclick') !== '' ||
                              clickTarget.tagName === 'A' ||
                              clickTarget.tagName === 'BUTTON' ||
                              clickTarget.tagName === 'INPUT')) {
                            break;
                          }
                          clickTarget = clickTarget.parentElement;
                          maxWalk--;
                        }
                        if (!clickTarget) clickTarget = target;

                        // Synthesize and dispatch a real click event
                        var clickEvent = new MouseEvent('click', {
                          bubbles: true,
                          cancelable: true,
                          view: doc.defaultView,
                          clientX: touch.clientX,
                          clientY: touch.clientY
                        });
                        clickTarget.dispatchEvent(clickEvent);
                        console.log('[iOS-SyntheticClick] ' + label + ': dispatched click on ' +
                          clickTarget.tagName +
                          (clickTarget.id ? '#' + clickTarget.id : '') +
                          (clickTarget.getAttribute && clickTarget.getAttribute('ng-click') ?
                            ' [ng-click=' + clickTarget.getAttribute('ng-click') + ']' : ''));
                      }
                      touchStartTarget = null;
                    }, true);

                    console.log("[iOS-Fix] Patched " + patched + " elements in [" + label + "]");
                    return true;
                  } catch(e) {
                    console.log("[iOS-Fix] Error in " + label + ": " + e.message);
                    return false;
                  }
                }

                // Fix main document immediately
                applyIOSTouchFix(document, "main");

                // Retry iframe penetration with exponential backoff
                var attempts = 0;
                var maxAttempts = 10;

                function tryFixIframes() {
                  var iframes = document.getElementsByTagName('iframe');
                  var fixedCount = 0;

                  for (var i = 0; i < iframes.length; i++) {
                    try {
                      var fd = iframes[i].contentDocument || iframes[i].contentWindow.document;
                      if (fd && fd.body && fd.body.children.length > 0) {
                        applyIOSTouchFix(fd, "iframe-" + i);
                        fixedCount++;

                        // Also check for nested iframes inside this iframe
                        var nestedIframes = fd.getElementsByTagName('iframe');
                        for (var j = 0; j < nestedIframes.length; j++) {
                          try {
                            var nfd = nestedIframes[j].contentDocument || nestedIframes[j].contentWindow.document;
                            if (nfd && nfd.body) {
                              applyIOSTouchFix(nfd, "nested-iframe-" + i + "-" + j);
                            }
                          } catch(ne) {
                            console.log("[iOS-Fix] Nested iframe cross-origin: " + ne.message);
                          }
                        }
                      }
                    } catch(e) {
                      console.log("[iOS-Fix] Iframe " + i + " cross-origin blocked: " + e.message);
                    }
                  }

                  attempts++;
                  console.log("[iOS-Fix] Iframe attempt " + attempts + "/" + maxAttempts + " - fixed: " + fixedCount + " of " + iframes.length);

                  // Retry with increasing delay if iframes exist but weren't ready
                  if (iframes.length > 0 && fixedCount < iframes.length && attempts < maxAttempts) {
                    var delay = Math.min(500 * Math.pow(1.5, attempts), 5000);
                    console.log("[iOS-Fix] Retrying in " + Math.round(delay) + "ms...");
                    setTimeout(tryFixIframes, delay);
                  }
                }

                // Start iframe fix after a short initial delay
                setTimeout(tryFixIframes, 500);
              })();
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
