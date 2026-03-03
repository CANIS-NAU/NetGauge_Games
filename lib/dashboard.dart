import 'package:flutter/material.dart';
//these will likely be used in the future when implementing real data
//to dashboard
import 'package:latlong2/latlong.dart';
import 'user_data_manager.dart';
import 'game_catalog.dart';
import 'package:provider/provider.dart';
import 'user_data_manager.dart';
import 'activity_logs.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

class PlayerStatistics extends StatelessWidget {
  const PlayerStatistics({super.key});

  @override
  Widget build(BuildContext context) {
    final favoriteGames = Provider.of<UserDataProvider>(context).favoriteGames;
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    loggingService.logEvent('User is in player statistics page.', phone: userData.phone);
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
            const Expanded(child: ExpansionListStatistics()),
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
    required super.averageDownloadSpeed,
    required super.averageUploadSpeed,
    required super.distanceTraveled,
    required super.pointsCollected,
    required super.radiusGyration,
    required super.sessionDataPoints,
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
      game: games[index % games.length].text, // Cycle through favorite games
      averageDownloadSpeed: 12.345,
      averageUploadSpeed: 6.789,
      distanceTraveled: 5,
      pointsCollected: 10,
      radiusGyration: 15.5,
      sessionDataPoints: [const LatLng(0.0, 0.0), const LatLng(0.0, 0.0), const LatLng(0.0, 0.0)],
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
    return SingleChildScrollView(child: _buildPanel());
  }

  Widget _buildPanel() {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    return ExpansionPanelList(
      expansionCallback: (int index, bool isExpanded) {
        setState(() {
          loggingService.logEvent('Expanded data for session on: ${_data[index].date}', phone: userData.phone);
          _data[index].isExpanded = isExpanded;
        });
      },
      children: _data.map<ExpansionPanel>((ExpandableSessionData item) {
        return ExpansionPanel(
          headerBuilder: (BuildContext context, bool isExpanded) {
            return ListTile(
              title: Text(item.game),
              subtitle: Text('Date: ${item.date.toIso8601String().substring(0, 10)}'),
            );
          },
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Average Download: ${item.averageDownloadSpeed} Mbps'),
                Text('Average Upload: ${item.averageUploadSpeed} Mbps'),
                Text('Distance Traveled: ${item.distanceTraveled} m'),
                Text('Points Collected: ${item.pointsCollected}'),
                Text('Radius of Gyration: ${item.radiusGyration}'),
              ],
            ),
          ),
          isExpanded: item.isExpanded,
        );
      }).toList(),
    );
  }
}
