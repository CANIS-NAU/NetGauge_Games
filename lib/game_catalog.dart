/* Since the current homepage has a lot of background tasks (which I plan to
* move to other files), I am just going to set up the UI here.*/

// import needed files and libraries
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:internet_measurement_games_app/speed_test_page.dart';
import 'widgets/buttons.dart';
import 'homepage.dart';
import 'session_manager.dart';
import 'location_logger.dart';
import 'vibration_controller.dart';
import 'user_data_manager.dart';
import 'activity_logs.dart';
import 'package:get_it/get_it.dart';
import 'user_data_manager.dart';
import 'activity_logs.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

final loggingService = GetIt.instance<LoggingService>();

class GameData {
  final String text;
  final IconData? icon;
  final String? imagePath;

  GameData({required this.text, this.icon, this.imagePath});
}

class GameCatalog extends StatelessWidget {
  const GameCatalog({super.key});

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    loggingService.logEvent('User is in game catalog page', phone: userData.phone);
    // Store your button data in a list
    final List<GameData> games = [
      GameData(text: "Measure Internet", icon: Icons.wifi),
      GameData(text: "Space Explorers", icon: Icons.settings),
      GameData(text: "Scavenger Hunt", icon: Icons.location_pin),
      GameData(text: "Zombie Apocalypse", imagePath: 'assets/icons/zombie_outline.png'),
      GameData(text: "Soul Seeker", imagePath: 'assets/icons/soul_icon.png'),
      GameData(text: "Dragon Slayer", imagePath: 'assets/icons/dragon_outline.png'),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
            'Game Catalog',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 25)
        ),
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
              onTap: () => showCustomPopup(context, games[index]),
            );
          },
        ),
      ),
    );
  }
}

@Preview()
Widget gameCatalogPreview() {
  return const MaterialApp(
    home: GameCatalog(),
  );
}

Future<void> showCustomPopup(BuildContext context, GameData game) {
  final userData = Provider.of<UserDataProvider>(context, listen: false);
  loggingService.logEvent('Showing pop-up for ${game.text}', phone: userData.phone);
  String title = "Title";
  String content = "Content";
  String gameURL = "URL";
  String? imagePath;

  if (game.text == "Zombie Apocalypse") {
    title = "Zombie Apocalypse";
    content = "A pandemic is wreaking havoc on the world, turning everyone into zombies!"
        "\n will you be a doctor, racing to find the cure, or a zombie, converting everyone you can?";
    gameURL = 'ZombieApocalypse.html';
    imagePath = game.imagePath;
  }
  if (game.text == "Soul Seeker") {
    title = "Soul Seeker";
    content = "Your soul has been shattered, and you must search for the fragments before it's too late!";
    gameURL = 'SoulSeeker.html';
    imagePath = game.imagePath;
  }
  if (game.text == "Dragon Slayer") {
    title = "Dragon Slayer";
    content = "Can you defeat the evil dragon?";
    gameURL = 'DragonSlayer.html';
    imagePath = game.imagePath;
  }
  if (game.text == "Scavenger Hunt") {
    title = "Scavenger Hunt";
    content = "Look for points of interest in your area!";
    gameURL = 'ScavengerHunt.html';
    imagePath = game.imagePath;
  }
  if (game.text == "Space Explorers") {
    title = "Space Explorers";
    content = "Coming soon!";
    gameURL = '';
    imagePath = game.imagePath;
  }
  if (game.text == "Measure Internet") {
    title = "Measure Internet";
    content = "Measure your connectivity!";
    imagePath = game.imagePath;
  }


  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imagePath != null) ...[
                  Image.asset(imagePath, height: 100, width: 100),
                  const SizedBox(height: 16),
                ],
                Text(content),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  favorite_games.any((favGame) => favGame.text == game.text)
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                onPressed: () {
                  updateFavorites(game, context);
                  dialogSetState(() {});
                },
              ),
              TextButton(
                onPressed: () => _launchGame(title, gameURL, context),
                child: const Text("Play"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          );
        },
      );
    },
  );
}

void _launchGame(String title, String gameFile, BuildContext context) {
  final userData = Provider.of<UserDataProvider>(context, listen: false);
  loggingService.logEvent('Launching $title', phone: userData.phone);

  // Close the dialog first
  Navigator.pop(context);

  // log the game start with the session manager
  SessionManager.startGame(title);
  // begin location logging
  LocationLogger.start();

  if(title == 'Measure Internet') {
    loggingService.logEvent('Clicked measure internet.', phone: userData.phone);
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const SpeedTestPage()
        )
    );
  } else {
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
      loggingService.logEvent('Game complete: $title', phone: userData.phone);

      // TODO: Navigate to home page
      /*Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => home(gameTitle: title),
      ),
    );*/
    });
  }
}

void updateFavorites(GameData game, BuildContext context) {
  final userData = Provider.of<UserDataProvider>(context, listen: false);
  // Check if a game with the same text is already in favorites
  final isFavorited = favorite_games.any((favGame) => favGame.text == game.text);

  if (isFavorited) {
    // remove from favorites
    favorite_games.removeWhere((favGame) => favGame.text == game.text);
    loggingService.logEvent('${game.text} removed from favorites.', phone: userData.phone);
  } else {
    // add to favorites
    favorite_games.add(game);
    loggingService.logEvent('${game.text} added to favorites.', phone: userData.phone);
  }
}
