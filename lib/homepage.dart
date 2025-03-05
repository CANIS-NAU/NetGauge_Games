import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  // helper function to build a tile that navigates to a WebView page when tapped
  Widget _buildTile(String title, IconData icon, BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
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

    final PlatformWebViewControllerCreationParams params =
    PlatformWebViewControllerCreationParams();

    controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted);

    // load the html from the assets folder
    controller.loadFlutterAsset('assets/FlutterTest.html');

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (String url) {
          setState(() {
            isLoading = false;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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