# README

## Setup

First you must clone the repository onto your system utilizing whatever method you like:

GitHub CLI: `gh repo clone CANIS-NAU/NetGauge_Games`

Git HTTPS: `git clone https://github.com/CANIS-NAU/NetGauge_Games.git`

Or, use the GitHub Desktop GUI.

I recommend using VS Code as your editor while working with Flutter apps. Using the VSC Flutter plugins will give you a very nice environment for working with the code. However, when it comes time for you to actually run the code, do NOT run the code via the VSC terminal as this can lead to scoping issues. Instead, use your native system terminal to navigate to the project root directory and run the project from there. This means that, when you install flutter, you need to install it system-wide and not just within VSC. 

To install Flutter, navigate to the installation webpage at https://docs.flutter.dev/get-started/install and choose your system and then the platform you are developing for. After doing this, you will be taken to a page that contains instructions for installation and setup for you device and target device. While I do reccommend following their instructions for configuring a Text Editor or IDE to work with Flutter, I do NOT reccomend using VSC to install flutter. When given the option to install Flutter through VSC or just download the SDK, you should download the SDK system-wide. That said, both installations pathways should work, I just have been using the raw SDK instead of downloading through VSC. 

Depending on the system you are using and the system you are developing for you will get additional instructions on how to install any other dependencies you may need. For example, building for Android will require you to download AndroidStudio, which comes with the Android SDK, amongst other tools.

These instructions for installation and setup on the Flutter homepage are extremely robust, and will give you a better idea of how to set everything up than I can (these are the very docs I used for my first time setup).

Once flutter is installed on your system, you can check its status by running `flutter doctor` in your native system terminal. This will give you an output detailing what your Flutter Build is capable of doing:

```
PS C:\Users\cpend> flutter doctor

┌─────────────────────────────────────────────────────────┐
│ A new version of Flutter is available!                  │
│                                                         │
│ To update to the latest version, run "flutter upgrade". │
└─────────────────────────────────────────────────────────┘
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.29.3, on Microsoft Windows [Version 10.0.26100.4652], locale en-US)
[✓] Windows Version (11 Home 64-bit, 24H2, 2009)
[!] Android toolchain - develop for Android devices (Android SDK version 36.0.0)
    ! Some Android licenses not accepted. To resolve this, run: flutter doctor --android-licenses
[✓] Chrome - develop for the web
[✗] Visual Studio - develop Windows apps
    ✗ Visual Studio not installed; this is necessary to develop Windows apps.
      Download at https://visualstudio.microsoft.com/downloads/.
      Please install the "Desktop development with C++" workload, including all of its default components
[✓] Android Studio (version 2023.3)
[✓] VS Code (version 1.101.1)
[✓] Connected device (3 available)
[✓] Network resources

! Doctor found issues in 2 categories.
```

NOTE: Since I am working on a Windows system, any iOS related developement tools are omitted from the `flutter doctor` output. If you are working on the iOS deployment of the app you will likely be on a macOS system and will see the iOS Toolchain listed.

For our purposes, we only need the iOS and Android Toolchains since those are the two platforms we are developing for. 

**IMPORTANT NOTE FOR ANDROID:** One additional step you will need to take in order to ensure that Firestore read/writes are functional on your deployment version is to download the `google-services.json` file from the apps Firestore instance. To do this, first navigate to https://console.firebase.google.com/u/2/project/nauimg-524b6/overview (you will need to get access to the Firestore database from myself or Dr. Vigil-Hayes) and then navigate to `Project Settings`. This will take you to a page that lists 'Your Apps', one of which will be the Android build. Selecting this app will present you with an option to download `google-services.json`. After downloading, place the file in any or all of the following directories: 

`NetGauge_Games\android\app`
`NetGauge_Games\android\app\src`
`NetGauge_Games\android\app\src\debug`

You will only need to do this once.

## Launching the App

### For Android

Launching the application on an Android device is an extremely simple process. Given the multitude of Android phones we have access to in the lab, I highly reccommend deploying on a physical device. Simply plug the phone into a computer that has the full Android Toolchain installed, and say 'Allow' when the phone prompts you to allow USB debugging access from the connected computer.

To verify the device connection, you can open your terminal and run `flutter devices` which will produce a list of compatible devices that Flutter can deploy to:

```
PS C:\Users\cpend> flutter devices
Found 4 connected devices:
  KB2005 (mobile)   • b83dcac0 • android-arm64  • Android 14 (API 34)
  Windows (desktop) • windows  • windows-x64    • Microsoft Windows [Version 10.0.26100.4652]
  Chrome (web)      • chrome   • web-javascript • Google Chrome 133.0.6943.142
  Edge (web)        • edge     • web-javascript • Microsoft Edge 138.0.3351.121

Run "flutter emulators" to list and start any available device emulators.

If you expected another device to be detected, please run "flutter doctor" to diagnose potential issues. You may also
try increasing the time to wait for connected devices with the "--device-timeout" flag. Visit https://flutter.dev/setup/
for troubleshooting tips.
```

Then, navigate to the project root at `\NetGauge_Games\` and first run the command `flutter pub get`. This will ensure that all the required dependencies are installed onto your system so that the app can deploy properly. Then, simply run the command `flutter run`. This command will automatically default to the connected phone and install onto a debug version of the app. If you leave your device plugged into the computer during testing, you will also see debug output as the app runs.

If you would like to be extremely robust in your deployment process, you can clean the project and rebuild it each time you deploy by running `flutter clean` then `flutter pub get` then `flutter run`. However, this is not necessary.


### For iOS

WIP

## File Overview

All of the relevant Flutter code is located at `\NetGauge_Games\lib\`

1. `main.dart`:
2. `homepage.dart`:
3. `location_service.dart`:
4. `location_logger.dart`:
5. `vibration_controller.dart`:
6. `session_manager.dart`:
7. `ndt7_service.dart`:
8. `name_entry_page.dart`:
9. `speed_test_page.dart`:
10. `likert_form.dart`:
    
## Important Code

### The Flutter Bridge

The single most important piece of code is the Flutter Bridge that facilitates communication between the application backend and the JavaScript code that runs in the Twine games. All the relevant code for the Flutter Bridge lives in `homepage.dart`. 

The Flutter Bridge is created as a JavaScript channel when we initialize the WebView element in `homepage.dart`:

```{dart}
class _WebViewPageState extends State<WebViewPage> {
  ...
  ...
  ...
      // register a JavaScript channel named 'FlutterBridge'
      // to receives messages from the web content
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          handleNativeMessage(message.message);
        },
      );
  ...
  ...
  ...
  }
```

This creates the channel that allows information to be communicated between the HTML games and the Application itself. The Flutter Bridge uses a Native Message Handler to process the requests sent from the games. Put simply, a game posts a 'message' through the Flutter Bridge that represents a particular request along with a payload of information if necessary. The `handleNativeMessage` function in the `_WebViewPageState` class processes this message and executes the associated command. Here is the main body of the `handleNativeMessage` function:

```{dart}
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
```

As you can see, it's fairly simple. Each string message has an associated case that performs a particular action when received. The particular functions run by these different cases are written in different parts of the code, though many are written at the bottom of `homepage.dart`. Creating a new message case is simple-- just add a new case statement to the Native Message Handler, write the functionality you would like it perform within the case statement, and then publish the message you created via the game JavaScript.

Publishing messages from the Story JavaScript is a also a fairly straightforward procedure, though it depends on what information the function on the app side requires to properly execute. For example, SoulSeeker and ZombieApocalypse both utilize a hint system in order to assist the player in locating points of interest. Here is the case where this is defined in the application:

```{dart}
 case 'hintRequest':
          // provides player with a hint directing them towards the nearest POI
          provideHint();
          break;
```

When the message `hintRequest` is received by the FlutterBridge, all it does is call the `provideHint` function which takes no arguments. This means that, on the JavaScript side, we need to provide no additional data, just publish the message:

```{JavaScript}
// requests an orientation hint from Flutter
window.requestHint = function() {
  FlutterBridge.postMessage(JSON.stringify({command: "hintRequest"}));
};
```

However, different communications may require the Twine application to send some data to application, which entails the creation of a payload that is passed alongside the message. For example, many of the games are designed to write data to Firestore whenever the player takes an action that leads to an internet measurement test being performed. This means that we need to create a payload of relevant data we want to write, send that over to the application, and then the application writes that data to Firestore. Here is an example of one such function in ScavengerHunt:

```{JavaScript}
// function to request metrics data from Flutter bridge
window.requestMetricsAndWriteData = function()
{ 
  // check current player site
  var site;
  
  if(State.variables.insideCampus)
  {
	site = "campus";
  } else if (State.variables.insideUrban) {
   	site = "urban"; 
  } else if (State.variables.insideRural) {
   	site = "rural"; 
  } else {
   	site = "unidentifiedSite"; 
  }
  
  // post a message to the FlutterBbridge requesting internet metrics
  // include data payload for Firestore data writing
  FlutterBridge.postMessage(JSON.stringify({
    command: "requestMetricsAndWriteData",
    payload: {
      nickname: State.variables.playerName,
      datetime: new Date().toISOString(),
      game: "ScavengerHunt.html",
      hexagon: site,
      question: State.variables.hintAnswered
    }
  }));
};
```

You can see that, when the message is posted to the FlutterBridge, it contains both the relevant command as well as a Payload of information that is to be written to Firestore. This message is received by the Native Message Handler and processed through this case:

```{dart}
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
```

The payload is provided to the `writeCheckData()` function to be written to Firestore. 

In addition to the games needing to communicate information to the app, there are many times where the app needs to communicate information back to the games, which is done utilizing a callback system. The simple Location Request logic is one such example, where the game requests location information from the app and the app provides it.

The Location Request is executed within a game as:

```{JavaScript}
// Function to request location data from Flutter
// context dictates what to do with the data once 
// received.
window.requestLocation = function(context)
{
  // post a message to the flutter bridge requesting location data
  // and the context in which to use the location data
  FlutterBridge.postMessage(JSON.stringify({
    command: "getLocation", // runs getLocation in Flutter
    context: context // what to do with returned location data
  }));
};
```

Here, 'getLocation' is the message command, and `context` is a message dictating what to do with the location data when it is received (we will talk more about the `context` element when we get to the callback function). When this message is posted, the Native Message Handler receives and manages it through this case statement:

```{dart}
// JS is requesting location
        case 'getLocation':
          // store request context (what to do with the returned location)
          final context = data['context'];
          
          // call async function to send the location data
          sendLocationJSON(context);
          break;
```

Which grabs the location, and then, crucially, sends it back to the game via the `sendLocationJSON()` function:

```{dart}
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
```

This function builds the location object to be returned, and add the very end calls a callback function that exists within the JavaScript code via `controller.runJavaScript("window.onLocationJSON(${jsonEncode(json)})");`, where `window.onLocationJSON()` is the name of the callback function:

```{JavaScript}
// Callback function that receives location JSON from
// flutter and uses context to decide what to do with that
// data
window.onLocationJSON = function(json)
{
  const data = JSON.parse(json);
  const context = data.context;
  
  // determine what needs to be done with the returned location
  // data
  switch(context) {
    case 'zoneCheck': // determining if the player is in a valid zone
      const lat = data.latitude;
      const lon = data.longitude;
      
      // log for debugging
      console.log("User Lat: ", lat);
      console.log("User Lon: ", lon);
      
      // initialize location statuses as false
      let insideCampus = false;
      let insideUrban = false;
      let insideRural = false;
      
      insideCampus = isPointInsideHexagon(lat, lon, campusSpace);
      insideUrban = isPointInsideHexagon(lat, lon, urbanSpace);
      insideRural = isPointInsideHexagon(lat, lon, ruralSpace);
      
      // debug logs
      console.log("insideCampus", insideCampus);
      console.log("insideUrban", insideUrban);
      console.log("insideRural", insideRural);
      
      State.variables.insideCampus = insideCampus;
      State.variables.insideUrban = insideUrban;
      State.variables.insideRural = insideRural;
      break;
      
    default: // unrecognized context
      console.warn("Unrecognized location context: ", context);
  }
};
```

This function receives and processes the location data, performing whatever task is established by the `context`. In the example above, there is only a single context for a Location Request. However, future games may require additional contexts, so the callback function was made to be extensible depending on what additional contexts may be needed. This is crucial to note, because it means that there is no one single way to write these message publication/callback functions in the Story JavaScript. The functions that live in the app background are indeed static and will remain unchanged, but depening on your needs you can adjust the `window.requestLocationJSON()` and `window.onLocationJSON()` functions to send and receive the information however you'd like. Perhaps one of your games has 5 location request contexts and another game only has 2. In both of these games, the message publication and callback functions will look different as a result of the different purposes. This makes it difficult to detail one specific way to write these publication and callback functions as they are designed to be customizable and extensible depending on the use case.

This is not a full coverage of every single message command contained within the Native Message Handler, but it should be enough to understand the intended purpose of the tool, how to utilize it, how to extend it, and how to read the associated code in the JavaScript. I reccommend reading through the different possible messages that can be received and understanding how those are utilized in the different games. 

### `pubspec.yaml`

The `pubspec.yaml` file (located at the root level of the project) is where all of the dependencies and assets are listed out. Whenever you would like to add a new dependency, you declare it in this document. Additionally, whenever you add any asset of any kind (game, image, sound, etc.) you also *must* declart it here. Simply adding the asset to the `\assets` folder is not enough to make it accessible by the app, it also must be declared in the `pubspec.yaml` file:


```
# To add assets to your application, add an assets section, like this:
  assets:
    - assets/SoulSeeker.html
    - assets/ZombieApocalypse.html
    - assets/ScavengerHunt.html
    - assets/DragonSlayer.html
    - assets/icons/ability-icon.png
    - assets/icons/antidote-icon.png
    - assets/icons/attack-icon.png
    - assets/icons/help-icon.png
    - assets/icons/movement-icon.png
    - assets/icons/no-antidote-icon.png
    - assets/icons/noise-icon.png
    - assets/icons/orientation-icon.png
    - assets/icons/search-icon.png
    - assets/icons/victory-icon.png
    - assets/maps/Campus-PlayArea.png
    - assets/maps/Rural-PlayArea.png
    ...
    ...
    ...
```
### Tiles

We refer to the buttons that exist on the homepage that launch the various games as `Tiles', and there are two typs. 

A standard Tile is utilized to build a button that launches a particular HTML game into the WebView (located in `homepage.dart`, and is defined as:

```{dart}
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
```

It takes the title to be displayed on the button, an icon to represent the game (currently a placeholder), the name of the gamefile to run (make sure it is both in the `\assets` folder and declared in `pubspec.yaml`), and the build context. 

The other Tile type is called a Page Tile, and it is utilized to launch other Flutter pages. For example, our clone of a typical internet speed test application is not built in twine, but directly into Flutter. Thus, launching this page requires different methodology from opening an HTML file in the WebView:

```{dart}
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
```

Both `_buildTile()` and `_buildPageTile()` are utilized in the `build` method of the homepage:

```{homepage.dart}
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
```

To add more tiles to the homepage, simply update this build funciton with the additional tile that you are aiming to build. 

### Device-Specfic Folders and Files

Very rarely you may have to make changes to device-specific files and folders instead of making global changes to the dart code. You can locate Android specific files at `NetGauge_Games\android` and iOS specific files at `NetGauge_Games\ios`. 

The two device-specific files you are most likely to interact with are the permissions files. These are the files that dictate what permissions the app will need to use on the device, and therefore must be device-specific. 

The Android permissions file is called `AndroidManifest.xml` and is located at `\NetGauge_Games\android\app\src\main`.

The iOS permissions file is called `info.plist` and is located at `\NetGauge_Games\ios\Runner\`.
 
## TODO

- Currently, the iOS build of the application is only semi-functional. It deploys and runs as expected on an iOS emulator, but does not seem to run on physical hardware.
- While the internet measurement system is indeed buit and functional (see `ndt7_service.dart`) it is not actually utilized in the Native Message Handler yet, I have only used it in isolated tests that print the output to the console. The NDT7 Service will need to be updated such that, instead of publishing the data to the console, it stores the data in some kind of data structure, and thend the `grabMetrics` function (in `homepage.dart`) will need to be updted to send this data structure to the JavaScript side (via the `window.onMetrics()`) function. Additionally, any function in the JavaScript that is designed to display these metrics to the user after they are collected now needs to be updated to wait for the test to be performed. Right now, the JavaScript side will display empty measurement values becuase it is trying to display those values before they are actually computed.
- the ndt7_service_implemention branch needs to be merged with the mapping_service_implementation branch, and then all of that merged into main. You may want to reach out to me (Cole) when you do this and I can help you with merge conflicts.
- When we built the iOS version of the app and listed it on our Apple Developer account we made a typo, meaning the project is recognized as `NetGagueGames` and not `NetGaugeGames`. This, unfortunately, is not a simple fix at all. We will need to remake the app in the Apple Developer account and then regenerate *all* of the permissions files and signing certifications that Apple requires when developing any sort of app. Additionally, we will need to go through the iOS-specific files and change any reference to `NetGagueGames` to `NetGaugeGames`.
- Read through this documentation for spelling errors.

## Things That Will Likely Change
There are a handful of systems that were built to be minimally functional and will likely need to change as the app grows towards a more fleshed out system. 

1. The POI System. Currently, both the SoulSeeker and ZombieApocalypse games utilize points of interest that the player needs to search for, albeit in different ways. SoulSeeker sends a single POI at a time, depending on the play area the user is within and the realm they are in on the game side:

```{JavaScript}
// Determine which group of POIs to send to android based on the hexagon the user is in
window.sendPOIData = function(){
  
  // Send point of Interest for each realm in each of the 3 testing locations
  if(State.variables.insideCampus) {
    if(State.variables.tutorialComplete)
    {
      if(State.variables.fragmentCounter == 0) {
        console.log("Campus FirstRealm POI sent to Flutter");
        
        // vibration system designed to work with a list of POIs
        const poiList = [
          { latitude: 35.186191, longitude: -111.658219}
        ];
        
        // Send the POI set to Flutter
    	FlutterBridge.postMessage(JSON.stringify({
    		command: "setPOIs",
         	payload: poiList
    	}));
        
        State.variables.FirstRealm = false;
      }
      else if (State.variables.fragmentCounter == 1) {
        console.log("Campus SecondRealm POI sent to Flutter");
        
        // vibration system designed to work with a list of POIs
        const poiList = [
          { latitude: 35.185980, longitude: -111.658405}
        ];
        
        // Send the POI set to Flutter
    	FlutterBridge.postMessage(JSON.stringify({
    		command: "setPOIs",
         	payload: poiList
    	}));
        
        State.variables.SecondRealm = false;
      }
      else if (State.variables.fragmentCounter == 2) {
        console.log("Campus ThirdRealm POI sent to Flutter");
        
        // vibration system designed to work with a list of POIs
        const poiList = [
          { latitude: 35.185564, longitude: -111.658066}
        ];
        
        // Send the POI set to Flutter
    	FlutterBridge.postMessage(JSON.stringify({
    		command: "setPOIs",
         	payload: poiList
    	}));
        
        State.variables.ThirdRealm = false;
      }
    } else {
      console.log("Campus Tutorial POI sent to Flutter");
      
      // vibration system designed to work with a list of POIs
      const poiList = [
        { latitude: 35.185980, longitude: -111.658405}
      ];
      
      // Send the POI set to Flutter
    	FlutterBridge.postMessage(JSON.stringify({
    		command: "setPOIs",
         	payload: poiList
    	}));
        
    }
  
  } else if (State.variables.insideUrban) {
    if(State.variables.tutorialComplete)
    {
      if(State.variables.fragmentCounter == 0) {
        console.log("Urban FirstRealm POI sent to Flutter");
        
        // vibration system designed to work with a list of POIs
        const poiList = [
          { latitude: 35.198773, longitude: -111.648046}
        ];
        
        // Send the POI set to Flutter
    	FlutterBridge.postMessage(JSON.stringify({
    		command: "setPOIs",
         	payload: poiList
    	}));
        
        State.variables.FirstRealm = false;
      }
      else if (State.variables.fragmentCounter == 1) {
        console.log("Urban SecondRealm POI sent to Flutter");
        
        // vibration system designed to work with a list of POIs
        const poiList = [
          { latitude: 35.198444, longitude: -111.647922}
        ];
        
        // Send the POI set to Flutter
    	FlutterBridge.postMessage(JSON.stringify({
    		command: "setPOIs",
         	payload: poiList
    	}));
        
        State.variables.SecondRealm = false;
      }
      else if (State.variables.fragmentCounter == 2) {
        console.log("Urban ThirdRealm POI sent to Flutter");
        
        // vibration system designed to work with a list of POIs
        const poiList = [
          { latitude: 35.198521, longitude: -111.648314}
        ];
        
        // Send the POI set to Flutter
    	FlutterBridge.postMessage(JSON.stringify({
    		command: "setPOIs",
         	payload: poiList
    	}));
        
        State.variables.ThirdRealm = false;
      }
    } else {
       console.log("Urban Tutorial POI sent to Flutter");

       // vibration system designed to work with a list of POIs
       const poiList = [
         { latitude: 35.198521, longitude: -111.648314}
       ];
      
       // Send the POI set to Flutter
       FlutterBridge.postMessage(JSON.stringify({
         command: "setPOIs",
         payload: poiList
       }));
    }
    
  } else if (State.variables.insideRural) {
    if(State.variables.tutorialComplete)
    {
      if(State.variables.fragmentCounter == 0) {
        console.log("Rural FirstRealm POI sent to Flutter");
        
        // vibration system designed to work with a list of POIs
       	const poiList = [
         	{ latitude: 35.234222, longitude: -111.665501}
       	];
        
        // Send the POI set to Flutter
    	FlutterBridge.postMessage(JSON.stringify({
    		command: "setPOIs",
         	payload: poiList
    	}));

        State.variables.FirstRealm = false;
      }
      else if (State.variables.fragmentCounter == 1) {
        console.log("Rural SecondRealm POI sent to Flutter");
        
        // vibration system designed to work with a list of POIs
       	const poiList = [
         	{ latitude: 35.234288, longitude: -111.665135}
       	];
        
        // Send the POI set to Flutter
    	FlutterBridge.postMessage(JSON.stringify({
    		command: "setPOIs",
         	payload: poiList
    	}));
        
        State.variables.SecondRealm = false;
      }
      else if (State.variables.fragmentCounter == 2) {
        console.log("Rural ThirdRealm POI sent to Flutter");
        
        // vibration system designed to work with a list of POIs
       	const poiList = [
         	{ latitude: 35.234671, longitude: -111.665116}
       	];
        
        // Send the POI set to Flutter
    	FlutterBridge.postMessage(JSON.stringify({
    		command: "setPOIs",
         	payload: poiList
    	}));
     
        State.variables.ThirdRealm = false;
      }
    } else {
     	console.log("Rural Tutorial POI sent to Flutter");
      
      	// vibration system designed to work with a list of POIs
       	const poiList = [
         	{ latitude: 35.234288, longitude: -111.665135}
       	];
      
      	// Send the POI set to Flutter
    	FlutterBridge.postMessage(JSON.stringify({
    		command: "setPOIs",
         	payload: poiList
    	}));
    }
    
  } else {
    console.log("Not in a play area, no POIs sent");
  }

};
```

This funciton will change dramatically when the POI system becomes more dynamic and generates these points rather than hardcoding them. In fact, you may be able to shift the entirety of the POI logic into the app and out of the games themeselves, though that is up to the discretion of the future dev. The ZombieApocalypse games functions in a similar manner, but it sends groups of interest points instead of infdividual ones:

```{JavaScript}
// Determine which group of POIs to send to android based on the hexagon the user is in
window.sendPOIData = function(){
  // Point of Interest lists for each of the three locations
  var campusPoiTutorial = [
    {latitude: 35.185980, longitude: -111.658405} // SICCS Patio
  ];
  
  var campusPois = [
    {latitude: 35.186191, longitude: -111.658219}, // SICCS entrance
    {latitude: 35.185980, longitude: -111.658405}, // SICCS patio
    {latitude: 35.185765, longitude: -111.658330}, // SICCS small lot
    {latitude: 35.185564, longitude: -111.658066}  // ISB Lot
  ];
  
  var urbanPoiTutorial = [
    {latitude: 35.198521, longitude:-111.648314}  // Mozelle's Bakery Sign
  ];
  
  var urbanPois = [
    {latitude: 35.198773, longitude:-111.648046}, // Green tables near cat sculpture
    {latitude: 35.198600, longitude:-111.647828}, // Hello sugar salon
    {latitude: 35.198521, longitude:-111.648314},  // Mozelle's Bakery Sign
    {latitude: 35.198444, longitude:-111.647922} // Forum Center
  ];
  
  var ruralPoiTutorial = [
    {latitude: 35.234288, longitude: -111.665135} // Progression sculpture
  ];
  
  var ruralPois = [
    {latitude: 35.234288, longitude: -111.665135}, // Progression sculpture
    {latitude: 35.234222, longitude: -111.665501}, // Museum entrance
    {latitude: 35.234671, longitude: -111.665116}, // Parking lot
    {latitude: 35.234244, longitude: -111.665822}  // Left of the entrance, around back
  ];
      
  if(State.variables.insideCampus) {
    if(State.variables.tutorialComplete)
    {
    	console.log("Campus POIs sent to Flutter");
    	FlutterBridge.postMessage(JSON.stringify({
          command: "setPOIs",
          payload: campusPois
        }));
    } else {
     	console.log("Campus Tutorial POI sent to Flutter");
      	FlutterBridge.postMessage(JSON.stringify({
          command: "setPOIs",
          payload: campusPoiTutorial
        }));
    }
  } else if (State.variables.insideUrban) {
    if(State.variables.tutorialComplete)
    {
      	console.log("Urban POIs sent to Flutter");
  		FlutterBridge.postMessage(JSON.stringify({
          command: "setPOIs",
          payload: urbanPois
        }));
    }else{
      	console.log("Urban Tutorial POI sent to Flutter");
      	FlutterBridge.postMessage(JSON.stringify({
          command: "setPOIs",
          payload: urbanPoiTutorial
        }));
    }
  } else if (State.variables.insideRural) {
    if(State.variables.tutorialComplete)
    {
      	console.log("Rural POIs sent to Flutter");
    	FlutterBridge.postMessage(JSON.stringify({
          command: "setPOIs",
          payload: ruralPois
        }));
    }else{
      	console.log("Rural POI tutorial sent to Flutter");
      	FlutterBridge.postMessage(JSON.stringify({
          command: "setPOIs",
          payload: ruralPoiTutorial
        }));
    }
  } else {
    console.log("Not in a play area, no POIs sent");
  }
};
```

Additionally, you will likely be able to entirely remove code that the defines the playspaces that all games use:

```{JavaScript}
// FUNCTIONS RELATED TO DETERMINING PLAYER SPACE //
// Function to compute vertices of a hexagonal plane given a center point and desired area in km^2
function calculateHexagonVertices(centerLatitude, centerLongitude, area) {
    // Calculate side length using the area of a regular hexagon
    const radius = Math.sqrt((2 * area) / (3 * Math.sqrt(3)));

    // Calculate angles for each vertex (in radians)
    const angles = [0, Math.PI / 3, (2 * Math.PI) / 3, Math.PI, (4 * Math.PI) / 3, (5 * Math.PI) / 3];

    // Earth's radius in kilometers
    const earthRadius = 6371;

    // Convert radius from kilometers to degrees
    const radiusLat = (radius / earthRadius) * (180 / Math.PI);
    const radiusLon = radiusLat / Math.cos(centerLatitude * (Math.PI / 180));

    // Calculate vertices
    const vertices = angles.map(angle => {
        const latitude = centerLatitude + radiusLat * Math.cos(angle);
        const longitude = centerLongitude + radiusLon * Math.sin(angle);
        return { latitude, longitude };
    });

    return vertices;
}

// Check if a point is in any of our hexagons
function isPointInsideHexagon(pointLatitude, pointLongitude, vertices) {
  const numVertices = 6;
  let inside = false;
	
  // Loop through each edge of the Campus Hexagon
  for (let i = 0, j = numVertices - 1; i < numVertices; j = i++) {
    const vertex1 = vertices[i];
    const vertex2 = vertices[j];

    // Check if the point's longitude is between the longitudes of the current edge's vertices
    if ((vertex1.longitude > pointLongitude) !== (vertex2.longitude > pointLongitude)) {
      // Calculate the intersection point's latitude
      const intersectionLatitude =
        ((pointLongitude - vertex1.longitude) * (vertex2.latitude - vertex1.latitude)) /
          (vertex2.longitude - vertex1.longitude) +
        vertex1.latitude;

      // Check if the point's latitude is below the intersection latitude
      if (pointLatitude < intersectionLatitude) {
        inside = !inside;
      }
    }
  }
  // Return location status
  return inside;
}

// 0.7km^2 hexagonal plane defined just outside of SICCS (Campus)
let campusSpace = [];
campusSpace = calculateHexagonVertices(35.186127, -111.658185, 0.7);

// 0.7km^2 hexagonal plane defined at Heritage Square in downtown Flagstaff (Urban)
let urbanSpace = [];
urbanSpace = calculateHexagonVertices(35.19913, -111.648010, 0.7);

// 0.7km^2 hexagonal plane defined just outside the Museum of Northern Arizona (Rural)
let ruralSpace = [];
ruralSpace = calculateHexagonVertices(35.234485, -111.666281, 0.7);
```

In the early stages of the platform, we used three hardcoded playspaces that the players could operate the games within, and they are built using the functions above. As the platform becomes more dynamic, these playspaces will no longer need to be generated from hardcoded values. Keep in mind that removing these functions will also require significant changes to the code written in the Twine Passages as they currently utilize these hardcoded functions. Meaning, updating any of this code to be more modern and dynamic will require you to change not just the JavaScript code, but the games themselves. 
