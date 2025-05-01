import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:internet_measurement_games_app/location_service.dart';
import 'package:internet_measurement_games_app/location_test_page.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_manager.dart';
import 'location_logger.dart';

// class to manage session data that needs to be accessible across functions/files

// updated landing page, now a stateful widget
class HomePage extends StatefulWidget{
  const HomePage({Key? key}) : super(key: key);
  
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
{
  String _sessionId = '';

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      _promptForSessionId(context);
      SessionManager.setSessionId(_sessionId);
    });
  }

  Future<void> _promptForSessionId(BuildContext context) async{
    String tempSessionId = '';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Session ID'),
        content: TextField(
          autofocus: true,
          onChanged: (value)=> tempSessionId = value,
          decoration: const InputDecoration(hintText: 'e.g. session_001, E1'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if(tempSessionId.trim().isNotEmpty){
                setState(() => _sessionId = tempSessionId.trim());
                SessionManager.setSessionId(tempSessionId.trim());
                Navigator.of(context).pop();
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(String title, IconData icon, BuildContext context, Widget page) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          // log the game start with the session manager
          SessionManager.startGame(title);
          // navigate to the WebViewPage when tapped
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => page,
            ),
          ).then((_) {
            // log the game end with the session manager
            SessionManager.endGame();
          });
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
    // start location logger
    LocationLogger.start();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Landing Page'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildTile('Scavenger Hunt', Icons.home, context, const WebViewPage(title: 'Scavenger Hunt')),
              _buildTile('Soul Seeker', Icons.settings, context, const WebViewPage(title: 'Soul Seeker')),
              _buildTile('Zombie Apocalypse', Icons.info, context, const WebViewPage(title: 'Zombie Apocalypse')),
              _buildTile('Speed Tester', Icons.contact_mail, context, const WebViewPage(title: 'Speed Tester')),
              _buildTile('Test Location Service', Icons.my_location, context, const LocationTestPage())
            ],
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Session: $_sessionId'),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _promptForSessionId(context),
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
          ),
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
            // previously injected a 'fake' JS window here, but we are updating that method
            // to instead use a more dynamic event-based messaging system.
            // JS now uses FlutterBridge.postMessage(...) directly instead of original
            // Android Bridge calls
          },
        ),
      )
    // register a JavaScript channel named 'NativeBridge'
    // to receives messages from the web content
      ..addJavaScriptChannel(
        'FlutterBridge',
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

        // JS is requesting location
        case 'getLocation':
          // store request context (what to do with the returned location)
          final context = data['context'];
          
          // call async function to send the location data
          sendLocationJSON(context);
          break;

        // JS is requesting metrics
        case 'requestMetricsAndWriteData':
          // get the session ID
          final sessionId = SessionManager.sessionId;

          if(sessionId == null)
          {
            print("Firestore write failed- SessionID is NULL");
            return;
          }

          // convert payload to a map for firestore writing
          final jsonPayload = data['payload'];
          final mapPayload = Map<String, dynamic>.from(jsonPayload);
          
          // TODO: Grab the internet metrics using MSAK toolkit, send to JS
          grabMetrics();

          // write the payload data to firestore
          writeCheckData(mapPayload, sessionId);
          break;

        case 'publishLikertResponses':
          // get the sessionId
          final sessionId = SessionManager.sessionId;

          // ensure that session id is non null
          if(sessionId == null)
          {
            print("Firestore write failed- SessionID is NULL");
            return;
          }

          // convert payload to a map for firestore writing
          final jsonPayload = data['payload'];
          final mapPayload = Map<String, dynamic>.from(jsonPayload);

          // write teh likert data to firestore
          writeLikertData(mapPayload, sessionId);
          break;

        case 'publishPlayerName':
          // set the player name in the session manager so LocationService can access
          final nickname = data['playerName'];
          SessionManager.setPlayerName(nickname);
          break;

        default:
          print("Unknown command: $command");
      }
    } catch (e) {
      print("Error decoding message: $e");
    }
  }

  // handler for getting the location data from the location service
  void sendLocationJSON(context) async{
    // get location
    final loc = await determineLocationData();
    // build return JSON
    final json = jsonEncode({
      'latitude': loc.position.latitude,
      'longitude': loc.position.longitude,
      'context': context, // echo back context
    });
    // return the location json to JS
    controller.runJavaScript("window.onLocationJSON(${jsonEncode(json)})"); // need to encode the json twice for JS reception
  }

  // uses measureInternet() function to measure internet and send data to JS
  void grabMetrics() async{

    // TODO: When MSAK is implemented get internet metrics
    //final json = await mesureInternet();

    // PLACEHOLDER VALUES TO RETURN //
    final json = jsonEncode({
      'uploadSpeed': -1,
      'downloadSpeed': -1,
      'jitter': -1,
      'packetLoss': -1,
      'latency': -1,
    });

    // return the placeholder json
    controller.runJavaScript("window.onMetrics(${jsonEncode(json)})"); // need to encode the json twice for JS reception
  }

  // when the player makes an action that results in a measurement, this function writes the context to firestore
  Future<void> writeCheckData(Map<String, dynamic> payload, String? sessionId) async
  {
    // debug
    print('Writing to Firestore with session: $sessionId');
    print('Payload: $payload');

    // get location
    final loc = await determineLocationData();

    // write additional data to payload before publishing to firestore
    payload['latitude'] = loc.position.latitude;
    payload['longitude'] = loc.position.longitude;
    payload['sessionId'] = sessionId;

    // add the payload to firestore
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('Movement Data').doc(sessionId).collection('CheckData').add(payload);
  }

  // write the post-game likert responses to Firestore
  Future<void> writeLikertData(Map<String, dynamic> payload, String? sessionId) async{
    // add session Id to payload
    payload['sessionId'] = sessionId;

    // add payload to firestore
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('Movement Data').doc(sessionId).collection('LikertData').add(payload);
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