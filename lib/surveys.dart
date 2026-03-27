// this will hold the code for the METUX survey

// import libraries, pages, and packages
import 'package:flutter/material.dart';
import 'package:flutter_survey/flutter_survey.dart';
import 'home.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_data_manager.dart';
import 'activity_logs.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

// Setting up a data file with question, question type, answer in a json or csv
//more easily create new surveys

// set up instance of firestore database, all responses will be pushed to FB
final FirebaseFirestore db = FirebaseFirestore.instance;

class SurveyState extends StatefulWidget {
  final String surveyDocId;      // e.g. 'metux' or 'gemographic'
  final String responseCollection; // all going to survey responses right now...

  const SurveyState({
    super.key,
    required this.surveyDocId,
    required this.responseCollection,
  });

  @override
  State<SurveyState> createState() => _SurveyState();
}
// load a list (or dict?) of questions, answer options, whether required or not
// iterate over list and publish below, print in widget

class _SurveyState extends State<SurveyState> {
  final _formKey = GlobalKey<FormState>();
  List<QuestionResult> _questionResults = [];

  List<Question> _initialData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchQuestions().then((questions) {
      setState(() {
        _initialData = questions;
        _isLoading = false;
      });
    }).catchError((e) {
      setState(() { _isLoading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
            'Survey',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 25)
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body:
      _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: Survey(
          onNext: (results) { _questionResults = results; },
          initialData: _initialData,
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.deepPurple, // Background Color
              ),
              child: const Text("Submit",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20)),
                onPressed: () async {
                  loggingService.logEvent('Clicked submit survey.', email: userData.email);
                  if(widget.surveyDocId == 'demographic') {
                    userData.setDemographicStatus();
                  }
                  if (_formKey.currentState!.validate()) {
                    addUserData(userData.email, _questionResults, widget.surveyDocId).then((_) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const HomePage()),
                      );
                    });
                  }
                  debugPrint("[SURVEYS] Something went wrong with surveys. Check for recording.");
                }
            ),
          ),
          const SizedBox(height: 5),
        ],
      ),
    );
  }
  Future<List<Question>> _fetchQuestions() async {
    try {
      print("Fetching questions for: ${widget.surveyDocId}");
      final doc = await db.collection('surveys').doc(widget.surveyDocId).get();
      print("Document exists: ${doc.exists}");
      print("Document data: ${doc.data()}");
      if (!doc.exists) return [];
      final data = doc.data();
      final rawQuestions = data?['questions'] as List<dynamic>;
      print("Raw questions: $rawQuestions");
      return rawQuestions.map((q) {
        final choices = (q['choices'] as Map<String, dynamic>)
            .values
            .map((c) => c.toString())
            .toList();
        return Question(
          question: q['text'],
          isMandatory: q['mandatory'],
          answerChoices: {for (var c in choices) c: null},
        );
      }).toList();
    } catch (e) {
      print("Error fetching questions: $e");
      return [];
    }
  }
}


// method for uploading data to the DB
Future<void> addUserData(String userID, List<QuestionResult> results, String surveyDocId) async {
  final userData = {
    "ID": userID,
    "responses": results.map((r) => {
      "question": r.question,
      "answer": r.answers,
    }).toList(),
    "timestamp": FieldValue.serverTimestamp(),
  };

  try {
    await db.collection('responses').doc(surveyDocId).collection('submissions').add(userData);
    print("User added successfully!");
  } catch (e) {
    print("Error adding user: $e");
  }
}