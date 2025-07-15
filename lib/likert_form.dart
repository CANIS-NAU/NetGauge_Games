import 'package:flutter/material.dart';
import 'session_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mapping.dart';
import 'location_service.dart';
import 'package:latlong2/latlong.dart';
//import 'homepage.dart';

class LikertForm extends StatefulWidget {
  final String gameTitle;
  
  const LikertForm({Key? key, required this.gameTitle}) : super(key: key);

  @override
  State<LikertForm> createState() => _LikertFormState();
}

class _LikertFormState extends State<LikertForm> {
  int? envConnection;
  int? playerConnection;
  String resultText = '';

  void _submitForm() async {
    if(envConnection != null && playerConnection != null){
      setState(() {
        resultText = 
          'Thank you for your feedback! Opening map with your data...\n'
          'You rated your connection to the environment as: $envConnection.\n'
          'You rated your connection to your fellow players as: $playerConnection.\n';
      });
      // write data to firestore
      
      final sessionId = SessionManager.sessionId;
      final nickname = SessionManager.playerName;

      final likertData = {
        'game': widget.gameTitle,
        'envconnection': envConnection,
        'plrconnection': playerConnection,
        'nickname': nickname,
        'sessionID': sessionId
      };

      try {
        await FirebaseFirestore.instance
          .collection('Movement Data')
          .doc(sessionId)
          .collection('LikertData')
          .add(likertData);
        debugPrint('[LIKERT_FORM] Likert data added to Firestore.');
        
        // After successful submission, navigate to map
        _openMapWithSessionData();
        
      } catch(e) {
        debugPrint('[LIKERT_FORM] Error adding Likert data to Firestore: $e');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer both questions before submitting.')),
      );
    }
  }

  Future<void> _openMapWithSessionData() async {
    try {
      // Get location data for the current session
      final sessionLocationData = await _getSessionLocationData();
      
      // Get current location for map center
      final loc = await determineLocationData();
      
      // Use session data if available, otherwise fall back to static data
      final mapData = sessionLocationData.isNotEmpty ? sessionLocationData : heatmapData;
      
      // Navigate to map page
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => MapPage(
            data: mapData,
            gradients: gradients,
            index: 0,
            rebuildStream: Stream<void>.empty(),
            center: LatLng(loc.position.latitude, loc.position.longitude),
          ),
        ),
        (route) => route.isFirst, // Keep only the home page in the stack
      );
    } catch (e) {
      debugPrint('[LIKERT_FORM] Error opening map: $e');
      // Fallback - just go back to previous screen
      Navigator.pop(context);
    }
  }

  Future<List<TimedWeightedLatLng>> _getSessionLocationData() async {
    final sessionId = SessionManager.sessionId;
    if (sessionId == null) {
      debugPrint('[LIKERT_FORM] No session ID available for location data retrieval');
      return [];
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('Movement Data')
          .doc(sessionId)
          .collection('LocationData')
          .orderBy('datetime', descending: false)
          .get();

      List<TimedWeightedLatLng> locationData = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final latitude = data['latitude'] as double;
        final longitude = data['longitude'] as double;
        final datetime = DateTime.parse(data['datetime'] as String);
        
        locationData.add(TimedWeightedLatLng(
          LatLng(latitude, longitude),
          1.0, // intensity
          datetime,
        ));
      }

      debugPrint('[LIKERT_FORM] Retrieved ${locationData.length} location points');
      return locationData;
    } catch (e) {
      debugPrint('[LIKERT_FORM] Error retrieving location data: $e');
      return [];
    }
  }

  Widget _buildRadioGroup(String label, int? groupValue, ValueChanged<int?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List<Widget>.generate(5, (index) {
            int value = index + 1;
            return Row(
              children: [
                Radio<int>(value: value, groupValue: groupValue, onChanged: onChanged),
                Text('$value'),
              ],
            );
          }),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback Form')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRadioGroup(
              'How connected did you feel to the environment?',
              envConnection,
              (value) => setState(() => envConnection = value),
            ),
            const SizedBox(height: 16),
            _buildRadioGroup(
              'How connected did you feel to other players?',
              playerConnection,
              (value) => setState(() => playerConnection = value),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _submitForm, child: const Text('Submit')),
            const SizedBox(height: 16),
            Text(resultText),
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // Navigate back to homepage, removing all intermediate pages
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text('Return to Main Menu'),
              ),
            )
          ],
        ),
      ),
    );
  }
}