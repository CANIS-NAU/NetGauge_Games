// Reference: https://www.youtube.com/watch?v=F1ofL4t6fyg
// Reference: https://medium.com/@punithsuppar7795/building-a-firebase-powered-real-time-leaderboard-with-websockets-flutter-web-12afd4718ae0
import 'package:flutter/material.dart';


class Leaderboard extends StatefulWidget {
  const Leaderboard({Key? key}) : super(key: key);

  @override
  State<Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends State<Leaderboard> {



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Leaderboard',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.purple,
      ),
    );
  }
}