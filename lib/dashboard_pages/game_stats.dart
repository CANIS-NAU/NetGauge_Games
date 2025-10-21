import 'package:flutter/material.dart';


class GameStats extends StatefulWidget {
  const GameStats({Key? key}) : super(key: key);

  @override
  State<GameStats> createState() => _GameStatsState();
}

class _GameStatsState extends State<GameStats> {



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Game Statistics',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
}