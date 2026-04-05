import 'dart:convert';
import 'mapping.dart';
import 'package:flutter/material.dart';
import 'package:internet_measurement_games_app/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_manager.dart';
import 'vibration_controller.dart';
import 'dart:async';
import 'ndt7_service.dart';
import 'poi_generator.dart';
import 'package:provider/provider.dart';
import 'user_data_manager.dart';
import 'package:uuid/uuid.dart';

// data type for tracking location
class LocationPoint {
  final double longitude;
  final double latitude;

  LocationPoint({required this.longitude, required this.latitude});
}

// data type for measurements
class InternetMeasurement {
  final double uploadSpeed;
  final double downloadSpeed;
  final double jitters;
  final double latency;

  InternetMeasurement({required this.uploadSpeed, required this.downloadSpeed,
  required this.jitters, required this.latency});
}

//vars for mapping
final List<TimedWeightedLatLng> allHeatmapData = heatmapData;

// unique session ID for game
var gameSessionID = Uuid().v4();

/// A stateful widget that displays a WebView
class WebViewPage extends StatefulWidget {
  // is this the game title?
  final String title;
  //TODO: It may make more sense for this to be the GameData object, then call the html file from it later
  // that would help with easily grabbing the game name
  final String gameFile; // holds the html file to be loaded into webview


  const WebViewPage({Key? key, required this.title, required this.gameFile})
      : super(key: key);

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController controller;
  bool isLoading = true;
  final DateTime startTime = DateTime.now();
  List<LocationPoint> locationPoints = [];
  List<InternetMeasurement> measurements = [];

  Future<void> endGameSession() async {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    bool vpn_status = userData.vpnStatus;
    // calculate total distance traveled
    double distanceTraveled = calculateDistance(locationPoints);
    // update user data on record
    userData.updateDistanceTraveled(distanceTraveled);
    DateTime endTime = DateTime.now();
    debugPrint("[FLUTTER_BRIDGE] In endGameSession case.");

    debugPrint("[FLUTTER_BRIDGE] Verifying measurements were recorded: $measurements");

    // format data to send to firebase for this session
    final checkData = {
      'game': SessionManager.currentGame,
      'start_time': startTime,
      'end_time': endTime,
      'session_id': gameSessionID,
      'vpn_used' : vpn_status,
      'session_distance': distanceTraveled,
      'collected_measurements': measurements.map((p) => {
        'upload_speed': p.uploadSpeed,
        'download_speed': p.downloadSpeed,
        'latency': p.latency,
        'jitters': p.jitters
      }).toList(),
      'location_points': locationPoints.map((p) => {
        'latitude': p.latitude,
        'longitude': p.longitude,
      }).toList(),
    };
    debugPrint("[FLUTTER_BRIDGE] Formatted data for firestore.");

    // send to firebase
    try {
      debugPrint("Attempting to write to Firestore...");
      await FirebaseFirestore.instance
          .collection('measurements')
          .doc(userData.email)
          .collection('sessions')
          .add(checkData);
      debugPrint("Write successful!");
    } catch (e) {
      debugPrint("Firestore Error: $e");
    }
  }

  @override
  void initState() {
    super.initState();

    SessionManager.onWebViewClose = endGameSession;

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

    // set POIs for game session
    debugPrint("[FLUTTER_BRIDGE]: Calling setSessionPOIs...");
    setSessionPOIs();

    // Load gameFile associated with tile that created the webview
    debugPrint("[FLUTTER_BRIDGE]: Loading game file...");
    controller.loadFlutterAsset('assets/${widget.gameFile}');
  }

  @override
  void dispose() {
    // Unplug the bridge to prevent memory leaks or crashes
    SessionManager.onWebViewClose = null;
    super.dispose();
  }

  /// parses the incoming message from the JavaScript channel.
  /// it decodes the JSON string and calls corresponding methods based on the 'command' field
  /// I'm making this async to try and get it to work with NDT7 how it is currently set up..
  /// that may be a mistake. Making a note here in case things aren't working right.
  void handleNativeMessage(String message) async {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    bool vpn_status = userData.vpnStatus;

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

        // specific case for games that need extra POI info
        // i.e. scavenger hunt requires names of POIs
        case 'requestPOIName':
          // gets passed payload with specific POI info is being requested for
          final poiRequested = data['payload'];
          // look to poi list
          PointOfInterest poi = (SessionManager.poiList).firstWhere((pointOfInterest) =>
            pointOfInterest.longitude == poiRequested.longitude && pointOfInterest.latitude == poiRequested.latitude);
          String name = poi.name;
          // call handler function
          sendPOIName(name);
          break;

        case 'requestMetricsAndWriteData':
          // get the session ID
          final sessionId = SessionManager.sessionId;

          if (sessionId == null) {
            debugPrint(
                "[HANDLENATIVEMESSAGE] Firestore write failed- SessionID is NULL");
            return;
          }

          // convert payload to a map for firestore writing
          final jsonPayload = data['payload']; // I think this is supposed to shore data
          final mapPayload = Map<String, dynamic>.from(jsonPayload);

          grabMetrics();

          // write the payload data to firestore
          writeCheckData(mapPayload, sessionId);
          break;

        // TODO: Remove this after it is no longer referenced in existing games
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

          // write the likert data to firestore
          writeLikertData(mapPayload, sessionId);
          break;

        // case for when game is complete
        case 'endGameSession':
          endGameSession();
          break;

        /*case 'publishPlayerName':
          // set the player name in the session manager so LocationService can access
          final nickname = data['playerName'];
          SessionManager.setPlayerName(nickname);
          break;*/

        case 'setPOIs':
          PoiListGenerator poiGenerator = PoiListGenerator();
          final poiList = await poiGenerator.generatePOIList(5);

          debugPrint("[FLUTTER_BRIDGE] POI list set: $poiList");
          // console: [FLUTTER_BRIDGE] POI list set: Instance of 'Future<List<PointOfInterest>>'

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
          SessionManager.poiList.clear();

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

        // collects internet measurements, sends back to game
        case 'getInternetMeasurement':
          debugPrint("[FLUTTER_BRIDGE]: Calling getInternetMeasurement");
          // call NDT7-client
          final service = NDT7Service();
          final download = await service.runDownloadTest((status) {});
          final upload = await service.runUploadTest((status) {});

          InternetMeasurement measurement = InternetMeasurement(
            uploadSpeed:  upload['speedMbps'],
            downloadSpeed: download['speedMbps'],
            latency: download['latency'],
            jitters: 0.0,
          );
          debugPrint("[FLUTTER_BRIDGE]: Adding measurement to measurements list.");
          measurements.add(measurement);


          // get user location
          final loc = await determineLocationData();
          LocationPoint point = LocationPoint(longitude: loc.position.longitude, latitude: loc.position.latitude);
          locationPoints.add(point);

          // upload data to firebase
          final checkData = {
            'game': SessionManager.currentGame,
            'latitude': loc.position.latitude,
            'longitude': loc.position.longitude,
            'download_speed': download['speedMbps'],
            'upload_speed': upload['speedMbps'],
            'latency': download['latency'],
            'timestamp': FieldValue.serverTimestamp(),
            'session_id': gameSessionID,
            'vpn_used' : vpn_status,
          };

          try {
            debugPrint("Attempting to write to Firestore...");
            await FirebaseFirestore.instance
                .collection('measurements')
                .doc(userData.email)
                .collection('collected_measurements')
                .add(checkData);
            debugPrint("Write successful!");
          } catch (e) {
            debugPrint("Firestore Error: $e");
          }
          // TODO: Send data back to game (or should that be it's own case?)
          /*
          Currently, none of the games have logic based on internet measurement results. I am aware
          that that is a long-term goal. I am wondering if it makes sense to have two separate cases:
          one for just recording and one for retrieving?
           */

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
    LocationPoint point = LocationPoint(longitude: loc.position.longitude, latitude: loc.position.latitude);
    locationPoints.add(point);

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

  // take all location points, calculate distance traveled
  double calculateDistance(List<LocationPoint> pointsVisited) {
    double totalDistance = 0.0;
    for(int point = 0; point < pointsVisited.length - 1; point++) {
      double distanceBetween = Geolocator.distanceBetween(
          pointsVisited[point].latitude,
          pointsVisited[point].longitude,
          pointsVisited[point + 1].latitude,
          pointsVisited[point + 1].longitude);
      totalDistance += distanceBetween;
    }
    debugPrint("[FLUTTER_BRIDGE] Session distance traveled: $totalDistance");
    return totalDistance;
  }

  // uses measureInternet() function to measure internet and send data to JS
  void grabMetrics() async{
    // use the NDT7 service to get the metrics
    final results = await NDT7Service().runFullTest();
    final json = jsonEncode(results);


    // return the placeholder json
    controller.runJavaScript(
        "window.onMetrics(${jsonEncode(json)})"); // need to encode the json twice for JS reception
  }

  void setSessionPOIs() async {
    try {
      debugPrint("[FLUTTER_BRIDGE]: Starting POI generation...");
      PoiListGenerator poiGenerator = PoiListGenerator();
      final poiList = await poiGenerator.generatePOIList(5);
      debugPrint("[FLUTTER_BRIDGE]: POI list generated in setSessionPOIs: $poiList");
      SessionManager.setPOIs(poiList);
    } catch (e) {
      debugPrint("[FLUTTER_BRIDGE]: Critical error in setSessionPOIs: $e");
    }

  }

  // helper function, sends name of POI
  void sendPOIName(String poiName) {
    controller.runJavaScript("window.onRequestPOIName($poiName)");
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
    LocationPoint point = LocationPoint(longitude: loc.position.longitude, latitude: loc.position.latitude);
    locationPoints.add(point);

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
    LocationPoint point = LocationPoint(longitude: loc.position.longitude, latitude: loc.position.latitude);
    locationPoints.add(point);

    // grab the current poi list in the session manager
    final poiList = SessionManager.poiList;
    debugPrint("[FLUTTER_BRIDGE]: Printing off POI list in checkPOI...");
    debugPrint("[FLUTTER_BRIDGE]: POI List: $poiList");

    // create a variable to store the index of the poi to be removed if it exists
    int indexToRemove = -1;

    // iterate over PoIs and determine if one is within collection vicinity
    for (int i = 0; i < poiList.length; i++) {
      final poi = poiList[i];
      final distance = Geolocator.distanceBetween(loc.position.latitude,
          loc.position.longitude, poi.latitude!, poi.longitude!);

      // a poi can be collected within 10 meters of the player
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
    LocationPoint point = LocationPoint(longitude: loc.position.longitude, latitude: loc.position.latitude);
    locationPoints.add(point);

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
        userPos.longitude, nearestPOI.latitude!, nearestPOI.longitude!);

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