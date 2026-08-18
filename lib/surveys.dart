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
import 'dart:async';

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
      if (mounted) {
        setState(() {
          _initialData = questions;
          _isLoading = false;
        });
      }
    }).catchError((e) {
      print("Error in initState _fetchQuestions: $e");
      if (mounted) {
        setState(() { _isLoading = false; });
      }
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
                  if (_formKey.currentState!.validate()) {
                    if (widget.surveyDocId == 'demographic') {
                      await userData.setDemographicStatus();
                    } else {
                      // Only record the token for periodic surveys (like METUX)
                      // so we don't accidentally skip them.
                      await userData.recordSurveyToken(userData.email);
                    }
                    await addUserData(userData.email, _questionResults, widget.surveyDocId, widget.sessionId, widget.gameTitle);
                    if (mounted) {
                      if (widget.onComplete != null) {
                        widget.onComplete!();
                      } else {
                        Navigator.pop(context);
                      }
                    }
                  }
                }
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }


  Future<List<Question>> _fetchQuestions({int attempt = 1}) async {
    try {
      print("Fetching questions for: ${widget.surveyDocId} (Attempt $attempt)");
      
      // Wait a moment for network to stabilize if this is the first attempt after a game
      if (attempt == 1 && widget.surveyDocId == 'postGame') {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      var doc = await db.collection('surveys')
          .doc(widget.surveyDocId)
          .get()
          .timeout(const Duration(seconds: 10));
      
      // If not found, try lowercase version (e.g., METUX -> metux)
      if (!doc.exists) {
        print("Survey not found with ID ${widget.surveyDocId}, trying lowercase...");
        doc = await db.collection('surveys')
            .doc(widget.surveyDocId.toLowerCase())
            .get()
            .timeout(const Duration(seconds: 10));
      }

      print("Document exists: ${doc.exists}");
      if (!doc.exists) return [];
      final data = doc.data() ?? {};
      print("Survey data keys: ${data.keys.toList()}");

      List<dynamic> rawQuestions = [];
      
      // 1. Try standard nested 'questions' or 'Questions' field first
      final nestedQuestions = data['questions'] ?? data['Questions'];
      
      if (nestedQuestions != null) {
        if (nestedQuestions is List) {
          rawQuestions = nestedQuestions;
        } else if (nestedQuestions is Map) {
          // Sort by numeric key (0, 1, 2...) to preserve order
          final sorted = (nestedQuestions as Map<String, dynamic>).entries.toList()
            ..sort((a, b) {
              final aInt = int.tryParse(a.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              final bInt = int.tryParse(b.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              return aInt.compareTo(bInt);
            });
          rawQuestions = sorted.map((e) => e.value).toList();
        }
      } else {
        // 2. Flat structure: questions are top-level fields (e.g. 'question1', 'q1'...)
        final questionKeys = data.keys.where((k) {
          final lk = k.toLowerCase();
          return lk.startsWith('question') || RegExp(r'^q\d+$').hasMatch(lk);
        }).toList();
        
        if (questionKeys.isNotEmpty) {
          print("Found flat structure with ${questionKeys.length} question fields.");
          // Sort keys numerically so question2/q2 comes before question10/q10
          questionKeys.sort((a, b) {
            final aInt = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            final bInt = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            return aInt.compareTo(bInt);
          });
          rawQuestions = questionKeys.map((k) => data[k]).toList();
        }
      }

      if (rawQuestions.isEmpty) {
        print("No questions found in document.");
        return [];
      }

      print("Raw questions count: ${rawQuestions.length}");
      final questions = rawQuestions.map((q) {
        if (q == null) return null;
        
        String text = '';
        List<String> choices = [];
        bool isMandatory = false;

        if (q is Map) {
          text = (q['text'] ?? q['question'] ?? q['prompt'] ?? '').toString();
          final rawMandatory = q['mandatory'] ?? q['required'];
          if (rawMandatory is bool) {
            isMandatory = rawMandatory;
          } else if (rawMandatory is String) {
            isMandatory = rawMandatory.toLowerCase() == 'true';
          }
          
          final rawChoices = q['choices'] ?? q['options'];
          if (rawChoices is List) {
            choices = rawChoices.map((c) => c.toString()).toList();
          } else if (rawChoices is Map) {
            final sorted = (rawChoices as Map<String, dynamic>).entries.toList()
              ..sort((a, b) {
                final aInt = int.tryParse(a.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                final bInt = int.tryParse(b.key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                return aInt.compareTo(bInt);
              });
            choices = sorted.map((e) => e.value.toString()).toList();
          }
        } else if (q is String) {
          text = q;
        }

        if (text.isEmpty) {
          print("Warning: Skipping question with empty text: $q");
          return null;
        }

        return Question(
          question: text,
          isMandatory: isMandatory,
          answerChoices: {for (var c in choices) c: null},
        );
      }).whereType<Question>().toList();

      print("Successfully mapped ${questions.length} questions.");
      return questions;
    } catch (e, stack) {
      print("Error fetching questions (Attempt $attempt): $e");
      
      final errorStr = e.toString().toLowerCase();
      bool isNetworkError = errorStr.contains('unavailable') || 
                            errorStr.contains('timeout') || 
                            errorStr.contains('network') ||
                            errorStr.contains('deadline');

      if (attempt < 5 && isNetworkError) {
        print("Network issue detected. Retrying survey fetch in 3 seconds (Attempt ${attempt + 1})...");
        await Future.delayed(const Duration(seconds: 3));
        return _fetchQuestions(attempt: attempt + 1);
      }
      print(stack);
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