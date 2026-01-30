import 'package:flutter/material.dart';
import 'package:internet_measurement_games_app/location_service.dart';
import 'package:internet_measurement_games_app/session_manager.dart';
import 'likert_form.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ndt7_service.dart';
import 'dart:convert';
import 'dart:io';
import 'poi_generator.dart';
import 'homepage.dart';

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
  String errorLog = '';
  String detailedLog = '';

  // ADD THIS METHOD HERE
  @override
  void initState() {
    super.initState();
    // Test basic WebSocket connectivity on startup
    _testBasicWebSocketConnection();
  }

  // Add this test method
  Future<void> _testBasicWebSocketConnection() async {
    try {
      debugPrint('[TEST] Testing basic WebSocket connection...');

      final testSocket = await WebSocket.connect(
        'wss://echo.websocket.org',
      );

      debugPrint('[TEST] ✅ WebSocket connected successfully!');

      testSocket.listen(
            (message) {
          debugPrint('[TEST] Received: $message');
        },
        onDone: () {
          debugPrint('[TEST] Connection closed');
        },
        onError: (error) {
          debugPrint('[TEST] Error: $error');
        },
      );

      testSocket.add('Hello from Flutter!');

      await Future.delayed(const Duration(seconds: 2));
      testSocket.close();

    } catch (e, stack) {
      debugPrint('[TEST] ❌ WebSocket connection failed!');
      debugPrint('[TEST] Error: $e');
      debugPrint('[TEST] Stack: $stack');

      // Optionally show error to user
      setState(() {
        errorLog = 'WebSocket test failed: $e\n\nThis may indicate a network permission issue.';
      });
    }
  }

  void _runSpeedTest() async {
    setState(() {
      downloadSpeed = 'Testing...';
      uploadSpeed = 'Testing...';
      latency = 'Testing...';
      detailedLog = 'Step 1: Initializing...\n';
      errorLog = '';
    });
    // write data to firestore
    final loc = await determineLocationData();
    //final nickname = SessionManager.playerName;
    final sessionId = SessionManager.sessionId;

    try {
      final service = NDT7Service();

      setState(() {
        detailedLog += 'Step 2: Starting download test...\n';
      });

      // Call the download test with callback
      final download = await service.runDownloadTest((status) {
        setState(() {
          detailedLog += status + '\n';
        });
      });

      setState(() {
        detailedLog += '\n✅ Download complete!\n';
        detailedLog += 'Speed: ${download['speedMbps']?.toStringAsFixed(2)} Mbps\n';
        detailedLog += 'Bytes: ${download['bytesReceived']}\n';
        detailedLog += 'Duration: ${download['duration']?.toStringAsFixed(2)} sec\n';
        detailedLog += 'Messages: ${download['messageCount']}\n\n';
        detailedLog += 'Raw bytes received: ${download['bytesReceived']}\n';  // ADD THIS
        detailedLog += 'Raw duration: ${download['duration']} sec\n';  // ADD THIS

        downloadSpeed = '${download['speedMbps']?.toStringAsFixed(2) ?? '0.00'} Mbps';
        latency = '${download['latency']?.toStringAsFixed(2) ?? '0.00'} ms';
      });

      setState(() {
        detailedLog += 'Step 3: Starting upload test...\n';
      });

      // Call the upload test with callback
      final upload = await service.runUploadTest((status) {
        setState(() {
          detailedLog += status + '\n';
        });
      });

      setState(() {
        detailedLog += '\n✅ Upload complete!\n';
        detailedLog += 'Speed: ${upload['speedMbps']?.toStringAsFixed(2)} Mbps\n';
        detailedLog += 'Bytes: ${upload['bytesSent']}\n';
        detailedLog += 'Duration: ${upload['duration']?.toStringAsFixed(2)} sec\n';
        detailedLog += 'Chunks: ${upload['chunksSent']}\n\n';

        uploadSpeed = '${upload['speedMbps']?.toStringAsFixed(2) ?? '0.00'} Mbps';

        detailedLog += '✅ ALL TESTS COMPLETE!\n';
      });

      // Save to Firestore
      setState(() {
        detailedLog += 'Step 4: Saving to Firestore...\n';
      });

      final loc = await determineLocationData();
      final sessionId = SessionManager.sessionId;

      final checkData = {
        'game': 'Speedtest',
        'latitude': loc.position.latitude,
        'longitude': loc.position.longitude,
        'sessionID': sessionId,
        'downloadSpeed': download['speedMbps'],
        'uploadSpeed': upload['speedMbps'],
        'latency': download['latency'],
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('Movement Data')
          .doc(sessionId)
          .collection('CheckData')
          .add(checkData);

      setState(() {
        detailedLog += '✅ Data saved to Firestore!\n';
        jitter = '-1';
        packetLoss = '-1';
      });

      debugPrint('[SPEED_TEST] Test completed successfully');

    } catch (e, stackTrace) {
      debugPrint('[SPEED_TEST] Error: $e');
      debugPrint('[SPEED_TEST] Stack: $stackTrace');

      setState(() {
        downloadSpeed = 'Failed';
        uploadSpeed = 'Failed';
        latency = 'Failed';
        errorLog = '❌ ERROR:\n${e.toString()}\n\nStack trace:\n${stackTrace.toString()}';
        detailedLog += '\n❌ TEST FAILED: $e\n';
      });
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
          if (errorLog.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  errorLog,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                ),
              ),
            ),
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