# README

## Setup

### For Android

### For iOS

## Launching the App

### For Android

### For iOS

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

 
## TODO

- Currently, the iOS build of the application is only semi-functional. It deploys and runs as expected on an iOS emulator, but does not seem to run on physical hardware.
- While the internet measurement system is indeed buit and functional (see `ndt7_service.dart`) it is not actually utilized in the Native Message Handler yet, I have only used it in isolated tests that print the output to the console. The NDT7 Service will need to be updated such that, instead of publishing the data to the console, it stores the data in some kind of data structure, and thend the `grabMetrics` function (in `homepage.dart`) will need to be updted to send this data structure to the JavaScript side (via the `window.onMetrics()`) function. Additionally, any function in the JavaScript that is designed to display these metrics to the user after they are collected now needs to be updated to wait for the test to be performed. Right now, the JavaScript side will display empty measurement values becuase it is trying to display those values before they are actually computed.
- the ndt7_service_implemention branch needs to be merged with the mapping_service_implementation branch, and then all of that merged into main. You may want to reach out to me (Cole) when you do this and I can help you with merge conflicts. 
