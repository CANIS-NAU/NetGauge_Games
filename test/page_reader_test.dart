import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:internet_measurement_games_app/page_reader.dart';

// A pretend speech engine. Each spoken piece waits until the test says it has finished, so tests can stop a
// reading part way through.
class FakeEngine implements SpeechEngine {
  final List<String> spoken = [];
  int stopCalls = 0;
  bool failToSpeak = false;
  final List<Completer<void>> _pending = [];

  @override
  Future<void> speak(String text) {
    if (failToSpeak) throw Exception('no text-to-speech engine');
    spoken.add(text);
    final done = Completer<void>();
    _pending.add(done);
    return done.future;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    // stopping speech ends whatever is being spoken, like a real engine
    for (final pending in _pending) {
      if (!pending.isCompleted) pending.complete();
    }
  }

  // the piece being spoken finishes naturally
  void finishCurrentPiece() {
    final pending = _pending.lastWhere((c) => !c.isCompleted);
    pending.complete();
  }
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('textToSpeechChunks', () {
    test('has nothing to say for empty text, spaces, or only decorations', () {
      expect(textToSpeechChunks(''), isEmpty);
      expect(textToSpeechChunks('   \n\n  \t '), isEmpty);
      expect(textToSpeechChunks('* * *\n-----\n~~~'), isEmpty);
    });

    test('keeps a short page as one piece', () {
      expect(textToSpeechChunks('Welcome to the game. Press Start.'), ['Welcome to the game. Press Start.']);
    });

    test('ends headings and buttons with a full stop so the voice pauses instead of running on', () {
      final text = 'SCIENTIST\n\nWelcome to the war against the zombie plague, Doctor.\nContinue';
      expect(textToSpeechChunks(text), ['SCIENTIST. Welcome to the war against the zombie plague, Doctor. Continue.']);
    });

    test('does not add a full stop to a line that already ends with punctuation', () {
      expect(textToSpeechChunks('Are you ready?\nYes!\n"Go," she said'), ['Are you ready? Yes! "Go," she said.']);
    });

    test('collapses the blank lines and spacing that pages are padded with', () {
      final text = '\n\n\n\n  "Welcome,   Lost One,"  Omni intones.  Your soul   is shattered.\n\n\n';
      expect(textToSpeechChunks(text), ['"Welcome, Lost One," Omni intones. Your soul is shattered.']);
    });

    test('splits a long page into pieces at sentence ends, keeping everything in order', () {
      final sentences = [for (var i = 1; i <= 40; i++) 'This is sentence number $i of the story.'];
      final chunks = textToSpeechChunks(sentences.join(' '), maxLength: 200);

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(200));
        expect(chunk, endsWith('.')); // never cut in the middle of a sentence
      }
      expect(chunks.join(' '), sentences.join(' '));
    });

    test('cuts a very long run with no sentence end at spaces, never in the middle of a word', () {
      final words = [for (var i = 0; i < 100; i++) 'word$i'];
      final chunks = textToSpeechChunks(words.join(' '), maxLength: 120);

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(120));
      }
      // every word comes out whole and in order (the line gets a full stop on the end, since it had none)
      expect(chunks.join(' '), '${words.join(' ')}.');
    });

    test('pieces stay under the real speech engine limit by default', () {
      final longPage = List.filled(400, 'A sentence that goes on for a little while.').join(' ');
      for (final chunk in textToSpeechChunks(longPage)) {
        expect(chunk.length, lessThanOrEqualTo(3000));
      }
    });
  });

  group('decodeJavaScriptString', () {
    const page = 'SCIENTIST\n\nWelcome, Doctor.\nShe said "hi".';

    test('reads what Android returns (the string wrapped in an extra layer of JSON)', () {
      // the script returns JSON.stringify(text); Android then JSON-encodes that string again
      final fromAndroid = jsonEncode(jsonEncode(page));
      expect(decodeJavaScriptString(fromAndroid), page);
    });

    test('reads what an iPhone returns (just the one layer of JSON)', () {
      expect(decodeJavaScriptString(jsonEncode(page)), page);
    });

    test('leaves ordinary text that merely starts and ends with quotes alone', () {
      const dialogue = '"Welcome," said Omni. "Your soul is shattered."';
      expect(decodeJavaScriptString(jsonEncode(dialogue)), dialogue);
    });

    test('gives an empty string for anything that is not text', () {
      expect(decodeJavaScriptString(null), '');
      expect(decodeJavaScriptString(42), '');
      expect(decodeJavaScriptString('null'), 'null');
      expect(decodeJavaScriptString(''), '');
    });
  });

  group('PageReader', () {
    test('reads each piece in turn, and says it has finished', () async {
      final engine = FakeEngine();
      final reader = PageReader(engine: engine);
      final text = [for (var i = 1; i <= 6; i++) 'Sentence number $i of the page.'].join(' ');

      final result = reader.read(text);
      await settle();
      expect(reader.isSpeaking, isTrue);

      // with a long enough page there are several pieces; let each one finish
      while (reader.isSpeaking && engine._pending.any((c) => !c.isCompleted)) {
        engine.finishCurrentPiece();
        await settle();
      }

      expect(await result, ReadOutcome.finished);
      expect(reader.isSpeaking, isFalse);
      expect(engine.spoken.join(' '), text);
      reader.dispose();
    });

    test('tells listeners when reading starts and stops', () async {
      final engine = FakeEngine();
      final reader = PageReader(engine: engine);
      final states = <bool>[];
      reader.addListener(() => states.add(reader.isSpeaking));

      final result = reader.read('One short page.');
      await settle();
      engine.finishCurrentPiece();
      await result;

      expect(states, [true, false]);
      reader.dispose();
    });

    test('stopping part way through ends the reading and says no more', () async {
      final engine = FakeEngine();
      final reader = PageReader(engine: engine);
      // enough text for several pieces
      final text = List.filled(5, List.filled(60, 'Another sentence of text.').join(' ')).join(' ');
      expect(textToSpeechChunks(text).length, greaterThan(1));

      final result = reader.read(text);
      await settle();
      expect(reader.isSpeaking, isTrue);
      expect(engine.spoken.length, 1);

      await reader.stop();
      expect(reader.isSpeaking, isFalse);
      expect(await result, ReadOutcome.stopped);
      expect(engine.spoken.length, 1); // nothing more was spoken after the stop
      reader.dispose();
    });

    test('reading a new page replaces the one being read', () async {
      final engine = FakeEngine();
      final reader = PageReader(engine: engine);
      final long = List.filled(5, List.filled(60, 'Old page sentence here.').join(' ')).join(' ');

      final first = reader.read(long);
      await settle();
      final second = reader.read('The new page.');
      await settle();

      expect(await first, ReadOutcome.stopped);
      expect(engine.spoken.last, 'The new page.');
      expect(reader.isSpeaking, isTrue);

      engine.finishCurrentPiece();
      expect(await second, ReadOutcome.finished);
      reader.dispose();
    });

    test('a page with no text is reported, not read', () async {
      final engine = FakeEngine();
      final reader = PageReader(engine: engine);

      expect(await reader.read('  \n * * * \n'), ReadOutcome.nothingToRead);
      expect(engine.spoken, isEmpty);
      expect(reader.isSpeaking, isFalse);
      reader.dispose();
    });

    test('a phone with no speech engine is reported, and reading is not left "on"', () async {
      final engine = FakeEngine()..failToSpeak = true;
      final reader = PageReader(engine: engine);

      expect(await reader.read('Hello there.'), ReadOutcome.unavailable);
      expect(reader.isSpeaking, isFalse);
      reader.dispose();
    });

    test('stopping when nothing is being read is harmless', () async {
      final engine = FakeEngine();
      final reader = PageReader(engine: engine);
      await reader.stop();
      await reader.stop();
      expect(reader.isSpeaking, isFalse);
      reader.dispose();
    });

    test('can read again after a reading has finished or been stopped', () async {
      final engine = FakeEngine();
      final reader = PageReader(engine: engine);

      var result = reader.read('First page.');
      await settle();
      engine.finishCurrentPiece();
      expect(await result, ReadOutcome.finished);

      result = reader.read('Second page.');
      await settle();
      await reader.stop();
      expect(await result, ReadOutcome.stopped);

      result = reader.read('Third page.');
      await settle();
      engine.finishCurrentPiece();
      expect(await result, ReadOutcome.finished);
      expect(engine.spoken.last, 'Third page.');
      reader.dispose();
    });
  });

  group('the scripts run in the game', () {
    test('read the current page, and report page changes to the app', () {
      expect(readablePageTextScript, contains('#passages .passage'));
      expect(readablePageTextScript, contains('innerText'));
      expect(passageChangeHookScript, contains(':passagestart'));
      // the message the app listens for
      expect(passageChangeHookScript, contains('passageChanged'));
    });
  });
}
