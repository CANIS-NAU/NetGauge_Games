// this will hold the code for the METUX survey

// import libraries, pages, and packages
import 'package:flutter/material.dart';
import 'package:flutter_survey/flutter_survey.dart';
import 'home.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Setting up a data file with question, question type, answer in a json or csv
//more easily create new surveys

// set up instance of firestore database, all responses will be pushed to FB
final FirebaseFirestore db = FirebaseFirestore.instance;

class METUXState extends StatefulWidget {
  const METUXState({super.key});

  @override
  State<METUXState> createState() => _METUXState();
}

// load a list (or dict?) of questions, answer options, whether required or not
// iterate over list and publish below, print in widget

class _METUXState extends State<METUXState> {
  final _formKey = GlobalKey<FormState>();
  List<QuestionResult> _questionResults = [];
  final List<Question> _initialData = [
    Question(
        question: "I decided to start using NetGauge because: Other people wanted me to use it.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "I would expect NetGauge to be interesting to use.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "I believe NetGauge could improve my life.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "I believe NetGauge could improve my life.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "NetGauge could help me do something important.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "I would want others to know I use NetGauge.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "I would feel bad about myself if I did not try NetGauge.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "I think NetGauge would be enjoyable.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "I am required to use NetGauge (e.g. by my job, school, family).",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "NetGauge could be of value to me.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "NetGauge would be fun to use.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "NetGauge would be fun to use.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "NetGauge would look good to others if I use it.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "I would feel confident that I could use NetGauge effectively.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "NetGauge would be easy for me to use.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "I would feel very capable and effective at using NetGauge.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "I would feel confident in my ability to use NetGauge.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "Learning how to use NetGauge would be difficult.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "I would find the NetGauge interface and controls confusing.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "It would not be easy for me to use NetGauge.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "NetGauge would provide me with useful options and choices.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "I would be able to get NetGauge to do what I would want.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "I would feel pressured by the use of NetGauge.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "NetGauge would feel intrusive.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "NetGauge would feel controlling.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "NetGauge would help me form or sustain fulfilling relationships.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "NetGauge would help me feel part of a larger community.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "NetGauge would make me feel connected to other people.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "I would not feel close to other users using NetGauge.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "NetGauge would not support meaningful connections to others.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "I would find using NetGauge too difficult to do regularly.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
    Question(
        question: "I would only use NetGauge to do tasks because I have to.",
        isMandatory: true,
        answerChoices: const {
          "1 (Strongly disagree)": null,
          "2 (Somewhat disagree)": null,
          "3 (Neither disagree nor agree)": null,
          "4 (Somewhat agree)": null,
          "5 (Strongly agree)": null,
        }),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: Survey(
            onNext: (questionResults) {
              _questionResults = questionResults;
            },
            initialData: _initialData),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.deepPurple, // Background Color
              ),
              child: const Text("Submit"),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  // Add code here to submit results to firebase backend
                  // navigate back to home once complete
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomePage(),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}


// method for uploading data to the DB
Future<void> addUserData(String userID, List<QuestionResult> results) async {
  final usersCollection = db.collection("METUX"); // Reference to a 'users' collection
  final userData = {
    "ID": userID,
    "Response": results,
    "timestamp": FieldValue.serverTimestamp(),
  };

  try {
    await usersCollection.add(userData); // Adds a new document with an auto-ID
    print("User added successfully!");
  } catch (e) {
    print("Error adding user: $e");
  }
}