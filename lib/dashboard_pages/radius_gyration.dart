import 'package:flutter/material.dart';


class RadiusGyration extends StatefulWidget {
  const RadiusGyration({Key? key}) : super(key: key);

  @override
  State<RadiusGyration> createState() => _RadiusGyrationState();
}

class _RadiusGyrationState extends State<RadiusGyration> {



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Radius of Gyration',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue,
      ),
    );
  }
}