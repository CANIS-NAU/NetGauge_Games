# Welcome to NetGauge!

This is a playful mobile crowdsensing app. Our mission is to address gaps in network broadband coverage through playful, mobile phone-based experiences! In this README, we will go over some basics for how the app works and how it can be adapted. Further documentation can be found here: [https://docs.google.com/document/d/1zF-ACzqcxePOPnuxDHSR9DxybQAbec2Ndd_oC-av4qg/edit?usp=sharing] 

# Setting up your Programming Environment

You will need to have Flutter/Dart installed on your machine, as well as an IDE of your choosing. Check out Flutter's website for OS-specific installations here: https://docs.flutter.dev/install

Not sure what IDE to use? Android Studio is a great option, because it has easy emulator integration. You can download it here: https://developer.android.com/studio

If you are working on a Mac, you'll want to install XCode for deployment: https://developer.apple.com/xcode/

Now, all you have to do is clone this repository and you are ready to get started! If you are new to GitHub, the desktop app is really useful for these sorts of things: https://docs.github.com/en/desktop/installing-and-authenticating-to-github-desktop/installing-github-desktop

# How Does NetGauge Work?

Here, we go over specific areas of NetGauge's system.

## How is Internet Measured?

Currently, internet measurements are collected using the NDT7 client: [https://www.measurementlab.net/tests/ndt/ndt7/]

All code for this in NetGauge can be found in the file titled "ndt7_service.dart." Essentially, we first establish a web socket connection and then use a URL to access the NDT7 server, saving the results that are produced for different aspects of the speed test (e.g., upload speed, download speed). Heads up--there is a rate limit for this. If you are trying to call the NDT7 client for a measurement too much, it will make you wait.

## How Does NetGauge Find Points of Interest?

All code for this is located in the "poi_generator.dart" file. We mainly utilize Overpass API for gathering points of interest: [https://wiki.openstreetmap.org/wiki/Overpass_API]

However, due to rate limiting, the code is set up to utilize mirrors, if needed.

The code will always fetch the following information on the nearest POIs to the user: latitude, longitude, and radius. Optionally, this can also fetch the amenity type and associated tags. The desired number of POIs will be returned as a list, in order from closest to furthest from the user's location.

## How Do I Add New Games to NetGauge?

Currently, you need to manually adjust the code to add new games to the platform. However, we are currently working on an upgrade to add in new games via Firebase! (Coming Soon!)



