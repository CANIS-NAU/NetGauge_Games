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

This creates the channel that allows information to be communicated between the HTML games and the Application itself. The Flutter Bridge uses a Native Message Handler to process the requests send from the games.

## TODO
