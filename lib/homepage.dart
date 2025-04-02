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