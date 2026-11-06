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
import 'app_theme.dart';
import 'theme_controller.dart';
import 'daily_reminder_service.dart';

// app initialization
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await RemoteConfigService().initialize();

  final getIt = GetIt.instance;
  final loggingService = LoggingService();
  await loggingService.init();
  getIt.registerSingleton<LoggingService>(loggingService);

  final notificationSettings = await FirebaseMessaging.instance.requestPermission(provisional: true);
  final apnsToken = await FirebaseMessaging.instance.getAPNSToken();

  await DailyReminderService.init();

  // the saved light/dark choice (Hive was initialized by the logging service above)
  final themeController = await ThemeController.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserDataProvider()),
        ChangeNotifierProvider.value(value: themeController),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: context.watch<ThemeController>().mode,
      // Newer Android versions draw apps edge to edge, so the system navigation bar (gesture area or the
      // home/back buttons) would cover the bottom of every screen, including the maps. Keeping every
      // screen clear of it here fixes that in one place; the top is left to each screen's AppBar.
      builder: (context, child) => ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          top: false,
          left: false,
          right: false,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
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
              DailyReminderService.scheduleIfEnabled();
            });
            return const HomePage();
          }

          // User is logged out - clear provider data
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<UserDataProvider>(context, listen: false)
                .clearData();
            DailyReminderService.cancel();
          });

          return const LoginPage();
        },
      ),
    );
  }

}