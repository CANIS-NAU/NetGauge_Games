// Reads the text of a game page aloud, for players who would rather listen than read (or cannot read the screen).
//
// The page's text is pulled out of the game's web page with a little JavaScript (see readablePageTextScript),
// tidied up and split into pieces the phone's speech engine can handle (see textToSpeechChunks), and spoken one
// piece at a time. The phone's built-in text-to-speech engine does the talking, so no internet is needed.

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

// What happened when a page was read.
enum ReadOutcome {
  // the whole page was read out
  finished,
  // the player stopped it, or moved to another page, part way through
  stopped,
  // the page has no text to read
  nothingToRead,
  // the phone has no working text-to-speech engine
  unavailable,
}

// The part that actually speaks. Kept separate so tests can use a pretend one.
abstract class SpeechEngine {
  // speaks the text and completes when it has been spoken (or was stopped)
  Future<void> speak(String text);

  Future<void> stop();
}

class FlutterTtsEngine implements SpeechEngine {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _prepare() async {
    if (_ready) return;
    // make speak() wait until the text has been spoken
    await _tts.awaitSpeakCompletion(true);
    // 0.5 is a normal speaking pace on both Android and iPhone
    await _tts.setSpeechRate(0.5);
    if (!kIsWeb && Platform.isIOS) {
      // so the audio is heard even when the phone's silent switch is on
      try {
        await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, const [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ]);
      } catch (e) {
        debugPrint('[PAGE_READER] Could not set the iOS audio category: $e');
      }
    }
    _ready = true;
  }

  @override
  Future<void> speak(String text) async {
    await _prepare();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}

class PageReader extends ChangeNotifier {
  final SpeechEngine _engine;

  PageReader({SpeechEngine? engine}) : _engine = engine ?? FlutterTtsEngine();

  bool _speaking = false;

  // true while a page is being read out
  bool get isSpeaking => _speaking;

  // Which reading is current. A new reading, or a stop, moves this on, so an older reading that is still winding
  // down can tell it is no longer wanted.
  int _reading = 0;

  // Reads the text aloud. Completes when it has been read, or has stopped for any reason. Starting a new reading
  // replaces the one in progress.
  Future<ReadOutcome> read(String text) async {
    final chunks = textToSpeechChunks(text);
    if (chunks.isEmpty) return ReadOutcome.nothingToRead;

    final mine = ++_reading;
    // whatever was being read before stops first
    try {
      await _engine.stop();
    } catch (e) {
      debugPrint('[PAGE_READER] Could not stop the previous reading: $e');
    }
    if (mine != _reading) return ReadOutcome.stopped;

    _speaking = true;
    notifyListeners();
    try {
      for (final chunk in chunks) {
        if (mine != _reading) return ReadOutcome.stopped;
        await _engine.speak(chunk);
      }
      return mine == _reading ? ReadOutcome.finished : ReadOutcome.stopped;
    } catch (e) {
      debugPrint('[PAGE_READER] Text-to-speech failed: $e');
      return ReadOutcome.unavailable;
    } finally {
      if (mine == _reading) {
        _speaking = false;
        notifyListeners();
      }
    }
  }

  // Stops reading, if it is reading. Safe to call at any time.
  Future<void> stop() async {
    _reading++;
    final wasSpeaking = _speaking;
    _speaking = false;
    if (wasSpeaking) notifyListeners();
    try {
      await _engine.stop();
    } catch (e) {
      debugPrint('[PAGE_READER] Could not stop: $e');
    }
  }
}

// JavaScript that returns the visible text of the page the player is on: the current passage (not menus, scripts or
// anything hidden). innerText leaves out anything that is not showing.
const String readablePageTextScript = '''
(function () {
  var passages = document.querySelectorAll('#passages .passage');
  var root = passages.length ? passages[passages.length - 1] : (document.querySelector('.passage') || document.body);
  return JSON.stringify(root.innerText || '');
})()
''';

// JavaScript, run once the game has loaded, that tells the app whenever the game moves to another page so the app
// can stop reading the old one. Twine's SugarCube announces each page change with a ":passagestart" event.
const String passageChangeHookScript = '''
(function () {
  if (window.__netgaugeReaderHooked) return;
  function hook() {
    if (!window.jQuery) { setTimeout(hook, 200); return; }
    window.__netgaugeReaderHooked = true;
    jQuery(document).on(':passagestart', function () {
      FlutterBridge.postMessage(JSON.stringify({command: 'passageChanged'}));
    });
  }
  hook();
})();
''';

// What a web page's JavaScript hands back depends on the phone: Android wraps a string in an extra layer of quotes
// and iPhone does not, and the script above already returns JSON. This unwraps however many layers there are.
String decodeJavaScriptString(Object? result) {
  Object? value = result;
  // a string can only be unwrapped a few times, so a pathological value cannot loop forever
  for (var i = 0; i < 4 && value is String; i++) {
    final text = value.trim();
    if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
      try {
        value = jsonDecode(text);
        continue;
      } catch (_) {
        break;
      }
    }
    break;
  }
  return value is String ? value : '';
}

// Speech engines can only take so much text at once (Android's limit is 4000 characters), so a long page is split into
// pieces, at sentence ends where possible. The text is also tidied so the voice pauses in the right places.
List<String> textToSpeechChunks(String text, {int maxLength = 3000}) {
  final prepared = _prepareForSpeech(text);
  if (prepared.isEmpty) return [];

  // sentences, each keeping its ending punctuation
  final sentences = RegExp(r'[^.!?]+[.!?]+["”’)]*|[^.!?]+$')
      .allMatches(prepared)
      .map((m) => m.group(0)!.trim())
      .where((s) => s.isNotEmpty);

  final chunks = <String>[];
  var current = '';
  void flush() {
    if (current.isNotEmpty) chunks.add(current);
    current = '';
  }

  for (final sentence in sentences) {
    if (sentence.length > maxLength) {
      // a very long run with no sentence end: cut it at spaces
      flush();
      var rest = sentence;
      while (rest.length > maxLength) {
        var cut = rest.lastIndexOf(' ', maxLength);
        if (cut <= 0) cut = maxLength;
        chunks.add(rest.substring(0, cut).trim());
        rest = rest.substring(cut).trim();
      }
      current = rest;
      continue;
    }
    if (current.isNotEmpty && current.length + 1 + sentence.length > maxLength) flush();
    current = current.isEmpty ? sentence : '$current $sentence';
  }
  flush();
  return chunks;
}

// Collapses whitespace, and ends each line with punctuation so headings, buttons and paragraphs are not run together
// into one breathless sentence ("SCIENTIST Welcome to the war" becomes "SCIENTIST. Welcome to the war").
String _prepareForSpeech(String text) {
  final lines = text
      .replaceAll(' ', ' ')
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      // a line of only symbols (dividers, decorations) has nothing to say
      .where((line) => RegExp(r'[A-Za-z0-9]').hasMatch(line));

  return lines.map((line) => RegExp(r'[.!?:;,…"”’)]$').hasMatch(line) ? line : '$line.').join(' ');
}
