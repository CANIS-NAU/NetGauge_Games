// This page will hold information and FAQs pertaining to the project
// importing libraries, pages, and packages

import 'package:flutter/material.dart';
import 'home.dart';
import 'user_data_manager.dart';
import 'package:provider/provider.dart';
import 'surveys.dart';

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
            TextButton(
              onPressed: () => {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SurveyState(
                    surveyDocId: 'METUX',
                    responseCollection: 'survey_responses',
                  )),
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
              child: const Text("Take METUX Survey"),
              //TODO: Nice-to-have-->add a trailing expand icon here
            ),
          ],
        )
    );
  }
}

