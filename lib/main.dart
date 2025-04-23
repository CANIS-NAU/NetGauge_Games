import 'package:flutter/material.dart';
import 'homepage.dart';

// void main() {
//   runApp(const MyApp());
// }

// testing button for now
void main() {
  runApp(MaterialApp(home: MsakTestPage()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Tiles Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}