import 'package:flutter/material.dart';
//these will likely be used in the future when implementing real data
//to dashboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:internet_measurement_games_app/dashboard_pages/game_stats.dart';
import 'package:internet_measurement_games_app/dashboard_pages/leaderboard.dart';
import 'package:internet_measurement_games_app/dashboard_pages/radius_gyration.dart';
import 'package:internet_measurement_games_app/dashboard_pages/total_data_points.dart';
import 'package:internet_measurement_games_app/dashboard_pages/total_distance.dart';

//this list defines all the different panels in the dashboard
// new panels can be added by adding a new "map" to this list
final List<Map<String, dynamic>> panelData = [
  {
    'title': 'Total Distance Traveled',
    'icon': Icons.directions_walk,
    'color': Colors.red,
    'message': 'Total Distance Traveled During Session',
    'navigation': TotalDistance()
  },
  {
    'title': 'Total Data Points Collected',
    'icon': Icons.scatter_plot,
    'color': Colors.green,
    'message': 'Total Data Points Collected During Session',
    'navigation': TotalDataPoints()
  },
  {
    'title': 'Radius of Gyration',
    'icon': Icons.radar,
    'color': Colors.blue,
    'message': 'Radius of Gyration During Session',
    'navigation': RadiusGyration()
  },
  {
    'title': 'Most Played Game in Area',
    'icon': Icons.gamepad,
    'color': Colors.orange,
    'message': 'Most Played Game in Area',
    'navigation': GameStats()
  },
  {
    'title': 'Leaderboard',
    'icon': Icons.emoji_events,
    'color': Colors.purple,
    'message': 'Leaderboard for Data Points Collected in Area',
    'navigation': Leaderboard()
  },
];

class DataDashboard extends StatefulWidget {
  const DataDashboard({Key? key}) : super(key: key);

  @override
  DataDashboardState createState() => DataDashboardState();
}

class DataDashboardState extends State<DataDashboard> {
  late Future<List<Map<String, dynamic>>> _userDataFuture;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mobility Data Dashboard',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: CircleAvatar(
              backgroundColor: Colors.black,
              radius: 20,
              child: Icon(
                Icons.person,
                color: Colors.white,
              ),
            ),
          ),
        ],
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: Container(
        color: Colors.white,
        child: grid,
      ),
    );
  }

  //makes up grid of panels and stylization
  get grid => Container(
    padding: const EdgeInsets.all(20),
    child: GridView.count(
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      crossAxisCount: 2,
      childAspectRatio: .90,
      children: List.generate(panelData.length, (index) {
        final data = panelData[index];
        //pop up when panel is clicked
        return InkWell(
          onTap: () {
            // Navigate to the page specified in the navigation field
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => data['navigation'],
              ),
            );
          },
          //continued box style
          borderRadius: BorderRadius.circular(12),
          child: Card(
            elevation: 4,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(data['icon'], color: data['color'], size: 40),
                  const SizedBox(height: 8),
                  Text(
                    data['title'],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: data['color'],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    ),
  );
}