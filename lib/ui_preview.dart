import 'package:flutter/material.dart';
import 'game_catalog.dart'; // Replace with your actual page file
import 'home.dart';

void main() {
  runApp(const PreviewApp());
}

class PreviewApp extends StatelessWidget {
  const PreviewApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: gameCatalog(context), // Replace with your actual page widget
    );
  }
}