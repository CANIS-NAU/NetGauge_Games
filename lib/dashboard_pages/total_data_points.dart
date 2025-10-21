import 'package:flutter/material.dart';


class TotalDataPoints extends StatefulWidget {
  const TotalDataPoints({Key? key}) : super(key: key);

  @override
  State<TotalDataPoints> createState() => _TotalDataPointsState();
}

class _TotalDataPointsState extends State<TotalDataPoints> {



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Total Data Points Collected',
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