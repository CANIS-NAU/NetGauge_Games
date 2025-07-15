import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:internet_measurement_games_app/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_manager.dart';
import 'location_logger.dart';
import 'vibration_controller.dart';
import 'name_entry_page.dart';
import 'dart:async';
import 'ndt7_service.dart';

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

  // constructor for tiles that launch games into the webview
  Widget _buildTile(String title, IconData icon, String gameFile, BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          // log the game start with the session manager
          SessionManager.startGame(title);
          // begin location logging
          LocationLogger.start();
          // navigate to the WebViewPage when tapped
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebViewPage(title: title, gameFile: gameFile),
            ),
          ).then((_) {
            // log the game end with the session manager
            SessionManager.endGame(); // also will stop logging location
            // Stop the vibration service, in case the game started it
            VibrationController.stop();
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

  // constructor for tiles that launch games in dedicated flutter pages
  Widget _buildPageTile(String title, IconData icon, Widget page, BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          // navigate to page
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          ).then((_){
            // log the game end with the session manager
            SessionManager.endGame(); // also will stop logging location
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Landing Page'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              // TODO: This could be more dynamic. Iterate over assets and build a 
              // tile for each 
              _buildTile('Scavenger Hunt', Icons.home, 'ScavengerHunt.html', context),
              _buildTile('Soul Seeker', Icons.settings, 'SoulSeeker.html', context),
              _buildTile('Zombie Apocalypse', Icons.info, 'ZombieApocalypse.html', context),
              _buildTile('Dragon Slayer', Icons.home, 'DragonSlayer.html', context),
              _buildPageTile('Speed Test', Icons.speed, const NameEntry(), context)
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
  final String gameFile; // holds the html file to be loaded into webview

  const WebViewPage({Key? key, required this.title, required this.gameFile}) : super(key: key);

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
    const PlatformWebViewControllerCreationParams params =
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

    // Load gameFile associated with tile that created the webview
    controller.loadFlutterAsset('assets/${widget.gameFile}');
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
            debugPrint("[HANDLENATIVEMESSAGE] Firestore write failed- SessionID is NULL");
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
            debugPrint("[HANDLENATIVEMESSAGE] Firestore write failed- SessionID is NULL");
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

        case 'setPOIs':
          // extract POI list from payload
          final rawPOIs = data['payload'];

          final poiList = (rawPOIs as List).map((entry) {
            return {
              'latitude': (entry['latitude'] as num).toDouble(),
              'longitude': (entry['longitude'] as num).toDouble(),
            };
          }).toList();

          debugPrint("[HANDLENATIVEMESSAGE] POI list set: $poiList");
          
          // store the POIs in the Sessionmanager
          SessionManager.setPOIs(poiList);
          break;

        case 'POICheck':
          // checks if the player is in collection vicinity of a POI
          // collects the PoI if so.
          checkPOI();
          break;

        case "clearPOIList":
          // clears the current list of POIs in the SessionManager
          for(int i = 0; i < SessionManager.poiList.length; i++)
          {
            SessionManager.poiList.removeAt(i);
          }

          break;

        case 'hintRequest':
          // provides player with a hint directing them towards the nearest POI
          provideHint();
          break;

        case 'startVibrationService':
          // starts the vibration service for the current game
          VibrationController.start();
          break;

        case 'stopVibrationService':
          // stops the vibration system
          VibrationController.stop();
          break;

        default:
          debugPrint("[HANDLENATIVEMESSAGE] Unknown command: $command");
      }
    } catch (e) {
      debugPrint("[HANDLENATIVEMESSAGE] Error decoding message: $e");
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
    // use the NDT7 service to get the metrics
    final results = await ndt7_service.runFullTest();
    final json = jsonEncode(results);

    // return the json file
    controller.runJavaScript("window.onMetrics(${jsonEncode(json)})"); // need to encode the json twice for JS reception
  }

  // when the player makes an action that results in a measurement, this function writes the context to firestore
  Future<void> writeCheckData(Map<String, dynamic> payload, String? sessionId) async
  {
    // debug
    debugPrint('[WRITECHECKDATA] Writing to Firestore with session: $sessionId');
    debugPrint('[WRITECHECKDATA] Payload: $payload');

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

  // Check if the player can collect a POI and return true/false to JS
  Future<void> checkPOI() async{
    // grab players current position
    final loc = await determineLocationData();

    // grab the current poi list in the session manager
    final poiList = SessionManager.poiList;
    // create a variable to store the index of the poi to be removed if it exists
    int indexToRemove = -1;

    // iterate over PoIs and determine if one is within collection vicinity
    for(int i = 0; i < poiList.length; i++){
      final poi = poiList[i];
      final distance = Geolocator.distanceBetween(
        loc.position.latitude,
        loc.position.longitude,
        poi['latitude']!,
        poi['longitude']!
      );

      // a poi can be collected within 7 meters of the player
      if(distance <= 7){
        indexToRemove = i;
        break;
      }
    }

    // use a boolean to track if a poi has been found or not
    final bool collected = indexToRemove != -1;
    
    // if a poi was collected, remove it from the list
    if(collected)
    {
      SessionManager.poiList.removeAt(indexToRemove);
      debugPrint("[CHECKPOI] POI collected at index $indexToRemove");
      debugPrint("[CHECKPOI] Updated POI list: ${SessionManager.poiList}");
    }else{
      debugPrint("[CHECKPOI] No POI within range.");
    }

    // send results back to JS
    final resultJson = jsonEncode({'collected': collected});
    controller.runJavaScript("window.onPOICheck($resultJson)");
  }

  // Callback function to perform hint generation
  Future<void> provideHint() async{
    // get user current position and heading
    final loc = await determineLocationData();
    final userPos = loc.position;
    final heading = loc.heading;

    // verify that a heading was received
    if (heading == null) {
      controller.runJavaScript("window.onHint(JSON.stringify({hint: 'No compass available'}));");
      return;
    }

    // get the nearest POI
    final nearestPOI = SessionManager.getNearestPOI(userPos);
    // verify POI exists
    if (nearestPOI == null) {
      controller.runJavaScript("window.onHint(JSON.stringify({hint: 'No POIs available'}));");
      return;
    }

    // calculate bearing from user to POI
    final bearingToPOI = Geolocator.bearingBetween(
      userPos.latitude,
      userPos.longitude,
      nearestPOI['latitude']!,
      nearestPOI['longitude']!
    );

    // Normalize and compare to user heading
    double relativeBearing = (bearingToPOI - heading) % 360;
    if(relativeBearing < 0) relativeBearing += 360;

    // produce a hint based on the relative bearing
    String hint;
    if(relativeBearing >= 330 || relativeBearing < 30){
      hint = "in front of you";
    } else if (relativeBearing >= 30 && relativeBearing < 150) {
      hint = "to your right";
    } else if (relativeBearing >= 150 && relativeBearing < 210){
      hint = "behind you";
    } else {
      hint = "to your left";
    }

    // send the hint back to the game
    final resultJson = jsonEncode({'hint': hint});
    controller.runJavaScript("window.onHint($resultJson);");
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
