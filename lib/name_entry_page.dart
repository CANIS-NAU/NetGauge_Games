import 'package:flutter/material.dart';
import 'session_manager.dart';
import 'speed_test_page.dart';
import 'location_logger.dart';

// name entry page that runs before the speed tester page

class NameEntry extends StatefulWidget {
  const NameEntry({Key? key}) : super(key: key);

  @override
  NameEntryState createState() => NameEntryState();
}

class NameEntryState extends State<NameEntry> {
  final TextEditingController _nameController = TextEditingController();

  void _submitName() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
     // SessionManager.setPlayerName(name);
      LocationLogger.start();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SpeedTestPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid nickname.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Experiment Nickname')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Enter your experiment nickname:',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'e.g. tester001',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitName,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
