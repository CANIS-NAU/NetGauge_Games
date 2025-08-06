import 'package:flutter/material.dart';
//these will likely be used in the future when implementing real data
//to dashboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_manager.dart';

//this list defines all the different panels in the dashboard
// new panels can be added by adding a new "map" to this list
final List<Map<String, dynamic>> panelData = [
  {
    'title': 'Total Distance Traveled',
    'icon': Icons.directions_walk,
    'color': Colors.red,
    'message': 'Total Distance Traveled During Session'
  },
  {
    'title': 'Total Data Points Collected',
    'icon': Icons.scatter_plot,
    'color': Colors.green,
    'message': 'Total Data Points Collected During Session'
  },
  {
    'title': 'Radius of Gyration',
    'icon': Icons.radar,
    'color': Colors.blue,
    'message': 'Radius of Gyration During Session'
  },
  {
    'title': 'Most Played Game in Area',
    'icon': Icons.gamepad,
    'color': Colors.orange,
    'message': 'Most Played Game in Area'
  },
  {
    'title': 'Leaderboard',
    'icon': Icons.emoji_events,
    'color': Colors.purple,
    'message': 'Leaderboard for Data Points Collected in Area'
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
      body: Stack(
        children: <Widget>[dashBackground, content],
      ),
    );
  }

  //makes the background of the dashboard match the app theme
  get dashBackground => Column(
        children: <Widget>[
          Expanded(
            child: Container(
                color: Theme.of(context)
                    .primaryColor), //adds matching purple theme
            flex: 2,
          ),
          Expanded(
            child: Container(color: Colors.white),
            flex: 5,
          ),
        ],
      );

  //sets header and grid onto the dashboard to seperate the header from the grid
  get content => Container(
        child: Column(
          children: <Widget>[
            header,
            grid,
          ],
        ),
      );
//stylizing the header of the dashboard
//this is the top part of the dashboard that has the title and user ico
  get header => const ListTile(
        contentPadding: EdgeInsets.only(left: 20, right: 20, top: 20),
        title: Text(
          'Mobility Data Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Roboto',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: CircleAvatar(
          backgroundColor: Colors.black,
          radius: 20,
          child: Icon(
            Icons.person,
            color: Colors.white,
          ),
        ),
      );

  //makes up grib of panels and stylization
  get grid => Expanded(
        child: Container(
          //box style
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 14),
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
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text(data['message']),
                        content: Text('Feature coming soon!'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      );
                    },
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
        ),
      );
}
