import 'package:flutter/material.dart';
// Replace with your actual page file

void main() {
  runApp(const PreviewApp());
}

class PreviewApp extends StatelessWidget {
  const PreviewApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      //home: METUX(), // Replace with your actual page widget
    );
  }
}
