import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../user_data_manager.dart';
import 'package:geolocator/geolocator.dart';


class TotalDistance extends StatefulWidget {
  const TotalDistance({Key? key}) : super(key: key);

  @override
  State<TotalDistance> createState() => _TotalDistanceState();
}

class _TotalDistanceState extends State<TotalDistance> {


  @override
  Widget build(BuildContext context) {
    final userDataProvider = Provider.of<UserDataProvider>(context);
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
      body: const SingleChildScrollView( // Allows scrolling if list is long
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total distance traveled: TBD',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 20), // Spacing
            Text(
              'Distances per Session: TBD',
              style: TextStyle(
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

}