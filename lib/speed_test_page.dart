import 'package:flutter/material.dart';
import 'package:internet_measurement_games_app/location_service.dart';
import 'package:internet_measurement_games_app/session_manager.dart';
import 'likert_form.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ndt7_service.dart';
import 'dart:convert';

class SpeedTestPage extends StatefulWidget{
  const SpeedTestPage({Key? key}) : super(key: key);

  @override
  SpeedTestPageState createState() => SpeedTestPageState();
}

class SpeedTestPageState extends State<SpeedTestPage> {
  String downloadSpeed = '---';
  String uploadSpeed = '---';
  String latency = '---';
  String jitter = '---';
  String packetLoss = '---';

  void _runSpeedTest() async {

    final results = await NDT7Service().runFullTest();

    // set state with actual metrics
    setState(() {
      downloadSpeed = '${results['downloadSpeed']?.toStringAsFixed(2) ?? '0.00'} Mbps';
      uploadSpeed = '${results['uploadSpeed']?.toStringAsFixed(2) ?? '0.00'} Mbps';
      latency = '${results['latency']?.toStringAsFixed(2) ?? '0.00'} ms';
      jitter = '${results['jitter']}';
      packetLoss = '${results['packetLoss']}';
    });
    // write data to firestore
    final loc = await determineLocationData();
    final nickname = SessionManager.playerName;
    final sessionId = SessionManager.sessionId;

    final checkData = {
        'game': 'Speedtest',
        'latitude': loc.position.latitude,
        'longitude': loc.position.longitude,
        'nickname': nickname,
        'sessionID': sessionId
      };

      try {
        await FirebaseFirestore.instance
          .collection('Movement Data')
          .doc(sessionId)
          .collection('CheckData')
          .add(checkData);
        debugPrint('[SPEED_TEST] Check data added to Firestore.');
      } catch(e) {
        debugPrint('[SPEED_TEST] Error adding Check data to Firestore: $e');
      }
  }

  // constructor for UI elements
  Widget _buildMetricsCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: ListTile(
        title: Text(label),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // overall page constructor
  @override
  Widget build(BuildContext context) {
    SessionManager.startGame('Speed Tester');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Internet Speed Test'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          _buildMetricsCard('Download Speed', downloadSpeed),
          _buildMetricsCard('Upload Speed', uploadSpeed),
          _buildMetricsCard('Latency', latency),
          _buildMetricsCard('Jitter', jitter),
          _buildMetricsCard('Packet Loss', packetLoss),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _runSpeedTest,
            child: const Text('Run Test'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}