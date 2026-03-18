// New homepage, so I can easily refer to the original home page as needed
import 'package:flutter/material.dart';
import 'widgets/buttons.dart';
import 'game_catalog.dart';
import 'user_data_manager.dart';
import 'package:provider/provider.dart';
import 'dashboard.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'dynamic_map.dart';
import 'information.dart';
import 'community_statistics.dart';
import 'settings.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'activity_logs.dart';
import 'package:get_it/get_it.dart';
import 'onboarding.dart';

final loggingService = GetIt.instance<LoggingService>();

class Utilities {
  final String text;
  final IconData? icon;
  final String? imagePath;
  Utilities({required this.text, this.icon, this.imagePath});

}

final List<Utilities> utilityButtons = [
  Utilities(text: "Game Catalog", icon:Icons.menu_book),
  Utilities(text: "Settings", icon:Icons.settings),
  Utilities(text: "Community Statistics", icon:Icons.auto_graph_rounded),
];

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _onboardingShown = false;

  @override
  void initState() {
    super.initState();
    // Show the popup after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_onboardingShown) {
        showCustomOnBoardingPopup(context);
        _onboardingShown = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    final favoriteGames = Provider.of<UserDataProvider>(context).favoriteGames;
    loggingService.logEvent('User is in home page', phone: userData.phone);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.help_outline_rounded),
          onPressed: () {
            FirebaseAnalytics.instance.logEvent(
              name: 'page_navigation',
              parameters: {
                'current_page': 'home',
                'new_page': 'information',
              },
            );
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Information()),
            );
          },
        ),
        centerTitle: true,
        title: const Text(
            'NetGauge Games',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 25)
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                color: Colors.white,
                child:
                  Text(
                      'Total Points Collected: ${userData.measurementsTaken} \n'
                          'Total Distance Traveled: ${userData.distanceTraveled} \n'
                          'Total Radius of Gyration: ${userData.totalRadiusGyration}',
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          fontSize: 20)
                  ),
              ),
              // add expand player statistics button
              TextButton(
                onPressed: () => {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PlayerStatistics()),
                  ),
                  loggingService.logEvent('Clicked expand player statistics', phone: userData.phone)
                },
                style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        color: Colors.black, // Specify the border color
                        width: 3,           // Specify the border width
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  fixedSize: const Size(500, 25),
                  //backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(
                      fontSize: 20,
                    fontWeight: FontWeight.w400,
                  )
                ),
                child: const Text("Expand Player Statistics"),
                //TODO: Nice-to-have-->add a trailing expand icon here
              ),
              const SizedBox(height: 10),
              //TODO: Add map preview here, remove SizedBox placeholder
              Container(
                decoration: BoxDecoration(
                  // Use BoxDecoration to add a border and other styling
                  border: Border.all(
                    color: Colors.black, // Specify the border color
                    width: 3.0, // Specify the border thickness
                  ),
                ),
                height: 250,
                width: double.infinity,
                child: OSMFlutter(
                  controller: MapController(
                    initPosition: GeoPoint(latitude: 47.4358055, longitude: 8.4737324),
                    areaLimit: const BoundingBox(
                      east: 10.4922941,
                      north: 47.8084648,
                      south: 45.817995,
                      west: 5.9559113,
                    ),
                  ),
                  osmOption: OSMOption(
                    userTrackingOption: const UserTrackingOption(
                      enableTracking: true,
                      unFollowUser: false,
                    ),
                    zoomOption: const ZoomOption(
                      initZoom: 8,
                      minZoomLevel: 3,
                      maxZoomLevel: 19,
                      stepZoom: 1.0,
                    ),
                    userLocationMarker: UserLocationMaker(
                      personMarker: const MarkerIcon(
                        icon: Icon(
                          Icons.location_history_rounded,
                          color: Colors.red,
                          size: 48,
                        ),
                      ),
                      directionArrowMarker: const MarkerIcon(
                        icon: Icon(
                          Icons.double_arrow,
                          size: 48,
                        ),
                      ),
                    ),
                    roadConfiguration: const RoadOption(
                      roadColor: Colors.yellowAccent,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DynamicMap()),
                  ),
                  loggingService.logEvent('Clicked expand map', phone: userData.phone)
                },
                style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        color: Colors.black, // Specify the border color
                        width: 3,           // Specify the border width
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    fixedSize: const Size(500, 25),
                    //backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                    )
                ),
                child: const Text("Expand Map"),
                //TODO: Nice-to-have-->add a trailing expand icon here
              ),
              const SizedBox(height: 10),
              // Utility buttons
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 15 / 12,
                ),
                itemCount: utilityButtons.length,
                itemBuilder: (context, index) {
                  return AppButtons(
                    textColor: Colors.deepPurple,
                    backgroundColor: Colors.white,
                    borderColor: Colors.deepPurple,
                    text: utilityButtons[index].text,
                    icon: utilityButtons[index].icon,
                    imagePath: utilityButtons[index].imagePath,
                    isIcon: true,
                    iconSize: 25,
                    textSize: 13,
                    buttonHeight: 40,
                    buttonLength: 65,
                    onTap: () async {
                      String buttonText = utilityButtons[index].text;
                      if (buttonText == 'Settings') {
                        loggingService.logEvent('Clicked on settings', phone: userData.phone);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Settings(),
                          ),
                        );
                      } else if (buttonText == 'Game Catalog') {
                        loggingService.logEvent('Clicked game catalog', phone: userData.phone);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const GameCatalog()),
                        );
                        // After returning, rebuild the UI to show the new favorites
                        setState(() {});
                      } else if (buttonText == 'Community Statistics') {
                        loggingService.logEvent('Clicked community statistics', phone: userData.phone);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CommunityStatistics())
                        );
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              // Game buttons
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 50 / 40,
                ),
                itemCount: favoriteGames.length,
                itemBuilder: (context, index) {
                  return AppButtons(
                    textColor: Colors.black,
                    backgroundColor: Colors.white,
                    borderColor: Colors.black,
                    text: favoriteGames[index].text,
                    icon: favoriteGames[index].icon,
                    imagePath: favoriteGames[index].imagePath,
                    isIcon: true,
                    iconSize: 60,
                    buttonHeight: 45,
                    buttonLength: 45,
                    onTap: () async {
                      loggingService.logEvent('Opened pop-up for ${favoriteGames[index].text}', phone: userData.phone);
                      await showCustomPopup(context, favoriteGames[index]);
                      setState(() {});
                    },
                  );
                },
              ),
            ]
          ),
      ),
      ),
    );
  }
}
