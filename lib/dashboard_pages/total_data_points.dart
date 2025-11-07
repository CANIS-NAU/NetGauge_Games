import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../user_data_manager.dart';

class TotalDataPoints extends StatefulWidget {
  const TotalDataPoints({Key? key}) : super(key: key);

  @override
  State<TotalDataPoints> createState() => _TotalDataPointsState();
}

class _TotalDataPointsState extends State<TotalDataPoints> {

  @override
  Widget build(BuildContext context) {
    final userDataProvider = Provider.of<UserDataProvider>(context);
    print("User ID Found: ${userDataProvider.uid}");
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Total Data Points Collected',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green,
      ),
      body:
        Text(
          'Total points collected: ${userDataProvider.measurementsTaken}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
            letterSpacing: 1.5,
          ),
        )
    );
  }
}