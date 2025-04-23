import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

// landing page of app
class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  // helper function to build a tile that navigates to a WebView page when tapped
  Widget _buildTile(String title, IconData icon, BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          // navigate to the WebViewPage when tapped
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebViewPage(title: title),
            ),
          );
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.all(16.0),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18.0),
            leading: Icon(icon, size: 40.0, color: Theme.of(context).primaryColor),
            title: Text(title, style: const TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Landing Page'),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildTile('Scavenger Hunt', Icons.home, context),
          _buildTile('Soul Seeker', Icons.settings, context),
          _buildTile('Zombie Apocalypse', Icons.info, context),
          _buildTile('Speed Tester', Icons.contact_mail, context),
        ],
      ),
    );
  }
}

/// A stateful widget that displays a WebView
class WebViewPage extends StatefulWidget {
  final String title;

  const WebViewPage({Key? key, required this.title}) : super(key: key);

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    // create parameters for the platform-specific WebView controller
    final PlatformWebViewControllerCreationParams params =
    PlatformWebViewControllerCreationParams();

    // create the WebView controller from the platform-specific parameters
    controller = WebViewController.fromPlatformCreationParams(params)
      // enable JavaScript execution
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // set a navigation delegate to handle events like page load
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
            // inject JavaScript into the WebView to define the AndroidBridge interface
            // this code sets up functions that the HTML can call to communicate with Flutter
            controller.runJavaScript('''
              window.AndroidBridge = {
                setPlayerName: function(name) {
                  NativeBridge.postMessage(JSON.stringify({command: 'setPlayerName', value: name}));
                },
                getLocationJSON: function() {
                  return JSON.stringify({latitude: 35.185652, longitude: -111.657812});
                },
                generateMetrics: function() {
                  return new Promise(function(resolve, reject) {
                    NativeBridge.postMessage(JSON.stringify({command: 'generateMetrics'}));
                    window.__resolveGenerateMetrics = resolve;
                  });
                }
              };
            
              if (typeof window.onLocationJSON !== 'function') {
                window.onLocationJSON = function(json) {
                  console.log("Received location JSON from Flutter: " + json);
                };
              }
            ''');
          },
        ),
      )
    // register a JavaScript channel named 'NativeBridge'
    // to receives messages from the web content
      ..addJavaScriptChannel(
        'NativeBridge',
        onMessageReceived: (JavaScriptMessage message) {
          handleNativeMessage(message.message);
        },
      );

    // TODO: load your HTML file from the assets folder
    controller.loadFlutterAsset('assets/ScavengerHunt.html');
  }

  /// parses the incoming message from the JavaScript channel.
  /// it decodes the JSON string and calls corresponding methods based on the 'command' field
  void handleNativeMessage(String message) {
    try {
      final Map<String, dynamic> data = json.decode(message);
      final String command = data['command'];
      switch (command) {
        case 'setPlayerName':
          final String playerName = data['value'];
          setPlayerName(playerName);
          break;
        case 'getLocationJSON':
          sendLocationJSON();
          break;
        case 'generateMetrics':
          sendMsakMetrics();
          break;
        default:
          print("Unknown command: $command");
      }
    } catch (e) {
      print("Error decoding message: $e");
    }
  }

  // TODO: store
  void setPlayerName(String playerName) {
    print("Player name set to: $playerName");
  }

  /// sends location data to the web content by calling a JavaScript function
  void sendLocationJSON() async {
    // integrate the location package, replace this with actual location data
    final Map<String, dynamic> locationData = {
      'latitude': 35.185652,
      'longitude': -111.657812,
    };

    // convert the location data to JSON
    final String locationJson = json.encode(locationData);
    print("Sending location JSON: $locationJson");
    // call the JavaScript function window.onLocationJSON with the JSON data
    controller.runJavaScript("window.onLocationJSON('$locationJson')");
  }

  void sendMsakMetrics() async {
    try {
      final result = await const MethodChannel('msak_channel').invokeMethod<String>('runMsak');
      print("Raw MSAK output: $result");

      final metrics = parseMsakOutput(result ?? "");
      final jsonString = json.encode(metrics);

      print("Sending parsed metrics: $jsonString");
      controller.runJavaScript("window.__resolveGenerateMetrics($jsonString)");
    } catch (e) {
      print("Error getting MSAK metrics: $e");
    }
  }

  Map<String, dynamic> parseMsakOutput(String output) {
    final downloadMatch = RegExp(r"rate\s+(\d+\.\d+)\s+Mbps").firstMatch(output);
    final rttMatch = RegExp(r"rtt\s+(\d+\.\d+)ms").firstMatch(output);

    return {
      "uploadSpeed": 0.0, // minimal-download doesn’t measure upload
      "downloadSpeed": downloadMatch != null ? double.parse(downloadMatch.group(1)!) : 0.0,
      "latency": rttMatch != null ? double.parse(rttMatch.group(1)!) : 0.0,
      "jitter": 0.0,
      "packetLoss": 0.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

// testing class for run msak

class MsakTestPage extends StatelessWidget {
  static const platform = MethodChannel('msak_channel');

  Future<void> runMsak() async {
    try {
      final result = await platform.invokeMethod('runMsak');
      debugPrint("MSAK result:\n$result");
    } catch (e) {
      debugPrint("Error getting MSAK metrics: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("MSAK Test")),
      body: Center(
        child: ElevatedButton(
          onPressed: runMsak,
          child: Text("Run MSAK Test"),
        ),
      ),
    );
  }
}
