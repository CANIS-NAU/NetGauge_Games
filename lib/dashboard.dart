import 'package:flutter/material.dart';
//these will likely be used in the future when implementing real data
//to dashboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile.dart';
import 'user_data_manager.dart';
import 'game_catalog.dart';
import 'widgets/buttons.dart';

class PlayerStatistics extends StatelessWidget {
  const PlayerStatistics({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
              'Player Statistics',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 25)
          ),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
      body:
        const ExpansionListStatistics(),
    );
  }
}

// stores ExpansionPanel state information
class SessionItem {
  SessionItem({
    required this.expandedValue,
    required this.headerValue,
    this.isExpanded = false,
  });

  String expandedValue;
  String headerValue;
  bool isExpanded;
}

List<SessionItem> generateItems(int numberOfItems) {
  return List<SessionItem>.generate(numberOfItems, (int index) {
    return SessionItem(
      headerValue: 'Session $index',
      expandedValue: 'Placeholder data.',
    );
  });
}

class ExpansionListStatistics extends StatefulWidget {
  const ExpansionListStatistics({super.key});

  @override
  State<ExpansionListStatistics> createState() =>
      _ExpansionListStatisticsState();
}

class _ExpansionListStatisticsState extends State<ExpansionListStatistics> {
  //TODO: This should not be hard-coded, update later with session count from manager.
  final List<SessionItem> _data = generateItems(8);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(child: Container(child: _buildPanel()));
  }

  Widget _buildPanel() {
    return ExpansionPanelList(
      expansionCallback: (int index, bool isExpanded) {
        setState(() {
          _data[index].isExpanded = isExpanded;
        });
      },
      children: _data.map<ExpansionPanel>((SessionItem item) {
        return ExpansionPanel(
          headerBuilder: (BuildContext context, bool isExpanded) {
            return ListTile(title: Text(item.headerValue));
          },
          body: ListTile(
            title: Text(item.expandedValue),
          ),
          isExpanded: item.isExpanded,
        );
      }).toList(),
    );
  }
}

//this list defines all the different panels in the dashboard
// new panels can be added by adding a new "map" to this list
/*final List<Map<String, dynamic>> panelData = [
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
            color: Colors.white
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: CircleAvatar(
              backgroundColor: Colors.black,
              radius: 20,
              child: IconButton(
                icon: Icon(Icons.person),
                color: Colors.white,
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfilePage())
                  );
                },
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
  }*/

