/* Since the current homepage has a lot of background tasks (which I plan to
* move to other files), I am just going to set up the UI here.*/

// import needed files and libraries
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:internet_measurement_games_app/speed_test_page.dart';
import 'widgets/buttons.dart';
import 'flutter_bridge.dart';
import 'session_manager.dart';
import 'location_logger.dart';
import 'post_game_survey.dart';
import 'vibration_controller.dart';
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
    final userData = Provider.of<UserDataProvider>(context);
    loggingService.logEvent('User is in game catalog page', email: userData.email);

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
        backgroundColor: const Color(0xFF440154),
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
  loggingService.logEvent('Showing pop-up for ${game.text}', email: userData.email);
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
  // Commenting out some games for the Hozhoni event, add back after
 /* if (game.text == "Soul Seeker") {
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
  } */
  if (game.text == "Scavenger Hunt") {
    title = "Scavenger Hunt";
    content = "Search for pictures and fun facts!";
    gameURL = 'hozhoni_scavenger_hunt.html';
    imagePath = game.imagePath;
  }
  if (game.text == "Measure Internet") {
    title = "Measure Internet";
    content = "Measure your connectivity!";
    imagePath = game.imagePath;
  }

  if (game.text == "Space Explorers") {
    title = "Space Explorers";
    content = "Testing this plz work!";
    imagePath = game.imagePath;
    gameURL = 'space_explorers_short.html';
  }

  if (game.text == "Constellation Quest") {
    title = "Constellation Quest";
    content = "Testing this plz work!";
    imagePath = game.imagePath;
    gameURL = 'constellation_quest.html';
  }


  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, dialogSetState) {
          // Listen to the provider to get the most up-to-date favorites
          final currentFavorites = Provider.of<UserDataProvider>(context).favoriteGames;
          final isFavorited = currentFavorites.any((favGame) => favGame.text == game.text);

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
                  isFavorited ? Icons.favorite : Icons.favorite_border,
                  color: isFavorited ? Colors.red : null,
                ),
                onPressed: () {
                  updateFavorites(game, context);
                  // No need for dialogSetState(() {}) because Provider will rebuild the widget
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
  loggingService.logEvent('Launching $title', email: userData.email);

  // keep the navigator: the dialog's context is no longer valid once the game ends
  final navigator = Navigator.of(context);

  // Close the dialog first
  Navigator.pop(context);

  // log the game start with the session manager
  SessionManager.startGame(title, userData.email);
  // begin location logging
  LocationLogger.start();

  final isSpeedTest = title == 'Measure Internet';
  if (isSpeedTest) {
    loggingService.logEvent('Clicked measure internet.', email: userData.email);
  }

  // Measure Internet is a native page, every other game runs in the WebView
  final gamePage = isSpeedTest
      ? MaterialPageRoute(builder: (context) => const SpeedTestPage())
      : MaterialPageRoute(builder: (context) => WebViewPage(title: title, gameFile: gameFile));

  // the end-of-session handling below runs for every game, including Measure Internet
  navigator.push(gamePage).then((_) async {
    // grab the session ID before the session is cleared, so the survey can be tied to it
    final sessionId = SessionManager.sessionId ?? '';

    // a failure while wrapping up the session must never keep the survey from being offered
    try {
      // the WebView games save their own session as they close; Measure Internet saves its session here,
      // while the current game is still set, and only if at least one test was run
      if (isSpeedTest && SessionManager.measurements.isNotEmpty) {
        await SessionManager.saveCurrentSession(userData.email, userData);
        userData.fetchUserData();
      }
      // log the game end with the session manager
      SessionManager.endGame(userData.email); // also will stop logging location
      // Stop the vibration service, in case the game started it
      VibrationController.stop();
      loggingService.logEvent('Game complete: $title', email: userData.email);
    } catch (e, stackTrace) {
      debugPrint('[GAME_CATALOG] Error ending session for $title: $e\n$stackTrace');
    }

    // offer the optional post-game survey (skips are logged inside)
    try {
      debugPrint('[GAME_CATALOG] Offering post-game survey for $title (navigator mounted: ${navigator.mounted}).');
      if (navigator.mounted) {
        await offerPostGameSurvey(
          navigator.context,
          gameTitle: title,
          sessionId: sessionId,
          email: userData.email,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[GAME_CATALOG] Error offering post-game survey: $e\n$stackTrace');
    }
  });
}

void updateFavorites(GameData game, BuildContext context) {
  final userData = Provider.of<UserDataProvider>(context, listen: false);
  // Call the new provider method to handle the update and Firestore sync
  userData.toggleFavorite(game.text);
  
  // Log the event
  final isFavorited = userData.favoriteGames.any((favGame) => favGame.text == game.text);
  if (isFavorited) {
    loggingService.logEvent('${game.text} removed from favorites.', email: userData.email);
  } else {
    loggingService.logEvent('${game.text} added to favorites.', email: userData.email);
  }
}
