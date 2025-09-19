# NetGauge_Games

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Communication Between Twine, the NetGauge App, and the Firestore Database
All of the communication between NetGauge and the built out Twine games is handled by the app itself in the homepage.dart file. Here are some important functions that you may need to know about:

--handle_native_message:
On the Twine game side, certain actions will lead to messages being posted to the backend of the app. When these messages get read by this function, it triggers an associated message or action. For example, if the game has a function that gets the user's location, it will trigger a series of events in the NetGauge app that will collect the location in the back-end.

--runJavaScript:
This function is mused to send information to the callback function on the Twine side. When we call a function on the JavaScript side (meaning within the Twine game), we provide it with context so it knows what information it needs to get provided with when it calls the next function.

--FlutterBridge.postMessage():
This command chooses the function that will be ran, taking in context to pass off to the game side. In order to write a function that interacts with the Flutter bridge, you must use the window structure, which allows JavaScript to access things beyond the game itself. An example of this syntax is window.requestMetricsAndWriteData().

--SessionManager:
This keeps track of data and how it is being used, including but not limitted to the session ID, the game's POI lists, and the player ID.

--writeCheckData:
This is the function that writes data to the firestore database.

--Reception Functions:
There are a few examples of reception functions, which vary based on what you need to do. Essentially, these are two-way forms of communication, where the game will post a message, the native message handler reads the message and runs a function in the back-end, and then it gives something back to the Twine side so call a JavaScript function.

_Important files and widgets you should know about_

--Location_logger.dart
Writes persistent location data to firestore.

--Widget _buildTile:
Used specifically for building HTML files and is located in homepage.dart.

--Widget _buildPageTile:
Provides the title, icon, and the page, used for the speed test.

## Deployment
Android studio is required for Android deployment and is the easiest way to install the Android SDK. You should also download the Android NDK, which does not come automatically with Android Studio.

Make sure when you are deploying the code that you are not using VSCode's terminal, but rather the computer terminal navigated into the directory where your Flutter code is.

