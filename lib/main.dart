import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'homepage.dart'; // Your existing homepage
import 'screens/auth/auth_wrapper.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';

// app initialization
void main() async {
  debugPrint('[MAIN] Main app is starting...');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[MAIN] Waiting for firebase connection to initialize...');
  await Firebase.initializeApp();
  debugPrint('[MAIN] Running app...');
  runApp(const MyApp());
}

// build the home page
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomePage',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const HomePage(), // Your existing homepage
      },
    );
  }
}