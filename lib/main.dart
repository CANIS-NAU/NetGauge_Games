import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'flutter_bridge.dart';
import 'home.dart';
import 'login_page.dart';
import 'user_data_manager.dart';
import 'package:provider/provider.dart';
import 'activity_logs.dart';
// for Hive.initFlutter()
import 'package:get_it/get_it.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'remote_config_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// app initialization
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Don't let a Remote Config failure block startup
  try {
    await RemoteConfigService().initialize();
  } catch (e) {
    debugPrint('[REMOTE CONFIG] Failed to initialize, using defaults: $e');
  }

  final getIt = GetIt.instance;
  final loggingService = LoggingService();
  await loggingService.init();
  getIt.registerSingleton<LoggingService>(loggingService);

  final notificationSettings = await FirebaseMessaging.instance.requestPermission(provisional: true);
  final apnsToken = await FirebaseMessaging.instance.getAPNSToken();

  runApp(
    ChangeNotifierProvider(
      create: (context) => UserDataProvider(),
      child: MyApp(navigatorKey: navigatorKey),
    ),
  );
}

class MyApp extends StatelessWidget {

  final GlobalKey<NavigatorState> navigatorKey;
  const MyApp({super.key, required this.navigatorKey});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Check auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // User is logged in
          if (snapshot.hasData) {
            // Fetch user data when logged in
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Provider.of<UserDataProvider>(context, listen: false)
                  .fetchUserData();
            });
            return const HomePage();
          }

          // User is logged out - clear provider data
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<UserDataProvider>(context, listen: false)
                .clearData();
          });

          return const LoginPage();
        },
      ),
    );
  }

}