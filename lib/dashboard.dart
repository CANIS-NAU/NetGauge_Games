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
                  'Total Points Collected: ${userData.totalPointsCollected} \n'
                      'Total Distance Traveled: ${userData.totalDistanceTraveled.toStringAsFixed(2)} \n'
                      'Total Radius of Gyration: ${userData.totalRadiusGyration.toStringAsFixed(2)}',
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

class ExpandableSessionData extends SessionData {
  bool isExpanded;
  final String sessionId;

  ExpandableSessionData({
    required super.startTime,
    required super.endTime,
    required super.game,
    super.averageDownloadSpeed,
    super.averageUploadSpeed,
    super.distanceTraveled,
    super.pointsCollected,
    super.radiusGyration,
    super.sessionDataPoints,
    required this.sessionId,
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

    // Use the already-fetched session list — no need to re-group measurements
    final sessions = Provider.of<UserDataProvider>(context).collectedSessions;

    debugPrint("[DASHBOARD]: Total sessions found: ${sessions.length}");

    if (_data.length != sessions.length) {
      setState(() {
        _data = sessions.map((session) {
          return ExpandableSessionData(
            sessionId: session.game + session.startTime.toIso8601String(), // or a real ID if you add one
            startTime: session.startTime,
            endTime: session.endTime,
            game: session.game,
            averageDownloadSpeed: session.averageDownloadSpeed,
            averageUploadSpeed: session.averageUploadSpeed,
            distanceTraveled: session.distanceTraveled,
            pointsCollected: session.pointsCollected,
            radiusGyration: session.radiusGyration,
          );
        }).toList();

        _data.sort((a, b) => b.endTime.compareTo(a.endTime));
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
          loggingService.logEvent('Expanded data for session: ${_data[index].sessionId}', email: userData.email);
          _data[index].isExpanded = isExpanded;
        });
      },
      children: _data.map<ExpansionPanel>((ExpandableSessionData item) {
        return ExpansionPanel(
          headerBuilder: (BuildContext context, bool isExpanded) {
            return ListTile(
              title: Text('Game: ${item.game}'),
              subtitle: Text('Date: ${item.endTime.toIso8601String().substring(0, 10)}\n'
                  'Measurements collected: ${item.pointsCollected} '),
            );
          },
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Average Download: ${item.averageDownloadSpeed?.toStringAsFixed(2)} Mbps'),
                Text('Average Upload: ${item.averageUploadSpeed?.toStringAsFixed(2)} Mbps'),
              ],
            ),
          ),
          isExpanded: item.isExpanded,
        );
      }).toList(),
    );
  }
}
