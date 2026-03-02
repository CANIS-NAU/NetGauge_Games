import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'homepage.dart';
import 'home.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;
import 'firebase_options.dart';
import 'login_page.dart';
import 'profile.dart';
import 'user_data_manager.dart';
import 'package:provider/provider.dart';
import 'activity_logs.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart'; // for Hive.initFlutter()
import 'package:get_it/get_it.dart';

// app initialization
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final getIt = GetIt.instance;
  final loggingService = LoggingService();
  await loggingService.init();
  getIt.registerSingleton<LoggingService>(loggingService);

  runApp(
    ChangeNotifierProvider(
      create: (context) => UserDataProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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