import 'package:flutter/material.dart';
import 'session_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'homepage.dart';

class LikertForm extends StatefulWidget {
  const LikertForm({Key? key}) : super(key: key);

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
          'Thank you for your feedback! You may now return to the Main Menu.\n'
          'You rated your connection to the environment as: $envConnection.\n'
          'You rated your connection to your fellow players as: $playerConnection.\n';
      });
      // write data to firestore
      
      final sessionId = SessionManager.sessionId;
      final nickname = SessionManager.playerName;

      final likertData = {
        'game': 'Speedtester',
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
      } catch(e) {
        debugPrint('[LIKERT_FORM] Error adding Likert data to Firestore: $e');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer both questions before submitting.')),
      );
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
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const HomePage()),
                    (route) => false,
                  );
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