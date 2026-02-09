// New homepage, so I can easily refer to the original home page as needed
import 'package:flutter/material.dart';
import 'speed_test_page.dart';
import 'widgets/buttons.dart';
import 'game_catalog.dart';

class Utilities {
  final String text;
  final IconData? icon;
  final String? imagePath;

  Utilities({required this.text, this.icon, this.imagePath});
}

final List<Utilities> utilityButtons = [
  Utilities(text: "Internet Measurement", icon:Icons.wifi),
  Utilities(text: "Settings", icon:Icons.settings),
  Utilities(text: "Player Statistics", icon:Icons.auto_graph),
  Utilities(text: "Community Statistics", icon:Icons.group),
];

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('NetGauge Games'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                    'Welcome, user!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                    fontSize: 30)),
                const SizedBox(height: 300),
                // Utility buttons
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 15 / 20,
                  ),
                  itemCount: utilityButtons.length,
                  itemBuilder: (context, index) {
                    return AppButtons(
                      textColor: Colors.deepPurple,
                      backgroundColor: Colors.white,
                      borderColor: Colors.deepPurple,
                      text: utilityButtons[index].text,
                      icon: utilityButtons[index].icon,
                      imagePath: utilityButtons[index].imagePath,
                      isIcon: true,
                      iconSize: 25,
                      textSize: 12,
                      buttonHeight: 60,
                      buttonLength: 85,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SpeedTestPage()),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Game buttons
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 50 / 40,
                  ),
                  itemCount: favorite_games.length,
                  itemBuilder: (context, index) {
                    return AppButtons(
                      textColor: Colors.black,
                      backgroundColor: Colors.white,
                      borderColor: Colors.black,
                      text: favorite_games[index].text,
                      icon: favorite_games[index].icon,
                      imagePath: favorite_games[index].imagePath,
                      isIcon: true,
                      iconSize: 60,
                      buttonHeight: 45,
                      buttonLength: 45,
                      onTap: () => showCustomPopup(context, favorite_games[index].text),
                    );
                  },
                ),
              ]
            ),
        ),
        ),
      ),
    );
  }
}