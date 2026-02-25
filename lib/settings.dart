// This page will hold information and FAQs pertaining to the project
// importing libraries, pages, and packages

import 'package:flutter/material.dart';
import 'home.dart';
import 'user_data_manager.dart';
import 'package:provider/provider.dart';

class Settings extends StatelessWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context);
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
              'Settings',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 25)
          ),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children:[
            const SizedBox(height: 8),
          ],
        )
    );
  }
}

