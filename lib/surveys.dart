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

class SurveyState extends StatefulWidget {
  final String surveyDocId;      // e.g. 'metux' or 'survey_a'
  final String responseCollection; // e.g. 'METUX' or 'survey_a_responses'

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
    return Scaffold(
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
                    addUserData("some_user_id", _questionResults, widget.surveyDocId).then((_) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const HomePage()),
                      );
                    });
                  }
                }
            ),
          ),
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