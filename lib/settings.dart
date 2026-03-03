// This page will hold information and FAQs pertaining to the project
// importing libraries, pages, and packages

import 'package:flutter/material.dart';
import 'user_data_manager.dart';
import 'package:provider/provider.dart';
import 'surveys.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';

class Settings extends StatelessWidget {
  const Settings({super.key});

  Future<void> logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      // Optional: Navigate to the login screen or a different screen after logout
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LoginPage()));
    } on FirebaseAuthException catch (e) {
      // Handle potential errors during sign out
      print('Error signing out: $e');
    }
  }


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
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(20),
              ),
              onPressed: () => logout(context),
              child: const Text('Logout',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20)),
            ),
          ],
        )
    );
  }
}

