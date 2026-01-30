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
      body: SingleChildScrollView( // Allows scrolling if list is long
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total points collected: ${userDataProvider.measurementsTaken}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 20), // Spacing
            const Text(
              'Data Points',
              style: TextStyle(
                fontSize: 20,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            // Display each data point
            ...userDataProvider.dataPoints.map((point) =>
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    '(${point.latitude}, ${point.longitude})', // Convert to string for display
                    style: TextStyle(fontSize: 16),
                  ),
                )
            ).toList(),
          ],
        ),
      ),
    );
    }
  }