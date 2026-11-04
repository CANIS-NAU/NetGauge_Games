// this will hold the optional survey that is offered at the end of each game session

// import libraries, pages, and packages
import 'package:flutter/material.dart';
import 'package:flutter_survey/flutter_survey.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';
import 'activity_logs.dart';

final loggingService = GetIt.instance<LoggingService>();

// orders numeric keys/IDs numerically ("2" before "10"), falling back to plain string order
int _compareKeys(String a, String b) {
  final aNum = int.tryParse(a);
  final bNum = int.tryParse(b);
  if (aNum != null && bNum != null) return aNum.compareTo(bNum);
  return a.compareTo(b);
}

// builds one survey question from its Firestore data: 'text' and 'choices' (array), optional 'mandatory'
Question _questionFromData(Map<String, dynamic> data) {
  final rawChoices = data['choices'];
  List<String> choices;

  // handle both array and map formats, same as the other surveys
  if (rawChoices is List) {
    choices = rawChoices.map((c) => c.toString()).toList();
  } else if (rawChoices is Map) {
    final sorted = rawChoices.entries.toList()
      ..sort((a, b) => _compareKeys(a.key.toString(), b.key.toString()));
    choices = sorted.map((e) => e.value.toString()).toList();
  } else {
    choices = [];
  }

  return Question(
    question: data['text'],
    isMandatory: data['mandatory'] ?? false,
    answerChoices: {for (var c in choices) c: null},
  );
}

// Questions live under surveys/postGame as questions -> [number] -> text, choices.
// Numbered documents in a 'questions' subcollection are used first; if there are none, a 'questions'
// field (array, or map keyed by number) on the surveys/postGame document is used instead.
Future<List<Question>> _fetchPostGameQuestions() async {
  final postGameDoc = FirebaseFirestore.instance.collection('surveys').doc('postGame');

  final snapshot = await postGameDoc.collection('questions').get();
  if (snapshot.docs.isNotEmpty) {
    final docs = snapshot.docs.toList()..sort((a, b) => _compareKeys(a.id, b.id));
    return docs.map((doc) => _questionFromData(doc.data())).toList();
  }

  final doc = await postGameDoc.get();
  final rawQuestions = doc.data()?['questions'];
  if (rawQuestions is List) {
    return rawQuestions.map((q) => _questionFromData(Map<String, dynamic>.from(q as Map))).toList();
  }
  if (rawQuestions is Map) {
    final entries = rawQuestions.entries.toList()
      ..sort((a, b) => _compareKeys(a.key.toString(), b.key.toString()));
    return entries.map((e) => _questionFromData(Map<String, dynamic>.from(e.value as Map))).toList();
  }
  return [];
}

// Offers the post-game survey. The survey is optional: skipping it (declining the prompt or
// leaving the survey without submitting) is logged through the logging service.
// Pass a long-lived context (e.g. navigator.context), since the game screen is already closed by now.
Future<void> offerPostGameSurvey(
  BuildContext context, {
  required String gameTitle,
  required String sessionId,
  required String email,
}) async {
  List<Question> questions;
  try {
    questions = await _fetchPostGameQuestions();
  } catch (e) {
    debugPrint("[POST_GAME_SURVEY] Error fetching questions: $e");
    return;
  }
  debugPrint("[POST_GAME_SURVEY] Fetched ${questions.length} question(s).");
  // nothing to ask, so there is nothing to offer or skip
  if (questions.isEmpty || !context.mounted) return;

  void logSkipped() {
    loggingService.logEvent(
      'Skipped post-game survey for $gameTitle.',
      email: email,
      params: {'game': gameTitle, 'session_id': sessionId},
    );
  }

  final wantsSurvey = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Quick survey?'),
      content: Text('Thanks for playing $gameTitle! Would you like to answer a few optional questions about your session?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Skip'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Take Survey'),
        ),
      ],
    ),
  );

  if (wantsSurvey != true || !context.mounted) {
    logSkipped();
    return;
  }

  final submitted = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => PostGameSurveyPage(
        questions: questions,
        gameTitle: gameTitle,
        sessionId: sessionId,
        email: email,
      ),
    ),
  );

  // backing out of the survey without submitting counts as skipping it
  if (submitted != true) logSkipped();
}

class PostGameSurveyPage extends StatefulWidget {
  final List<Question> questions;
  final String gameTitle;
  final String sessionId;
  final String email;

  const PostGameSurveyPage({
    super.key,
    required this.questions,
    required this.gameTitle,
    required this.sessionId,
    required this.email,
  });

  @override
  State<PostGameSurveyPage> createState() => _PostGameSurveyPageState();
}

class _PostGameSurveyPageState extends State<PostGameSurveyPage> {
  final _formKey = GlobalKey<FormState>();
  List<QuestionResult> _questionResults = [];
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final submission = {
      "ID": widget.email,
      "game": widget.gameTitle,
      "session_id": widget.sessionId,
      "responses": _questionResults.map((r) => {
        "question": r.question,
        "answer": r.answers,
      }).toList(),
      "timestamp": FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('responses')
          .doc('postGame')
          .collection('submissions')
          .add(submission);
      loggingService.logEvent('Submitted post-game survey for ${widget.gameTitle}.', email: widget.email);
      if (!mounted) return;
      // the messenger belongs to the app, so the message stays visible after this page closes
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Survey submitted')));
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("[POST_GAME_SURVEY] Error submitting survey: $e");
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit the survey. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Post-Game Survey',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 25),
        ),
        backgroundColor: const Color(0xFF440154),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: Survey(
          onNext: (results) { _questionResults = results; },
          initialData: widget.questions,
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
                backgroundColor: Colors.deepPurple,
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: const Text("Submit", style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
