// This page will contain community statistics data

// Import libraries, packages, and pages
import 'package:flutter/material.dart';
//these will likely be used in the future when implementing real data
//to dashboard
import 'user_data_manager.dart';
import 'package:provider/provider.dart';

// Declare class
class CommunityStatistics extends StatelessWidget {
  const CommunityStatistics({super.key});

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context);
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
              'CommunityStatistics',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 25)
          ),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children:[
            const Text('All-Time Statistics',
              style:
              TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              width: double.infinity,
              color: Colors.white,
              child:
              Text(
                  'Total Points Collected: ${userData.measurementsTaken} \n'
                      'Total Distance Traveled: ${userData.distanceTraveled} \n'
                      'Total Radius of Gyration: ${userData.totalRadiusGyration}',
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      fontSize: 20)
              ),
            ),
            const SizedBox(height: 16),
            const Text('Records',
              style:
              TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        )
    );
  }
}