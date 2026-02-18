import 'package:flutter/material.dart';
//these will likely be used in the future when implementing real data
//to dashboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile.dart';
import 'user_data_manager.dart';
import 'game_catalog.dart';
import 'widgets/buttons.dart';
import 'user_data_manager.dart';
import 'package:provider/provider.dart';

class PlayerStatistics extends StatelessWidget {
  const PlayerStatistics({super.key});

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context);
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
            const Text('Session Data',
              style:
               TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const ExpansionListStatistics(),
        ],
      )
    );
  }
}

// A new class that extends SessionData to include UI state for the panel.
class ExpandableSessionData extends SessionData {
  bool isExpanded;

  ExpandableSessionData({
    required super.date,
    required super.game,
    this.isExpanded = false,
  });
}

/*
TODO: This function is just to populate with dummy data. It will need to be replaced
by a function pulling real data to populate in player statistics.
 */
List<ExpandableSessionData> generateItems(int numberOfItems) {
  return List<ExpandableSessionData>.generate(numberOfItems, (int index) {
    return ExpandableSessionData(
      date: DateTime.now().subtract(Duration(days: index)), // Use DateTime.now()
      game: favorite_games[index % favorite_games.length], // Cycle through favorite games
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
  // The list now correctly holds the expandable data objects.
  final List<ExpandableSessionData> _data = generateItems(8);

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
      children: _data.map<ExpansionPanel>((ExpandableSessionData item) {
        return ExpansionPanel(
          headerBuilder: (BuildContext context, bool isExpanded) {
            return ListTile(title: Text(item.date.toString()));
          },
          body: ListTile(
            title: Text(item.game.text), // Correctly display the game's text property.
          ),
          isExpanded: item.isExpanded,
        );
      }).toList(),
    );
  }
}
