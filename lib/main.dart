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

  /// The iOS Safari Date Patch JS — injected into ALL frames (main + iframes)
  static const String _iosDateFixJS = '''
    (function() {
      if (window.__iosDateFixApplied) return;
      window.__iosDateFixApplied = true;

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
          initialUrlRequest: URLRequest(url: WebUri(targetUrl)),
          initialUserScripts: UnmodifiableListView<UserScript>([
            UserScript(
              source: _iosDateFixJS,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
              forMainFrameOnly: false, // Ensures it hits the iframe
            ),
          ]),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            allowsInlineMediaPlayback: true,
            disallowOverScroll: false,
            allowUniversalAccessFromFileURLs: true,
            allowFileAccessFromFileURLs: true,
            isFraudulentWebsiteWarningEnabled: false,
            useOnLoadResource: false,
            useShouldOverrideUrlLoading: true,
            transparentBackground: false,
          ),
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            return NavigationActionPolicy.ALLOW;
          },
          onConsoleMessage: (controller, consoleMessage) {
            debugPrint(
              'WEBVIEW_JS_LOG: [${consoleMessage.messageLevel}] ${consoleMessage.message}',
            );
          },
          onLoadStop: (controller, url) {
            debugPrint('PAGE_FINISHED: $url');
          },
          onReceivedError: (controller, request, error) {
            debugPrint('WEBVIEW_ERROR: ${error.description} (${request.url})');
          },
        ),
      ),
    );
  }
}
