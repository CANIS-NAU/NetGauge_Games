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
            // inject a JavaScript shim into the WebView
            // this shim creates a global AndroidBridge object that the web content can use
            controller.runJavaScript('''
              window.AndroidBridge = {
                // set player's name
                setPlayerName: function(name) {
                  // send a message to Flutter using the NativeBridge channel
                  NativeBridge.postMessage(JSON.stringify({command: 'setPlayerName', value: name}));
                },
                // request location data
                getLocationJSON: function() {
                  // send a message to Flutter using the NativeBridge channel
                  NativeBridge.postMessage(JSON.stringify({command: 'getLocationJSON'}));
                }
              };
            ''');
          },
        ),
      )
    // register a JavaScript channel with the name 'NativeBridge'
    // this channel receives messages from the web content
      ..addJavaScriptChannel(
        'NativeBridge',
        onMessageReceived: (JavaScriptMessage message) {
          // process messages from your HTML via the shim
          // for example, handle "setPlayerName" or "getLocationJSON" commands.
          print("Received from WebView: ${message.message}");
        },
      );

    // TODO: load your HTML file from the assets folder
    controller.loadFlutterAsset('assets/ScavengerHunt.html');
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