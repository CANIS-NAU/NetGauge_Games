import 'package:flutter/material.dart';


class TotalDistance extends StatefulWidget {
  const TotalDistance({Key? key}) : super(key: key);

  @override
  State<TotalDistance> createState() => _TotalDistanceState();
}

class _TotalDistanceState extends State<TotalDistance> {



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Total Distance Traveled',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

}