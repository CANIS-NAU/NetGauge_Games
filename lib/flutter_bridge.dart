import 'dart:convert';
import 'mapping.dart';
import 'package:flutter/material.dart';
import 'package:internet_measurement_games_app/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screen_awake.dart';
import 'game_progress.dart';
import 'page_reader.dart';
import 'session_manager.dart';
import 'vibration_controller.dart';
import 'dart:async';
import 'ndt7_service.dart';
import 'poi_generator.dart';
import 'package:provider/provider.dart';
import 'user_data_manager.dart';
import 'public_measurements.dart';
import 'poi_logic.dart';
import 'package:uuid/uuid.dart';
//import 'package:dart_geohash/dart_geohash.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'session_manager.dart';




/// A stateful widget that displays a WebView
class WebViewPage extends StatefulWidget {
  // is this the game title?
  final String title;
  //TODO: It may make more sense for this to be the GameData object, then call the html file from it later
  // that would help with easily grabbing the game name
  final String gameFile; // holds the html file to be loaded into webview

  // Where the player left off, when they chose to carry on rather than start again (see GameProgress). Null starts
  // the game from the beginning.
  final SavedGame? resumeFrom;

  const WebViewPage({Key? key, required this.title, required this.gameFile, this.resumeFrom})
      : super(key: key);

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController controller;
  bool isLoading = true;
  // Whether there are POIs to find right now. This follows the actual list, so when the list runs out (every POI
  // collected, or a new lookup finds none) the game goes back to the "move a distance" fallback by itself.
  bool get poiListStatus => SessionManager.hasPois;
  // the POI lookup currently in progress, so a check made while it runs can wait for it
  Future<void>? _poiLookup;
  final DateTime startTime = DateTime.now();
  List<LocationPoint> locationPoints = [];
  List<InternetMeasurement> measurements = [];
  final NDT7Service _ndt7Service = NDT7Service();
  // reads the current game page aloud when the player taps the Listen button
  final PageReader _reader = PageReader();
  DateTime? _lastMeasurementTime;
  // who this play belongs to, so a save goes back to the same person; read once, because the saved progress has to
  // be written while the game screen is closing, when the providers are no longer reachable
  late final String _account;
  // kept from initState: providers cannot be looked up while the widget is being disposed
  late final UserDataProvider _userData;

  @override
  void initState() {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    _userData = userData;
    String userEmail = userData.email;
    _account = userEmail;

    super.initState();
    SessionManager.startGame(widget.title, userEmail);
    SessionManager.onWebViewClose = () async => await SessionManager.saveCurrentSession(userData.email, userData);
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
            // so reading stops when the game moves to another page
            controller.runJavaScript(passageChangeHookScript);
            // put the player back where they left off, and keep saving their place from here on
            _installProgressScripts();
            if (!mounted) return;
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
    // leaving the game screen in any way (back button, a crash, signing out) lets the screen sleep again
    ScreenAwake.disable();
    // stop any audio when leaving the game
    _reader.stop();
    _reader.dispose();
    final userData = _userData;
    SessionManager.saveCurrentSession(userData.email, userData).then((_) {
      userData.fetchUserData();
    });
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
          loggingService.logEvent('Game is recording player location.', email: userData.email);
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
          debugPrint("[FLUTTER_BRIDGE]: Requesting POI info for $poi");
          // call handler function
          sendPOIName(name);
          loggingService.logEvent('Game is checking for POI name.', email: userData.email);
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
          // the game has been played to the end, so there is no longer a place to come back to
          await GameProgress.clear(_account, widget.title);
          await SessionManager.saveCurrentSession(userData.email, userData);
          await userData.fetchUserData();
          break;

        // the player reached an ending, so there is nothing to come back to
        case 'gameFinished':
          await GameProgress.clear(_account, widget.title);
          break;

        // the player turned a page, so this is where they would come back to
        case 'saveGameProgress':
          final payload = data['payload'];
          if (payload is! Map) break;
          final state = payload['save'];
          if (state is! String) break;
          final passage = payload['passage'];
          await GameProgress.save(
            _account,
            widget.title,
            state,
            passage: passage is String ? passage : null,
          );
          break;

        // the player was put back where they left off
        case 'gameResumed':
          loggingService.logEvent('Resumed ${widget.title} where the player left off.', email: userData.email);
          break;

        // The save could not be used, so the player is at the start of the game instead. The save is thrown away:
        // it failed once and would fail the same way every time, and keeping it would offer a resume that cannot
        // happen. The player is told, because otherwise the game silently starting over looks like a bug.
        case 'gameResumeFailed':
          final reason = (data['payload'] is Map ? data['payload']['reason'] : null) ?? 'unknown';
          debugPrint('[FLUTTER_BRIDGE] Could not resume ${widget.title}: $reason');
          loggingService.logEvent('Could not resume ${widget.title}: $reason', email: userData.email);
          await GameProgress.clear(_account, widget.title);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Your saved game could not be opened, so this one starts at the beginning.')),
            );
          }
          break;

        // the game's state could not be read; nothing to do but note it, the player plays on
        case 'gameProgressProblem':
          debugPrint('[FLUTTER_BRIDGE] Saving ${widget.title} did not work: ${data['payload']}');
          break;

        /*case 'publishPlayerName':
          // set the player name in the session manager so LocationService can access
          final nickname = data['playerName'];
          SessionManager.setPlayerName(nickname);
          break;*/

        case 'setPOIs':
          await (_poiLookup = _lookUpPois());

          if (poiListStatus) {
            loggingService.logEvent('Game is setting POIs. Nearby POIs found.', email: userData.email);
          } else {
            loggingService.logEvent('Game checked for POIs and did not find any. Simulating POIs with distance traveled.', email: userData.email);
          }
          break;

        // the game moved to another page, so what was being read aloud is out of date
        case 'passageChanged':
          _reader.stop();
          break;

        case 'POICheck':
          // checks if the player is in collection vicinity of a POI
          // collects the PoI if so.
          checkPOI();
          loggingService.logEvent('Game is checking for proximity to POIs/distance traveled.', email: userData.email);
          break;

        case "clearPOIList":
          // clears the current list of POIs in the SessionManager
          SessionManager.poiList.clear();

          break;

        case 'hintRequest':
          // provides player with a hint directing them towards the nearest POI
          provideHint();
          loggingService.logEvent('Player requested a hint.', email: userData.email);
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
          final now = DateTime.now();
          if (_lastMeasurementTime != null &&
              now.difference(_lastMeasurementTime!).inSeconds < 30) {
            debugPrint("[FLUTTER_BRIDGE] Measurement skipped — cooldown active.");
            loggingService.logEvent('Player requested to measure internet, but API is in cooldown.', email: userData.email);
            break;
          }
          _lastMeasurementTime = now;
          try {
            debugPrint("[FLUTTER_BRIDGE]: Calling getInternetMeasurement, recording speed.");
            // call NDT7-client
            final download = await _ndt7Service.runDownloadTest((status) {});
            final upload = await _ndt7Service.runUploadTest((status) {});

            InternetMeasurement measurement = InternetMeasurement(
              uploadSpeed:  upload['speedMbps'],
              downloadSpeed: download['speedMbps'],
              latency: download['latency'],
              jitters: 0.0,
            );
            loggingService.logEvent('Player measured their internet.', email: userData.email);
            debugPrint("[FLUTTER_BRIDGE]: Adding measurement to measurements list.");
            SessionManager.addMeasurement(measurement);



            // get user location; the measurement is still recorded without it if location is unavailable
            LocationData? loc;
            try {
              loc = await determineLocationData();
            } catch (e) {
              debugPrint("[FLUTTER_BRIDGE] Location unavailable, recording measurement without it: $e");
            }

            final checkData = <String, dynamic>{
              'game': SessionManager.currentGame,
              'download_speed': download['speedMbps'],
              'upload_speed': upload['speedMbps'],
              'latency': download['latency'],
              'timestamp': FieldValue.serverTimestamp(),
              'session_id': SessionManager.sessionId,
              'vpn_used' : vpn_status,
            };

            if (loc != null) {
              LocationPoint point = LocationPoint(longitude: loc.position.longitude, latitude: loc.position.latitude);
              locationPoints.add(point);
              SessionManager.sessionLocationPoints.add(point);

              // convert point to geohash, this is for mapping points later
              final GeoFirePoint geoFirePoint = GeoFirePoint(GeoPoint(point.longitude, point.latitude));
              checkData['latitude'] = loc.position.latitude;
              checkData['longitude'] = loc.position.longitude;
              checkData['geohash'] = geoFirePoint.geohash;
            }

            try {
              debugPrint("Attempting to write to Firestore...");
              final savedRef = await FirebaseFirestore.instance
                  .collection('measurements')
                  .doc(userData.email)
                  .collection('collected_measurements')
                  .add(checkData);
              debugPrint("Write successful!");
              // also publish the anonymized copy that the shared map reads
              await PublicMeasurements.publish(savedRef.id, checkData);
            } catch (e) {
              debugPrint("Firestore Error: $e");
            }

          } catch (e) {
          debugPrint("[FLUTTER_BRIDGE] Error in getInternetMeasurement: $e"); // ✅ visible errors
        }

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
    // get location; the game is always answered, with an error if there is no location, so it never waits forever
    final loc = await _currentLocation();
    if (!mounted) return;
    final Map<String, dynamic> reply;
    if (loc == null) {
      reply = {'latitude': null, 'longitude': null, 'context': context, 'error': 'location unavailable'};
    } else {
      locationPoints.add(LocationPoint(longitude: loc.position.longitude, latitude: loc.position.latitude));
      reply = {
        'latitude': loc.position.latitude,
        'longitude': loc.position.longitude,
        'context': context, // echo back context
      };
    }
    // return the location json to JS
    controller.runJavaScript(
        "window.onLocationJSON(${jsonEncode(jsonEncode(reply))})"); // need to encode the json twice for JS reception
  }

  // uses measureInternet() function to measure internet and send data to JS
  void grabMetrics() async{
    // use the NDT7 service to get the metrics
    final results = await _ndt7Service.runFullTest();
    final json = jsonEncode(results);


    // return the placeholder json
    controller.runJavaScript(
        "window.onMetrics(${jsonEncode(json)})"); // need to encode the json twice for JS reception
  }

  // Looks for POIs near the player and stores them for the game. It never throws, and when none are found the
  // list is simply empty, which puts the game in the "move a distance" fallback.
  Future<void> _lookUpPois() async {
    try {
      debugPrint("[FLUTTER_BRIDGE]: Starting POI generation...");
      final poiGenerator = PoiListGenerator();
      final poiList = await poiGenerator.generatePOIList(5);
      debugPrint("[FLUTTER_BRIDGE]: POI list generated: $poiList");
      SessionManager.setPOIs(poiList);

      // the fallback is measured from where the player was when the POIs were looked up
      if (poiGenerator.locationKnown) {
        SessionManager.fallback.startFrom(
          LocationPoint(longitude: poiGenerator.user_longitude, latitude: poiGenerator.user_latitude),
        );
      }
    } catch (e) {
      debugPrint("[FLUTTER_BRIDGE]: Critical error looking up POIs: $e");
      SessionManager.setPOIs([]);
    }
  }

  void setSessionPOIs() {
    _poiLookup = _lookUpPois();
  }

  // Sets up saving and resuming in the game's page, once it has loaded.
  //
  // The resume script goes in first on purpose: it holds off saving before the story shows anything, so the opening
  // passage cannot overwrite the very save the player is being put back into. The page can finish loading more than
  // once (an in-game reload), and both scripts do nothing the second time, so this is safe to run again.
  Future<void> _installProgressScripts() async {
    final resumeFrom = widget.resumeFrom;
    try {
      if (resumeFrom != null) {
        debugPrint('[FLUTTER_BRIDGE] Resuming ${widget.title} from ${resumeFrom.passage ?? 'the saved point'}.');
        await controller.runJavaScript(resumeScript(resumeFrom.save));
      }
      await controller.runJavaScript(gameProgressHookScript);
    } catch (e) {
      // the game is still perfectly playable, it just will not remember where the player got to
      debugPrint('[FLUTTER_BRIDGE] Could not set up saving for ${widget.title}: $e');
    }
  }

  // A check or hint asked for while the POI lookup is still running waits briefly for it, so it uses the POIs
  // instead of wrongly falling back to the "move a distance" mode.
  Future<void> _waitForPoiLookup() async {
    final lookup = _poiLookup;
    if (lookup == null) return;
    try {
      await lookup.timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("[FLUTTER_BRIDGE]: POI lookup still running, continuing without waiting: $e");
    }
  }

  // The player's current location, or null if it cannot be read (location off, no permission, or no fix in time).
  Future<LocationData?> _currentLocation() async {
    try {
      return await determineLocationData().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint("[FLUTTER_BRIDGE]: Location unavailable: $e");
      return null;
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

    // get location; still write the payload without it if location is unavailable
    try {
      final loc = await determineLocationData();
      locationPoints.add(LocationPoint(longitude: loc.position.longitude, latitude: loc.position.latitude));
      payload['latitude'] = loc.position.latitude;
      payload['longitude'] = loc.position.longitude;
    } catch (e) {
      debugPrint('[WRITECHECKDATA] Location unavailable, writing without it: $e');
    }

    // write additional data to payload before publishing to firestore
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

  // replaces the checkPOI function in the event that there are no POIs near the player
  Future<void> noPOICheck(LocationData loc) async {
    final here = LocationPoint(longitude: loc.position.longitude, latitude: loc.position.latitude);

    // the player "finds" something once they have moved far enough from the last find (or from where they started)
    final collected = SessionManager.fallback.checkFind(here);

    final resultJson = jsonEncode({'collected': collected});
    controller.runJavaScript("window.onPOICheck($resultJson)");
  }

  // Check if the player can collect a POI and return true/false to JS
  Future<void> checkPOI() async {
    await _waitForPoiLookup();

    // grab players current position
    final loc = await _currentLocation();
    if (loc == null) {
      // the game is waiting for an answer, so give it one: nothing can be found without a location
      controller.runJavaScript("window.onPOICheck(${jsonEncode({'collected': false, 'locationUnavailable': true})})");
      return;
    }
    LocationPoint point = LocationPoint(longitude: loc.position.longitude, latitude: loc.position.latitude);
    locationPoints.add(point);

    // if no POIs were found
    if (!poiListStatus) {
      // break out of this function, check other function
      debugPrint("[FLUTTER_BRIDGE] No POIs found in area...moving on...");
      await noPOICheck(loc);
    }
    else {
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
            loc.position.longitude, poi.latitude, poi.longitude);

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
        // if that was the last one, the game switches to the fallback, measured from here
        if (!SessionManager.hasPois) SessionManager.fallback.startFrom(point);
      } else {
        debugPrint("[CHECKPOI] No POI within range.");
      }

      // send results back to JS
      final resultJson = jsonEncode({'collected': collected});
      controller.runJavaScript("window.onPOICheck($resultJson)");
    }
  }

  // sends a hint to the game
  void _sendHint(String hint) {
    controller.runJavaScript("window.onHint(${jsonEncode({'hint': hint})});");
  }

  // Callback function to perform hint generation
  Future<void> provideHint() async {
    await _waitForPoiLookup();

    // get user current position and heading
    final loc = await _currentLocation();
    if (loc == null) {
      _sendHint('not available because location is turned off. Turn on location and try again.');
      return;
    }
    LocationPoint point = LocationPoint(longitude: loc.position.longitude, latitude: loc.position.latitude);
    locationPoints.add(point);
    final userPos = loc.position;

    // if there are no POIs
    if (!poiListStatus) {
      // get distance traveled between the last find (or the start) and the player
      final distanceMoved = SessionManager.fallback.distanceMoved(point);
      _sendHint(fallbackHint(distanceMoved));
      return;
    }

    final heading = loc.heading;
    // verify that a heading was received
    if (heading == null) {
      _sendHint('No compass available');
      return;
    }

    // get the nearest POI
    final nearestPOI = SessionManager.getNearestPOI(userPos);
    // verify POI exists
    if (nearestPOI == null) {
      _sendHint('No POIs available');
      return;
    }

    // calculate bearing from user to POI, then say where it is relative to the way the player is facing
    final bearingToPOI = Geolocator.bearingBetween(userPos.latitude,
        userPos.longitude, nearestPOI.latitude, nearestPOI.longitude);
    _sendHint(directionHint(bearingToPOI, heading));
  }

  // The Listen button: reads the page the player is on aloud, or stops if it is already reading.
  Future<void> _toggleReading() async {
    if (_reader.isSpeaking) {
      await _reader.stop();
      return;
    }

    // ask the game page for the text it is showing right now
    String text = '';
    try {
      final result = await controller.runJavaScriptReturningResult(readablePageTextScript);
      text = decodeJavaScriptString(result);
    } catch (e) {
      debugPrint('[FLUTTER_BRIDGE] Could not get the page text: $e');
    }

    final userData = Provider.of<UserDataProvider>(context, listen: false);
    loggingService.logEvent('Player asked to listen to a page of ${widget.title}.', email: userData.email);

    final outcome = await _reader.read(text);
    if (!mounted) return;
    final message = switch (outcome) {
      ReadOutcome.nothingToRead => 'There is no text to read on this page.',
      ReadOutcome.unavailable => 'Audio is not available on this device. Check that text-to-speech is installed and turned on.',
      _ => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // changes between "listen" and "stop" as the page is read
          ListenableBuilder(
            listenable: _reader,
            builder: (context, _) => IconButton(
              icon: Icon(_reader.isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up),
              tooltip: _reader.isSpeaking ? 'Stop reading' : 'Listen to this page',
              // nothing to read until the game has loaded
              onPressed: isLoading ? null : _toggleReading,
            ),
          ),
        ],
      ),
      // SafeArea keeps the game's bottom buttons out from under the system navigation bar
      // (gesture area or home/back buttons), which newer Android versions draw over the app
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            WebViewWidget(controller: controller),
            if (isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}