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
import 'abc_onboarding.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'surveys.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'location_notice.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

final loggingService = GetIt.instance<LoggingService>();

class Utilities {
  final String text;
  final IconData? icon;
  final String? imagePath;
  Utilities({required this.text, this.icon, this.imagePath});
}

final List<Utilities> utilityButtons = [
  Utilities(text: "Game Catalog", icon: Icons.menu_book),
  Utilities(text: "Settings", icon: Icons.settings),
  Utilities(text: "Community Statistics", icon: Icons.auto_graph_rounded),
];

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  // TODO: Change this to match whatever is reflected in user data manager
  bool _onboardingShown = false;
  VoidCallback? _loadingListener;

  /*
  Remote config survey prompting code
  Ref: https://firebase.google.com/docs/tutorials/welcome-back-screen
   */
  Future setupInteractedMessage() async {
    // Get any messages which caused the application to open from
    // a terminated state.
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    // If the message also contains a data property with a "type" of "chat",
    // navigate to a chat screen
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // Also handle any interaction when the app is in the background using a
    // Stream listener
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) {
    // guests are not shown surveys
    if (Provider.of<UserDataProvider>(context, listen: false).isGuestUser) return;
    if (message.data['type'] == 'survey') {
      Navigator.pushNamed(
        context,
        '/survey',
        arguments: SurveyState(
          surveyDocId: message.data['type'],
          responseCollection: 'survey_responses',
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final email = Provider.of<UserDataProvider>(context, listen: false).email;

    if (state == AppLifecycleState.resumed) {
      loggingService.logEvent('App is opened.', email: email);
    } else if (state == AppLifecycleState.paused) {
      loggingService.logEvent('App running in background.', email: email);
    } else if (state == AppLifecycleState.detached) {
      loggingService.logEvent('App session terminated.', email: email);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _waitForDataThenCheckSurvey();
    });
    WidgetsBinding.instance.addObserver(this);
    setupInteractedMessage();

    final userData = Provider.of<UserDataProvider>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (userData.isLoading) {
        _loadingListener = () {
          if (!userData.isLoading && mounted) {
            userData.removeListener(_loadingListener!);
            _loadingListener = null;
            _runStartupChecks(userData);
          }
        };
        userData.addListener(_loadingListener!);
      } else {
        _runStartupChecks(userData);
      }
    });
  }

  void _runStartupChecks(UserDataProvider userData) {
    if (!mounted) return;

    // the demographic survey itself is opened by _checkAndShowSurvey, so no extra pop-up is shown here

    /*if (!_onboardingShown) {
      showCustomOnBoardingPopup(context);
      if (mounted) setState(() => _onboardingShown = true);
    }*/

    loggingService.logEvent(
      'User is in homescreen.',
      email: userData.email,
      params: {'screen': 'HomeScreen'},
    );
  }

  // true if the survey document exists and has at least one question, so we never open an empty survey
  Future<bool> _surveyHasQuestions(String surveyDocId) async {
    if (surveyDocId.isEmpty) return false;
    try {
      final doc = await firestore.FirebaseFirestore.instance.collection('surveys').doc(surveyDocId).get();
      final questions = doc.data()?['questions'];
      return questions is List && questions.isNotEmpty;
    } catch (e) {
      debugPrint("[HOME] Could not check survey $surveyDocId: $e");
      return false;
    }
  }

  // Both survey steps wait for their survey to be closed, so whatever comes next never opens on top of one.
  Future<void> _checkAndShowSurvey() async {
    final userData = Provider.of<UserDataProvider>(context, listen: false);

    // guests are not shown surveys
    if (userData.isGuestUser) return;

    // Priority 1: Demographic survey on first open
    if (!userData.getDemographicStatus) {
      if (await _surveyHasQuestions('demographic')) {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SurveyState(
              surveyDocId: 'demographic',
              responseCollection: 'responses',
            ),
          ),
        );
        // After demographic is done, check if METUX should also show
        if (mounted) await _checkAndShowMetux(userData);
      }
      return; // Don't check METUX yet
    }

    // Priority 2: Remote Config-controlled survey (METUX etc.)
    await _checkAndShowMetux(userData);
  }

  Future<void> _checkAndShowMetux(UserDataProvider userData) async {
    if (!userData.shouldShowSurvey) return;
    if (!await _surveyHasQuestions(userData.remoteSurveyDocId)) return;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SurveyState(
          surveyDocId: userData.remoteSurveyDocId,
          responseCollection: 'responses',
        ),
      ),
    );
  }

  // set once the location notice has been handled, so it appears at most once each time the home screen opens
  bool _locationNoticeHandled = false;

  // Tells people who have location turned off that they will not get the full experience.
  Future<void> _maybeShowLocationNotice() async {
    if (_locationNoticeHandled || !mounted) return;
    _locationNoticeHandled = true;

    final issue = await checkLocationIssue();
    if (issue == null || !mounted) return;

    final userData = Provider.of<UserDataProvider>(context, listen: false);
    loggingService.logEvent('Showing location-off pop-up (${issue.name}).', email: userData.email);
    await showLocationNotice(context, issue);
  }

  // everything shown on arrival, in order: any surveys, then the location notice
  Future<void> _runFirstLaunchFlow() async {
    await _checkAndShowSurvey();
    if (mounted) await _maybeShowLocationNotice();
  }

  Future<void> _waitForDataThenCheckSurvey() async {
    final userData = Provider.of<UserDataProvider>(context, listen: false);

    // Wait until the user's account data has actually loaded. Checking earlier would see an empty profile and
    // think the demographic survey was never taken, even for returning users.
    if (userData.userData == null || userData.isLoading) {
      userData.addListener(_onDataLoaded);
      return;
    }

    _runFirstLaunchFlow();
  }

  void _onDataLoaded() {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    if (userData.userData != null && !userData.isLoading) {
      userData.removeListener(_onDataLoaded);
      _runFirstLaunchFlow();
    }
  }

  @override
  void dispose() {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    if (_loadingListener != null) {
      userData.removeListener(_loadingListener!);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    /*String surveyType = listenRemoteConfig();
    if (surveyType != 'none') {
      showSurveyPopup(context, surveyType);
    }*/
    final favoriteGames = Provider.of<UserDataProvider>(context).favoriteGames;
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    loggingService.logEvent('User is in home page', email: userData.email);
    final scaffoldContext = context;
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
        title: const Text('NetGauge Games',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 25)),
        backgroundColor: const Color(0xFF440154),
        foregroundColor: Colors.white,
      ),
      // SafeArea keeps the bottom buttons out from under the system navigation bar (gesture or 3-button)
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
                //mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: Text(
                        'Total Points Collected: ${userData.totalPointsCollected} \n'
                        'Total Distance Traveled: ${userData.totalDistanceTraveled.toStringAsFixed(2)} \n'
                        'Total Radius of Gyration: ${userData.totalRadiusGyration.toStringAsFixed(2)}',
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                            fontSize: 20)),
                  ),
                  // add expand player statistics button
                  TextButton(
                    onPressed: () {
                      loggingService.logEvent('Clicked expand player statistics', email: userData.email);
                      // statistics belong to an account, so guests only get a message
                      if (userData.isGuestUser) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Must be logged into an account to view')),
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PlayerStatistics()),
                      );
                    },
                    style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(
                            color: Colors.black, // Specify the border color
                            width: 3, // Specify the border width
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: const Color(0xFFfde725),
                        foregroundColor: Colors.black,
                        textStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        )),
                    child: const Text("Expand Player Statistics"),
                    //TODO: Nice-to-have-->add a trailing expand icon here
                  ),
                  const SizedBox(height: 5),
                  //TODO: Add map preview here, remove SizedBox placeholder
                  Container(
                    decoration: BoxDecoration(
                      // Use BoxDecoration to add a border and other styling
                      border: Border.all(
                        color: Colors.black, // Specify the border color
                        width: 3.0, // Specify the border thickness
                      ),
                    ),
                    // scale with the screen so the preview never pushes the buttons below it out of reach
                    height: (screenHeight * 0.25).clamp(160.0, 280.0),
                    width: double.infinity,
                    // the map is a native view that can draw and capture touches outside its bounds on some devices,
                    // so clip it and keep it from receiving touches (and from fighting the page's scrolling)
                    child: ClipRect(
                      child: AbsorbPointer(
                        child: OSMFlutter(
                          controller: MapController(
                            initPosition: GeoPoint(
                                latitude: 47.4358055, longitude: 8.4737324),
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
                                  Icons.location_pin,
                                  color: Color(0xFF21918c),
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
                    ),
                  ),
                  TextButton(
                    onPressed: () => {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const DynamicMap()),
                      ),
                      loggingService.logEvent('Clicked expand map',
                          email: userData.email)
                    },
                    style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(
                            color: Colors.black, // Specify the border color
                            width: 3, // Specify the border width
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: const Color(0xFFfde725),
                        foregroundColor: Colors.black,
                        textStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        )),
                    child: const Text("Expand Map"),
                    //TODO: Nice-to-have-->add a trailing expand icon here
                  ),
                  // Utility buttons
                  GridView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 15 / 12,
                    ),
                    itemCount: utilityButtons.length,
                    itemBuilder: (context, index) {
                      return AppButtons(
                        textColor: const Color(0xFF21918c),
                        backgroundColor: Colors.white,
                        borderColor: const Color(0xFF21918c),
                        text: utilityButtons[index].text,
                        icon: utilityButtons[index].icon,
                        imagePath: utilityButtons[index].imagePath,
                        isIcon: true,
                        iconSize: 25,
                        textSize: 13,
                        buttonHeight: 60,
                        buttonLength: 65,
                        onTap: () async {
                          String buttonText = utilityButtons[index].text;
                          if (buttonText == 'Settings') {
                            loggingService.logEvent('Clicked on settings',
                                email: userData.email);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const Settings()),
                            );
                          } else if (buttonText == 'Game Catalog') {
                            loggingService.logEvent('Clicked game catalog',
                                email: userData.email);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const GameCatalog()),
                            );
                            setState(() {});
                          } else if (buttonText == 'Community Statistics') {
                            loggingService.logEvent(
                              'Clicked on community statistics',
                              email: userData.email,
                            );
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const CommunityStatistics()),
                            );
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 5),
                  // Game buttons
                  GridView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
                          loggingService.logEvent(
                              'Opened pop-up for ${favoriteGames[index]}',
                              email: userData.email);
                          await showCustomPopup(context, favoriteGames[index]);
                          setState(() {});
                        },
                      );
                    },
                  ),
                ]),
          ),
        ),
      ),
    );
  }
}

Future<void> showSurveyPopup(BuildContext context, String surveyID) {
  final userData = Provider.of<UserDataProvider>(context, listen: false);
  loggingService.logEvent('Showing pop-up for $surveyID)',
      email: userData.email);
  String title = "Title";
  String content = "Content";

  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Please take this survey to support our research."),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SurveyState(
                              surveyDocId: surveyID,
                              responseCollection: 'survey_responses',
                            )),
                  )
                },
                style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        color: Colors.black, // Specify the border color
                        width: 3, // Specify the border width
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    fixedSize: const Size(500, 25),
                    //backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                    )),
                child: const Text("Take Survey"),
                //TODO: Nice-to-have-->add a trailing expand icon here
              ),
            ],
          );
        },
      );
    },
  );
}

Future<String> listenRemoteConfig() async {
  // TODO: Listen for Firebase remoteConfig messaging
  final remoteConfig = FirebaseRemoteConfig.instance;
  final String messageId = remoteConfig.getString('onboarding_experiment');

  try {
    debugPrint("ONBOARDING: Initializing Remote Config...");
    // getting remote config settings
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout:
          const Duration(seconds: 10), // shorter timeout for better UX
      minimumFetchInterval: Duration.zero, // allow frequent updates for testing
    ));

    // Fetch and activate the latest values from the server
    // We add a timeout to ensure the popup shows even if the network is slow
    await remoteConfig.fetchAndActivate().timeout(const Duration(seconds: 5),
        onTimeout: () {
      debugPrint("[HOME] RemoteConfig fetch timed out, using defaults.");
      /*
      Set messageID to default control setting. Doing this so we can tell Firebase
      that the user has already seen this message so they are not shown it again.
       */
      String messageID = "none";
      return false;
    });
  } catch (e) {
    debugPrint("[HOME] Error with Remote Config: $e");
  }

  final String surveyType = remoteConfig.getString('survey');
  return surveyType;
}
