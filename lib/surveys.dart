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
  final VoidCallback? onComplete;
  final String? sessionId;
  final String? gameTitle;

  const SurveyState({
    super.key,
    required this.surveyDocId,
    required this.responseCollection,
    this.onComplete,
    this.sessionId,
    this.gameTitle,
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
        backgroundColor: const Color(0xFF440154),
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
                  if (widget.surveyDocId == 'demographic') {
                    userData.setDemographicStatus();
                  }
                  if (_formKey.currentState!.validate()) {
                    await userData.recordSurveyToken(userData.email); // replaces recordSurveyShown
                    addUserData(userData.email, _questionResults, widget.surveyDocId, widget.sessionId, widget.gameTitle).then((_) {
                      widget.onComplete != null
                          ? widget.onComplete!()
                          : Navigator.push(context, MaterialPageRoute(builder: (_) => const HomePage()));
                    });
                  }
                }
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }


  Future<List<Question>> _fetchQuestions() async {
    try {
      print("Fetching questions for: ${widget.surveyDocId}");
      final doc = await db.collection('surveys').doc(widget.surveyDocId).get();
      print("Document exists: ${doc.exists}");
      if (!doc.exists) return [];
      final data = doc.data();

      // Handle both List and Map formats for the questions field
      final rawQuestionsData = data?['questions'];
      List<dynamic> rawQuestions;

      if (rawQuestionsData is List) {
        rawQuestions = rawQuestionsData;
      } else if (rawQuestionsData is Map) {
        // Sort by numeric key (0, 1, 2...) to preserve order
        final sorted = (rawQuestionsData as Map<String, dynamic>).entries.toList()
          ..sort((a, b) {
            final aInt = int.tryParse(a.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            final bInt = int.tryParse(b.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            return aInt.compareTo(bInt);
          });
        rawQuestions = sorted.map((e) => e.value).toList();
      } else {
        return [];
      }

      print("Raw questions: $rawQuestions");
      return rawQuestions.map((q) {
        // Handle both array and map formats for backwards compatibility
        List<String> choices;
        final rawChoices = q['choices'] ?? q['options'];

        if (rawChoices is List) {
          // New format: array preserves order
          choices = rawChoices.map((c) => c.toString()).toList();
        } else if (rawChoices is Map) {
        final sorted = (rawChoices as Map<String, dynamic>).entries.toList()
          ..sort((a, b) {
            // Strip 'option_' prefix before parsing as int
            final aInt = int.tryParse(a.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            final bInt = int.tryParse(b.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            return aInt.compareTo(bInt);
          });
        choices = sorted.map((e) => e.value.toString()).toList();
      } else {
          choices = [];
        }

        return Question(
          question: q['text'],
          isMandatory: q['mandatory'] ?? false,  // <-- fallback to false if null
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
Future<void> addUserData(String userID, List<QuestionResult> results, String surveyDocId, String? sessionId, String? gameTitle) async {
  final userData = {
    "ID": userID,
    "responses": results.map((r) => {
      "question": r.question,
      "answer": r.answers,
    }).toList(),
    "timestamp": FieldValue.serverTimestamp(),
    if (sessionId != null) "session_id": sessionId,
    if (gameTitle != null) "gameTitle": gameTitle,
  };

  try {
    await db.collection('responses').doc(surveyDocId).collection('submissions').add(userData);
    print("User added successfully!");
  } catch (e) {
    print("Error adding user: $e");
  }
}