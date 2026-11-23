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
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fetchQuestions().then((questions) {
      if (!mounted) return;
      setState(() {
        _initialData = questions;
        _isLoading = false;
      });
    }).catchError((e) {
      if (mounted) setState(() { _isLoading = false; });
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
          : _initialData.isEmpty
          // never show a survey with nothing to answer
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('This survey is not available right now.', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                  ],
                ),
              ),
            )
          : Form(
        key: _formKey,
        child: Survey(
          onNext: (results) { _questionResults = results; },
          initialData: _initialData,
        ),
      ),
      bottomNavigationBar: (_isLoading || _initialData.isEmpty) ? null : Column(
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

                onPressed: _submitting ? null : () async {
                  loggingService.logEvent('Clicked submit survey.', email: userData.email);
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _submitting = true);
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  // the answers are saved first; the survey only counts as done once they are safely stored
                  final saved = await addUserData(userData.email, _questionResults, widget.surveyDocId);
                  if (!saved) {
                    messenger.showSnackBar(const SnackBar(content: Text('Could not submit the survey. Please try again.')));
                    if (mounted) setState(() => _submitting = false);
                    return;
                  }
                  if (widget.surveyDocId == 'demographic') {
                    await userData.setDemographicStatus();
                  } else {
                    // only the remote-config survey (METUX etc.) counts as this wave's survey being seen;
                    // recording it for the demographic survey would stop METUX from ever being shown
                    await userData.recordSurveyToken(userData.email);
                  }
                  // the messenger belongs to the app, so the message stays visible after this page closes
                  messenger.showSnackBar(const SnackBar(content: Text('Survey submitted')));
                  // return to the screen that opened the survey, which can then show the next one
                  navigator.pop();
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
      print("Document data: ${doc.data()}");
      if (!doc.exists) return [];
      final data = doc.data();
      final rawQuestions = data?['questions'] as List<dynamic>;
      print("Raw questions: $rawQuestions");
      return rawQuestions.map((q) {
        // Handle both array and map formats for backwards compatibility
        List<String> choices;
        final rawChoices = q['choices'];

        if (rawChoices is List) {
          // New format: array preserves order
          choices = rawChoices.map((c) => c.toString()).toList();
        } else if (rawChoices is Map) {
          final sorted = (rawChoices as Map<String, dynamic>).entries.toList()
            ..sort((a, b) {
              // Parse keys as integers for correct numeric ordering
              final aInt = int.tryParse(a.key) ?? 0;
              final bInt = int.tryParse(b.key) ?? 0;
              return aInt.compareTo(bInt);
            });
          choices = sorted.map((e) => e.value.toString()).toList();
        } else {
          choices = [];
        }

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
// Returns whether the answers were stored.
Future<bool> addUserData(String userID, List<QuestionResult> results, String surveyDocId) async {
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
    return true;
  } catch (e) {
    print("Error adding user: $e");
    return false;
  }
}