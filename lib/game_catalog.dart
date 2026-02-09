/* Since the current homepage has a lot of background tasks (which I plan to
* move to other files), I am just going to set up the UI here.*/

// import needed files and libraries
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'widgets/buttons.dart';
import 'homepage.dart';
import 'session_manager.dart';
import 'location_logger.dart';
import 'vibration_controller.dart';

class GameData {
  final String text;
  final IconData? icon;
  final String? imagePath;

  GameData({required this.text, this.icon, this.imagePath});
}

@Preview()
Widget gameCatalog() {
  // Store your button data in a list
  final List<GameData> games = [
    GameData(text: "Space Explorers", icon: Icons.settings),
    GameData(text: "Scavenger Hunt", icon: Icons.location_pin),
    GameData(text: "Zombie Apocalypse", imagePath: 'assets/icons/zombie_outline.png'),
    GameData(text: "Soul Seeker", imagePath: 'assets/icons/soul_icon.png'),
    GameData(text: "Dragon Slayer", imagePath: 'assets/icons/dragon_outline.png'),
  ];

  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Game Catalog'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 50 / 40,
          ),
          itemCount: games.length,
          itemBuilder: (context, index) {
            return AppButtons(
              textColor: Colors.black,
              backgroundColor: Colors.white,
              borderColor: Colors.black,
              text: games[index].text,
              icon: games[index].icon,
              imagePath: games[index].imagePath,
              isIcon: true,
              iconSize: 60,
              buttonHeight: 45,
              buttonLength: 45,
              onTap: () => _showCustomPopup(context, games[index].text),
            );
          },
        ),
      ),
    ),
  );
}

void _showCustomPopup(BuildContext context, String game) {
  String title = "Title";
  String content = "Content";
  String gameURL = "URL";
  if(game == "Zombie Apocalypse") {
    title = "Zombie Apocalypse";
    content = "A pandemic is wreaking havoc on the world, turning everyone into zombies!"
        "\n will you be a doctor, racing to find the cure, or a zombie, converting everyone you can?";
    gameURL = 'ZombieApocalypse.html';
  }
  if(game == "Soul Seeker") {
    title = "Soul Seeker";
    content = "Your soul has been shattered, and you must search for the fragments before it's too late!";
    gameURL = 'SoulSeeker.html';
  }
  if(game == "Dragon Slayer") {
    title = "Dragon Slayer";
    content = "Can you defeat the evil dragon?";
    gameURL = 'DragonSlayer.html';
  }
  if(game == "Scavenger Hunt") {
    title = "Scavenger Hunt";
    content = "Look for points of interest in your area!";
    gameURL = 'ScavengerHunt.html';
  }
  if(game == "Space Explorers") {
    title = "Space Explorers";
    content = "Coming soon!";
    gameURL = '';
  }
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => _launchGame(title, gameURL, context),
            child: Text("Play"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      );
    },
  );
}

void _launchGame(String title, String gameFile, BuildContext context) {
  // Close the dialog first
  Navigator.pop(context);

  // log the game start with the session manager
  SessionManager.startGame(title);
  // begin location logging
  LocationLogger.start();

  // navigate to the WebViewPage
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => WebViewPage(title: title, gameFile: gameFile),
    ),
  ).then((_) async {
    // log the game end with the session manager
    SessionManager.endGame(); // also will stop logging location
    // Stop the vibration service, in case the game started it
    VibrationController.stop();

    // TODO: Navigate to home page
    /*Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => home(gameTitle: title),
      ),
    );*/
  });
}