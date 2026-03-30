import 'package:flutter/material.dart';
//these will likely be used in the future when implementing real data
//to dashboard
import 'package:latlong2/latlong.dart';
import 'user_data_manager.dart';
import 'game_catalog.dart';
import 'package:provider/provider.dart';
import 'activity_logs.dart';
import 'package:get_it/get_it.dart';
import 'package:geolocator/geolocator.dart';

class PlayerStatistics extends StatelessWidget {
  const PlayerStatistics({super.key});

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    loggingService.logEvent('User is in player statistics page.', email: userData.email);
    
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

class ExpansionListStatistics extends StatefulWidget {
  const ExpansionListStatistics({super.key});

  @override
  State<ExpansionListStatistics> createState() =>
      _ExpansionListStatisticsState();
}

class _ExpansionListStatisticsState extends State<ExpansionListStatistics> {
  List<ExpandableSessionData> _data = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final measurements = Provider.of<UserDataProvider>(context).collectedMeasurements;
    debugPrint("Total collected measurements is ${measurements.length}");
    
    // Only update if the number of measurements has changed to avoid resetting expansion state
    if (_data.length != measurements.length) {
      setState(() {
        _data = measurements.map((dp) => ExpandableSessionData(
          date: dp.timestamp,
          game: dp.gamePlayed,
          averageDownloadSpeed: dp.downloadSpeed,
          averageUploadSpeed: dp.uploadSpeed,
          distanceTraveled: 0, // Placeholder
          pointsCollected: measurements.length,  // Placeholder
          radiusGyration: 0.0, // Placeholder
          sessionDataPoints: [dp.point],
        )).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data.isEmpty) {
      return const Center(child: Text("Looks like you haven't collected measurements yet. Go play some games to collect data!"));
    }
    return SingleChildScrollView(child: _buildPanel());
  }

  Widget _buildPanel() {
    final userData = Provider.of<UserDataProvider>(context, listen: false);

    return ExpansionPanelList(
      expansionCallback: (int index, bool isExpanded) {
        setState(() {
          loggingService.logEvent('Expanded data for session on: ${_data[index].date}', email: userData.email);
          _data[index].isExpanded = isExpanded;
        });
      },
      children: _data.map<ExpansionPanel>((ExpandableSessionData item) {
        return ExpansionPanel(
          headerBuilder: (BuildContext context, bool isExpanded) {
            return ListTile(
              title: Text('Game: ${item.game}'),
              subtitle: Text('Date: ${item.date.toIso8601String().substring(0, 10)}'),
            );
          },
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Download: ${item.averageDownloadSpeed?.toStringAsFixed(2)} Mbps'),
                Text('Upload: ${item.averageUploadSpeed?.toStringAsFixed(2)} Mbps'),
                // Only show these if they have data
                if (item.distanceTraveled != 0) Text('Distance Traveled: ${item.distanceTraveled} m'),
                Text('Session Points: ${item.pointsCollected}'),
              ],
            ),
          ),
          isExpanded: item.isExpanded,
        );
      }).toList(),
    );
  }
}
