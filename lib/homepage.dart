import 'dart:convert';
import 'package:internet_measurement_games_app/dashboard.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'mapping.dart';
import 'package:flutter/material.dart';
import 'package:internet_measurement_games_app/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_manager.dart';
import 'location_logger.dart';
import 'vibration_controller.dart';
import 'name_entry_page.dart';
import 'likert_form.dart';
import 'dart:async';
import 'ndt7_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'profile.dart';
import 'poi_generator.dart';
import 'speed_test_page.dart';

//vars for mapping
final List<TimedWeightedLatLng> allHeatmapData = heatmapData;

// class to manage session data that needs to be accessible across functions/files

// updated landing page, now a stateful widget
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _sessionId = '';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _sessionId = user.uid;
      SessionManager.setSessionId(user.uid);
      //SessionManager.setPlayerName(user.email ?? user.uid);
    }
  }

 /* Future<void> _promptForSessionId(BuildContext context) async {
    String tempSessionId = '';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Session ID'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => tempSessionId = value,
          decoration: const InputDecoration(hintText: 'e.g. session_001, E1'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (tempSessionId.trim().isNotEmpty) {
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
  }*/

  // constructor for tiles that launch games into the webview
  Widget _buildTile(
      String title, IconData icon, String gameFile, BuildContext context) {
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
              builder: (context) =>
                  WebViewPage(title: title, gameFile: gameFile),
            ),
          ).then((_) async {
            // log the game end with the session manager
            SessionManager.endGame(); // also will stop logging location
            // Stop the vibration service, in case the game started it
            VibrationController.stop();

            // Navigate to Likert form after game ends
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LikertForm(gameTitle: title),
              ),
            );
          });
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.all(16.0),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18.0),
            leading:
                Icon(icon, size: 40.0, color: Theme.of(context).primaryColor),
            title: Text(title, style: const TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }

  // constructor for tiles that launch games in dedicated flutter pages
  Widget _buildPageTile(
      String title, IconData icon, Widget page, BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          // log the game start with the session manager -> added 7/10
          SessionManager.startGame(title);
          // begin location logging -> added 7/10
          LocationLogger.start();
          // navigate to page
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          ).then((_) async {
            // log the game end with the session manager
            SessionManager.endGame(); // also will stop logging location
            // Map will only open if the page specifically requests it
            // For now, just end the session without automatically opening map
          });
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.all(16.0),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18.0),
            leading:
                Icon(icon, size: 40.0, color: Theme.of(context).primaryColor),
            title: Text(title, style: const TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }

  // constructor for the map tile that uses session data
  Widget _buildMapTile(String title, IconData icon, BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () async {
          // Get the actual location data from Firestore
          final sessionLocationData = await getSessionLocationData();

          // Use session data if available, otherwise fall back to static data
          final mapData = sessionLocationData.isNotEmpty
              ? sessionLocationData
              : heatmapData;

          // Navigate to map page with the appropriate data
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MapPage(
                data: mapData,
                gradients: gradients,
                index: 0,
                rebuildStream: Stream<void>.empty(),
              ),
            ),
          );
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.all(16.0),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18.0),
            leading:
                Icon(icon, size: 40.0, color: Theme.of(context).primaryColor),
            title: Text(title, style: const TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }

  Widget _buildCombinedMapTile(
      String title, IconData icon, BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () async {
          final allLocationData = await getAllSessionLocationData();
          final mapData =
              allLocationData.isNotEmpty ? allLocationData : heatmapData;
          debugPrint('[HomePage] Calling functionality to build MapPage.');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MapPage(
                data: mapData,
                gradients: gradients,
                index: 0,
                rebuildStream: Stream<void>.empty(),
              ),
            ),
          );
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.all(16.0),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18.0),
            leading:
                Icon(icon, size: 40.0, color: Theme.of(context).primaryColor),
            title: Text(title, style: const TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }

  Future<List<TimedWeightedLatLng>> getAllSessionLocationData() async {
    final firestore = FirebaseFirestore.instance;
    List<TimedWeightedLatLng> allData = [];

    try {
      debugPrint('[MAP] Starting getAllSessionLocationData...');
      debugPrint('[MAP] Current session ID: ${SessionManager.sessionId}');
      //debugPrint('[MAP] Current player name: ${SessionManager.playerName}');
      debugPrint('[MAP] Current game: ${SessionManager.currentGame}');
      debugPrint('[MAP] Querying collection: Movement Data');

      final sessionsSnapshot =
          await firestore.collection('Movement Data').get();
      debugPrint(
          '[MAP] Query completed. Got ${sessionsSnapshot.docs.length} session documents');

      if (sessionsSnapshot.docs.isEmpty) {
        debugPrint(
            '[MAP] No session documents found. Collection might be empty or named differently.');
        return [];
      }

      for (final sessionDoc in sessionsSnapshot.docs) {
        debugPrint('[MAP] Processing session ID: ${sessionDoc.id}');
        debugPrint('[MAP] Session document data: ${sessionDoc.data()}');

        // Fetch location data for each session
        final locationSnapshot = await sessionDoc.reference
            .collection('LocationData')
            .orderBy('datetime', descending: false)
            .get();

        debugPrint(
            '[MAP] Session ${sessionDoc.id} has ${locationSnapshot.docs.length} location points');

        if (locationSnapshot.docs.isEmpty) {
          debugPrint(
              '[MAP] No LocationData subcollection found for session ${sessionDoc.id}');
          continue;
        }

        for (final locDoc in locationSnapshot.docs) {
          try {
            final data = locDoc.data();
            debugPrint('[MAP] Location document ${locDoc.id} data: $data');
            debugPrint('[MAP] Location data keys: ${data.keys}');

            final latitude = data['latitude'] as double;
            final longitude = data['longitude'] as double;
            final datetime = DateTime.parse(data['datetime'] as String);

            allData.add(TimedWeightedLatLng(
              LatLng(latitude, longitude),
              1.0,
              datetime,
            ));
          } catch (e) {
            debugPrint(
                '[MAP] Error processing location document ${locDoc.id}: $e');
            debugPrint('[MAP] Document data: ${locDoc.data()}');
          }
        }
      }

      debugPrint(
          '[MAP] Combined total of ${allData.length} location points across all sessions');
      return allData;
    } catch (e) {
      debugPrint('[MAP] Error fetching all sessions: $e');
      debugPrint('[MAP] Error type: ${e.runtimeType}');
      return [];
    }
  }

  // Function to retrieve location data from Firestore for the current session
  Future<List<TimedWeightedLatLng>> getSessionLocationData() async {
    if (_sessionId.isEmpty) {
      debugPrint(
          '[HOMEPAGE] No session ID available for location data retrieval');
      return [];
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('Movement Data')
          .doc(_sessionId)
          .collection('LocationData')
          .orderBy('datetime', descending: false)
          .get();

      List<TimedWeightedLatLng> locationData = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final latitude = data['latitude'] as double;
        final longitude = data['longitude'] as double;
        final datetime = DateTime.parse(data['datetime'] as String);

        locationData.add(TimedWeightedLatLng(
          LatLng(latitude, longitude),
          1.0, // intensity
          datetime,
        ));
      }

      debugPrint('[HOMEPAGE] Retrieved ${locationData.length} location points');
      return locationData;
    } catch (e) {
      debugPrint('[HOMEPAGE] Error retrieving location data: $e');
      return [];
    }
  }

  // Test function to check what's in Firestore
  Future<void> debugFirestoreContents() async {
    final firestore = FirebaseFirestore.instance;

    try {
      // Check if Firestore is accessible
      debugPrint('[FIRESTORE_DEBUG] Firestore connection test starting...');
      debugPrint(
          '[FIRESTORE_DEBUG] Current session ID: ${SessionManager.sessionId}');
      debugPrint('[FIRESTORE_DEBUG] Homepage session ID: $_sessionId');

      // List all top-level collections
      debugPrint('[FIRESTORE_DEBUG] Checking all top-level collections...');

      // Try different possible collection names
      final possibleCollections = [
        'Movement Data',
        'MovementData',
        'movement_data',
        'sessions',
        'Sessions'
      ];

      for (final collectionName in possibleCollections) {
        try {
          final query = await firestore.collection(collectionName).get();
          debugPrint(
              '[FIRESTORE_DEBUG] Collection "$collectionName" has ${query.docs.length} documents');

          if (query.docs.isNotEmpty) {
            // List all session IDs if any exist
            for (final doc in query.docs) {
              debugPrint('[FIRESTORE_DEBUG] Found session: ${doc.id}');
              debugPrint('[FIRESTORE_DEBUG] Session data: ${doc.data()}');

              // Check subcollections
              final locationData =
                  await doc.reference.collection('LocationData').get();
              final checkData =
                  await doc.reference.collection('CheckData').get();
              final likertData =
                  await doc.reference.collection('LikertData').get();

              debugPrint('[FIRESTORE_DEBUG] Session ${doc.id} has:');
              debugPrint(
                  '[FIRESTORE_DEBUG] - LocationData: ${locationData.docs.length} documents');
              debugPrint(
                  '[FIRESTORE_DEBUG] - CheckData: ${checkData.docs.length} documents');
              debugPrint(
                  '[FIRESTORE_DEBUG] - LikertData: ${likertData.docs.length} documents');

              // Show first few location data points if they exist
              if (locationData.docs.isNotEmpty) {
                debugPrint('[FIRESTORE_DEBUG] First 3 LocationData documents:');
                for (int i = 0; i < locationData.docs.length && i < 3; i++) {
                  final locDoc = locationData.docs[i];
                  debugPrint(
                      '[FIRESTORE_DEBUG] LocationData ${locDoc.id}: ${locDoc.data()}');
                }
              }
            }
          }
        } catch (e) {
          debugPrint(
              '[FIRESTORE_DEBUG] Error accessing collection "$collectionName": $e');
        }
      }

      // Also check if session "0" specifically exists -> just for testing purposes
      //dont use session "0" as actual session ID
      try {
        final sessionZeroDoc =
            await firestore.collection('Movement Data').doc('0').get();
        if (sessionZeroDoc.exists) {
          debugPrint(
              '[FIRESTORE_DEBUG] Session "0" exists with data: ${sessionZeroDoc.data()}');
          final locationData =
              await sessionZeroDoc.reference.collection('LocationData').get();
          debugPrint(
              '[FIRESTORE_DEBUG] Session "0" has ${locationData.docs.length} LocationData documents');
        } else {
          debugPrint('[FIRESTORE_DEBUG] Session "0" does not exist');
        }
      } catch (e) {
        debugPrint('[FIRESTORE_DEBUG] Error checking session "0": $e');
      }
    } catch (e) {
      debugPrint('[FIRESTORE_DEBUG] Error accessing Firestore: $e');
    }
  }

  // Test function to check location logging
  Future<void> testLocationLogging() async {
    debugPrint('[LOCATION_TEST] Starting location logging test...');
    debugPrint(
        '[LOCATION_TEST] Current session ID: ${SessionManager.sessionId}');
    /*debugPrint(
        '[LOCATION_TEST] Current player name: ${SessionManager.playerName}');*/
    debugPrint('[LOCATION_TEST] Current game: ${SessionManager.currentGame}');
    debugPrint('[LOCATION_TEST] Homepage session ID: $_sessionId');

    // Set test values if they're null
    if (SessionManager.sessionId == null || SessionManager.sessionId!.isEmpty) {
      debugPrint(
          '[LOCATION_TEST] Session ID is null/empty, using test session ID');
      SessionManager.setSessionId(
          _sessionId.isNotEmpty ? _sessionId : 'test_session');
    }

   /* if (SessionManager.playerName == null) {
      debugPrint(
          '[LOCATION_TEST] Player name is null, setting test player name');
      SessionManager.setPlayerName('test_player');
    }*/

    if (SessionManager.currentGame == null) {
      debugPrint('[LOCATION_TEST] Current game is null, setting test game');
      SessionManager.startGame('Test Game');
    }

    // Try to write a test location to Firestore
    try {
      final firestore = FirebaseFirestore.instance;
      final sessionId = SessionManager.sessionId ?? 'test_session';
      debugPrint('[LOCATION_TEST] Writing to session: $sessionId');

      // First, ensure the session document exists
      await firestore.collection('Movement Data').doc(sessionId).set({
        'sessionId': sessionId,
        //'playerName': SessionManager.playerName,
        'created': DateTime.now().toIso8601String(),
        'test': true,
      }, SetOptions(merge: true));

      // Then add the location data to the subcollection
      final docRef = await firestore
          .collection('Movement Data')
          .doc(sessionId)
          .collection('LocationData')
          .add({
        'latitude': 37.7749,
        'longitude': -122.4194,
        'datetime': DateTime.now().toIso8601String(),
        'game': SessionManager.currentGame,
        //'player': SessionManager.playerName,
        'test': true,
      });
      debugPrint(
          '[LOCATION_TEST] Test location data written successfully to document: ${docRef.id}');

      // Immediately try to read it back
      final readBack = await firestore
          .collection('Movement Data')
          .doc(sessionId)
          .collection('LocationData')
          .doc(docRef.id)
          .get();

      if (readBack.exists) {
        debugPrint('[LOCATION_TEST] Read back successful: ${readBack.data()}');
      } else {
        debugPrint(
            '[LOCATION_TEST] ERROR: Document was written but cannot be read back!');
      }
    } catch (e) {
      debugPrint('[LOCATION_TEST] Error writing test location data: $e');
    }

    // Reset game state
    SessionManager.endGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'NetGauge Games',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: CircleAvatar(
                backgroundColor: Colors.black,
                radius: 20,
                child: IconButton(
                  icon: Icon(Icons.person),
                  color: Colors.white,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfilePage())
                    );
                  },
                ),
              ),
            ),
          ],
          backgroundColor: Theme.of(context).primaryColor,
          elevation: 0,
        ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              // TODO: This could be more dynamic. Iterate over assets and build a
              // tile for each
              _buildTile(
                  'Scavenger Hunt', Icons.home, 'ScavengerHunt.html', context),
              _buildTile(
                  'Soul Seeker', Icons.settings, 'SoulSeeker.html', context),
              _buildTile('Zombie Apocalypse', Icons.info,
                  'ZombieApocalypse.html', context),
              _buildTile(
                  'Dragon Slayer', Icons.home, 'DragonSlayer.html', context),
              _buildPageTile(
                  'Speed Test', Icons.speed, const SpeedTestPage(), context),
              _buildMapTile('Session Data Map', Icons.map, context),
              _buildCombinedMapTile('Full Data Map', Icons.public, context),
              _buildPageTile('Data Dashboard', Icons.leaderboard,
                  const DataDashboard(), context),
            ],
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

  const WebViewPage({Key? key, required this.title, required this.gameFile})
      : super(key: key);

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

          if (sessionId == null) {
            debugPrint(
                "[HANDLENATIVEMESSAGE] Firestore write failed- SessionID is NULL");
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
          if (sessionId == null) {
            debugPrint(
                "[HANDLENATIVEMESSAGE] Firestore write failed- SessionID is NULL");
            return;
          }

          // convert payload to a map for firestore writing
          final jsonPayload = data['payload'];
          final mapPayload = Map<String, dynamic>.from(jsonPayload);

          // write teh likert data to firestore
          writeLikertData(mapPayload, sessionId);
          break;

        /*case 'publishPlayerName':
          // set the player name in the session manager so LocationService can access
          final nickname = data['playerName'];
          SessionManager.setPlayerName(nickname);
          break;*/

        case 'setPOIs':
          // extract POI list from payload
          final rawPOIs = data['payload'];

          /*final poiList = (rawPOIs as List).map((entry) {
            return {
              'latitude': (entry['latitude'] as num).toDouble(),
              'longitude': (entry['longitude'] as num).toDouble(),
            };
          }).toList();*/

          PoiListGenerator poi_generator = new PoiListGenerator();
          final poiList = poi_generator.generatePOIList(5);

          debugPrint("[HANDLENATIVEMESSAGE] POI list set: $poiList");

          // store the POIs in the Sessionmanager
          SessionManager.setPOIs(poiList as List<Map<String, double>>);
          break;

        case 'POICheck':
          // checks if the player is in collection vicinity of a POI
          // collects the PoI if so.
          checkPOI();
          break;

        case "clearPOIList":
          // clears the current list of POIs in the SessionManager
          for (int i = 0; i < SessionManager.poiList.length; i++) {
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
  void sendLocationJSON(context) async {
    // get location
    final loc = await determineLocationData();
    // build return JSON
    final json = jsonEncode({
      'latitude': loc.position.latitude,
      'longitude': loc.position.longitude,
      'context': context, // echo back context
    });
    // return the location json to JS
    controller.runJavaScript(
        "window.onLocationJSON(${jsonEncode(json)})"); // need to encode the json twice for JS reception
  }

  // uses measureInternet() function to measure internet and send data to JS
  void grabMetrics() async{
    // use the NDT7 service to get the metrics
    final results = await NDT7Service().runFullTest();;
    final json = jsonEncode(results);

    // TODO: When MSAK is implemented get internet metrics
    //final json = await mesureInternet();

    // PLACEHOLDER VALUES TO RETURN //
    /*final json = jsonEncode({
      'uploadSpeed': -1,
      'downloadSpeed': -1,
      'jitter': -1,
      'packetLoss': -1,
      'latency': -1,
    });*/

    // return the placeholder json
    controller.runJavaScript(
        "window.onMetrics(${jsonEncode(json)})"); // need to encode the json twice for JS reception
  }

  // when the player makes an action that results in a measurement, this function writes the context to firestore
  Future<void> writeCheckData(
      Map<String, dynamic> payload, String? sessionId) async {
    // debug
    debugPrint(
        '[WRITECHECKDATA] Writing to Firestore with session: $sessionId');
    debugPrint('[WRITECHECKDATA] Payload: $payload');

    // get location
    final loc = await determineLocationData();

    // write additional data to payload before publishing to firestore
    payload['latitude'] = loc.position.latitude;
    payload['longitude'] = loc.position.longitude;
    payload['sessionId'] = sessionId;

    // add the payload to firestore
    final firestore = FirebaseFirestore.instance;
    await firestore
        .collection('Movement Data')
        .doc(sessionId)
        .collection('CheckData')
        .add(payload);
  }

  // write the post-game likert responses to Firestore
  Future<void> writeLikertData(
      Map<String, dynamic> payload, String? sessionId) async {
    // add session Id to payload
    payload['sessionId'] = sessionId;

    // add payload to firestore
    final firestore = FirebaseFirestore.instance;
    await firestore
        .collection('Movement Data')
        .doc(sessionId)
        .collection('LikertData')
        .add(payload);
  }

  // Check if the player can collect a POI and return true/false to JS
  Future<void> checkPOI() async {
    // grab players current position
    final loc = await determineLocationData();

    // grab the current poi list in the session manager
    final poiList = SessionManager.poiList;
    // create a variable to store the index of the poi to be removed if it exists
    int indexToRemove = -1;

    // iterate over PoIs and determine if one is within collection vicinity
    for (int i = 0; i < poiList.length; i++) {
      final poi = poiList[i];
      final distance = Geolocator.distanceBetween(loc.position.latitude,
          loc.position.longitude, poi['latitude']!, poi['longitude']!);

      // a poi can be collected within 7 meters of the player
      if (distance <= 7) {
        indexToRemove = i;
        break;
      }
    }

    // use a boolean to track if a poi has been found or not
    final bool collected = indexToRemove != -1;

    // if a poi was collected, remove it from the list
    if (collected) {
      SessionManager.poiList.removeAt(indexToRemove);
      debugPrint("[CHECKPOI] POI collected at index $indexToRemove");
      debugPrint("[CHECKPOI] Updated POI list: ${SessionManager.poiList}");
    } else {
      debugPrint("[CHECKPOI] No POI within range.");
    }

    // send results back to JS
    final resultJson = jsonEncode({'collected': collected});
    controller.runJavaScript("window.onPOICheck($resultJson)");
  }

  // Callback function to perform hint generation
  Future<void> provideHint() async {
    // get user current position and heading
    final loc = await determineLocationData();
    final userPos = loc.position;
    final heading = loc.heading;

    // verify that a heading was received
    if (heading == null) {
      controller.runJavaScript(
          "window.onHint(JSON.stringify({hint: 'No compass available'}));");
      return;
    }

    // get the nearest POI
    final nearestPOI = SessionManager.getNearestPOI(userPos);
    // verify POI exists
    if (nearestPOI == null) {
      controller.runJavaScript(
          "window.onHint(JSON.stringify({hint: 'No POIs available'}));");
      return;
    }

    // calculate bearing from user to POI
    final bearingToPOI = Geolocator.bearingBetween(userPos.latitude,
        userPos.longitude, nearestPOI['latitude']!, nearestPOI['longitude']!);

    // Normalize and compare to user heading
    double relativeBearing = (bearingToPOI - heading) % 360;
    if (relativeBearing < 0) relativeBearing += 360;

    // produce a hint based on the relative bearing
    String hint;
    if (relativeBearing >= 330 || relativeBearing < 30) {
      hint = "in front of you";
    } else if (relativeBearing >= 30 && relativeBearing < 150) {
      hint = "to your right";
    } else if (relativeBearing >= 150 && relativeBearing < 210) {
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
          if (isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
