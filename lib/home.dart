// New homepage, so I can easily refer to the original home page as needed
import 'package:flutter/material.dart';
import 'speed_test_page.dart';
import 'widgets/buttons.dart';
import 'game_catalog.dart';
import 'user_data_manager.dart';
import 'package:provider/provider.dart';
import 'dashboard.dart';

class Utilities {
  final String text;
  final IconData? icon;
  final String? imagePath;
  Utilities({required this.text, this.icon, this.imagePath});

}

final List<Utilities> utilityButtons = [
  Utilities(text: "Game Catalog", icon:Icons.menu_book),
  Utilities(text: "Settings", icon:Icons.settings),
  Utilities(text: "Measure Internet", icon:Icons.wifi),
  Utilities(text: "Community Statistics", icon:Icons.auto_graph_rounded),
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
    final userData = Provider.of<UserDataProvider>(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.help_outline_rounded),
          onPressed: () { /* Open drawer/menu */ },
        ),
        centerTitle: true,
        title: const Text(
            'NetGauge Games',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 25)
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                color: Colors.white,
                child:
                  Text(
                      'Total Points Collected: ${userData.measurementsTaken} \n'
                          'Total Distance Traveled: ${userData.distanceTraveled} \n'
                          'Total Radius of Gyration: ${userData.totalRadiusGyration}',
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          fontSize: 20)
                  ),
              ),
              // add expand player statistics button
              TextButton(
                onPressed: () => {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PlayerStatistics()),
                  )
                },
                style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        color: Colors.black, // Specify the border color
                        width: 3,           // Specify the border width
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  fixedSize: const Size(500, 25),
                  //backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(
                      fontSize: 20,
                    fontWeight: FontWeight.w400,
                  )
                ),
                child: const Text("Expand Player Statistics"),
                //TODO: Nice-to-have-->add a trailing expand icon here
              ),
              const SizedBox(height: 350),
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
                    textSize: 13,
                    buttonHeight: 60,
                    buttonLength: 85,
                    onTap: () async {
                      String buttonText = utilityButtons[index].text;
                      if (buttonText == 'Settings') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SpeedTestPage(),
                          ),
                        );
                      } else if (buttonText == 'Game Catalog') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const GameCatalog()),
                        );
                        // 3. After returning, rebuild the UI to show the new favorites
                        setState(() {});
                      } else if (buttonText == 'Measure Internet') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SpeedTestPage(),
                          ),
                        );
                      }
                    },
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
                    onTap: () async {
                      await showCustomPopup(context, favorite_games[index]);
                      setState(() {});
                    },
                  );
                },
              ),
            ]
          ),
      ),
      ),
    );
  }
}