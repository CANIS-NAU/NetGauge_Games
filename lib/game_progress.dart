// Remembers where a player got to in a game, so they can put the phone away and pick the game back up later.
//
// Every game except "Measure Internet" is a Twine/SugarCube story running in the WebView (see flutter_bridge.dart).
// SugarCube can hand out its whole state as a single string (Save.serialize()) and put itself back into that state
// from the same string (Save.deserialize()), which covers the passage the player is on, their variables, and the
// history behind them. This file is the app's side of that: it keeps the most recent string for each game, for each
// person, on the phone.
//
// It is stored on the phone, not in Firestore, so a half-finished game is tied to the device it was started on.
// That keeps a mid-game save out of the research data, and means it works with no connection.
//
// Progress is per person and per game, so two people sharing a phone do not land in each other's games, and a
// player can have one game paused while they play another.
//
// Nothing here throws. If the saved progress cannot be read or written, the player simply starts the game from
// the beginning, which is what happened before any of this existed.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// What was saved for one game: the state string the game can be put back into, plus enough to describe it to the
// player ("Zombie Apocalypse, saved yesterday").
class SavedGame {
  // the game's title, as it appears in the catalog
  final String game;

  // SugarCube's own state string; meaningless to us, meaningful to the game
  final String save;

  // when the player was last at this point
  final DateTime savedAt;

  // the name of the passage (page) the player was on, when the game told us; used for debugging and logging only
  final String? passage;

  const SavedGame({required this.game, required this.save, required this.savedAt, this.passage});

  Map<String, dynamic> toMap() => {
        'game': game,
        'save': save,
        'savedAt': savedAt.toIso8601String(),
        if (passage != null) 'passage': passage,
      };

  // Reads back what toMap wrote. Returns null for anything that is not a usable save, so a stored value left by an
  // older version of the app, or a half-written one, is ignored rather than crashing the catalog.
  static SavedGame? fromMap(Object? stored) {
    if (stored is! Map) return null;
    final game = stored['game'];
    final save = stored['save'];
    final savedAt = DateTime.tryParse(stored['savedAt'] as String? ?? '');
    if (game is! String || game.isEmpty) return null;
    if (save is! String || save.isEmpty) return null;
    if (savedAt == null) return null;
    final passage = stored['passage'];
    return SavedGame(
      game: game,
      save: save,
      savedAt: savedAt,
      passage: passage is String && passage.isNotEmpty ? passage : null,
    );
  }
}

class GameProgress {
  static const String _boxName = 'game_progress';

  // A SugarCube save of a story this size is a few kilobytes. Anything far larger than that is not a save we want
  // to keep on the phone, so it is dropped rather than stored.
  static const int maxSaveLength = 2 * 1024 * 1024;

  // Saves older than this are not offered. A month-old game is one the player has moved on from, and offering it
  // is more confusing than helpful.
  static const Duration keepFor = Duration(days: 30);

  static Box? _box;

  // The games a resume is offered for. "Measure Internet" is a single measurement on a native page, not a story
  // with a place to come back to, so it is not one of them.
  static bool supportsResume(String game) => game != 'Measure Internet';

  // Opens the store. Hive must already be initialized (the logging service does that at startup). If the store
  // cannot be opened, every call below quietly does nothing and no progress is kept.
  static Future<void> load() async {
    try {
      _box = await Hive.openBox(_boxName);
      await _dropExpired();
    } catch (e) {
      debugPrint('[GAME_PROGRESS] Could not open the saved progress: $e');
      _box = null;
    }
  }

  // one player's one game
  static String _keyFor(String account, String game) => '$account::$game';

  // The progress waiting for this player in this game, or null if there is none worth offering (nothing saved, the
  // save is too old, or it cannot be read).
  static SavedGame? progressFor(String account, String game) {
    if (account.isEmpty) return null;
    try {
      final saved = SavedGame.fromMap(_box?.get(_keyFor(account, game)));
      if (saved == null) return null;
      if (DateTime.now().difference(saved.savedAt) > keepFor) return null;
      return saved;
    } catch (e) {
      debugPrint('[GAME_PROGRESS] Could not read the saved progress for $game: $e');
      return null;
    }
  }

  // whether this player has somewhere to come back to in this game
  static bool hasProgress(String account, String game) => progressFor(account, game) != null;

  // Remembers where the player is now, replacing whatever was saved for this game before. An empty or implausibly
  // large state string is ignored, so a game that is still starting up cannot wipe a real save.
  static Future<void> save(String account, String game, String state, {String? passage}) async {
    if (account.isEmpty || game.isEmpty) return;
    if (state.isEmpty || state.length > maxSaveLength) {
      debugPrint('[GAME_PROGRESS] Ignoring a ${state.length} character save for $game.');
      return;
    }
    final entry = SavedGame(game: game, save: state, savedAt: DateTime.now(), passage: passage);
    try {
      await _box?.put(_keyFor(account, game), entry.toMap());
    } catch (e) {
      debugPrint('[GAME_PROGRESS] Could not save progress for $game: $e');
    }
  }

  // Forgets this game, so the player starts it from the beginning next time. Used when a game is finished and when
  // the player chooses to start over.
  static Future<void> clear(String account, String game) async {
    if (account.isEmpty) return;
    try {
      await _box?.delete(_keyFor(account, game));
    } catch (e) {
      debugPrint('[GAME_PROGRESS] Could not clear progress for $game: $e');
    }
  }

  // Forgets every game this player has in progress (the "start everything fresh" button in Settings).
  static Future<void> clearAll(String account) async {
    if (account.isEmpty) return;
    try {
      final box = _box;
      if (box == null) return;
      final prefix = '$account::';
      final keys = box.keys.where((k) => k is String && k.startsWith(prefix)).toList();
      await box.deleteAll(keys);
    } catch (e) {
      debugPrint('[GAME_PROGRESS] Could not clear the saved progress: $e');
    }
  }

  // Every game this player has waiting, most recently played first. Used to tell them how many games are paused.
  static List<SavedGame> inProgress(String account) {
    if (account.isEmpty) return [];
    try {
      final box = _box;
      if (box == null) return [];
      final prefix = '$account::';
      final saves = box.keys
          .where((k) => k is String && k.startsWith(prefix))
          .map((k) => SavedGame.fromMap(box.get(k)))
          .whereType<SavedGame>()
          .where((s) => DateTime.now().difference(s.savedAt) <= keepFor)
          .toList();
      saves.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return saves;
    } catch (e) {
      debugPrint('[GAME_PROGRESS] Could not list the saved progress: $e');
      return [];
    }
  }

  // Throws away saves nobody is coming back to, so the store does not grow for ever. Done once at startup.
  static Future<void> _dropExpired() async {
    final box = _box;
    if (box == null) return;
    final now = DateTime.now();
    final stale = box.keys.where((key) {
      final saved = SavedGame.fromMap(box.get(key));
      // an entry that cannot be read is no use to anyone either
      return saved == null || now.difference(saved.savedAt) > keepFor;
    }).toList();
    if (stale.isEmpty) return;
    debugPrint('[GAME_PROGRESS] Dropping ${stale.length} saved game(s) nobody came back to.');
    await box.deleteAll(stale);
  }
}

// How long ago the game was saved, in the words a player would use ("just now", "2 days ago").
String describeSavedAt(DateTime savedAt, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(savedAt);
  if (elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} minute${elapsed.inMinutes == 1 ? '' : 's'} ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours} hour${elapsed.inHours == 1 ? '' : 's'} ago';
  return '${elapsed.inDays} day${elapsed.inDays == 1 ? '' : 's'} ago';
}

// ---------------------------------------------------------------------------------------------------------------
// The JavaScript side
//
// Twine's SugarCube can hand out its whole state as one string and put itself back into that state from the same
// string. In SugarCube 2.37 those are Save.base64.save() and Save.base64.load(); in older versions they were
// Save.serialize() and Save.deserialize(). Both are tried, newest first, so a game exported from an older Twine
// still works.
//
// Neither script ever throws into the game: a game whose state cannot be read just does not get saved, and a game
// that cannot be restored starts from the beginning instead.
// ---------------------------------------------------------------------------------------------------------------

// Shared helpers, included by both scripts below. Defines __netgauge.progress with:
//   ready()   - whether SugarCube has finished starting up, so its state can be read or replaced
//   read()    - the current state as a string, or null
//   write(s)  - puts the game into the state held in s; returns a promise
//   tell(c,p) - sends a message back to the app
const String _progressHelpers = '''
window.__netgauge = window.__netgauge || {};
if (!window.__netgauge.progress) {
  window.__netgauge.progress = {
    // the app is told about things that happen out here, where there is no other way to see them
    tell: function (command, payload) {
      try {
        FlutterBridge.postMessage(JSON.stringify({command: command, payload: payload || {}}));
      } catch (e) {}
    },
    api: function () {
      var sc = window.SugarCube;
      return (sc && sc.Save) ? sc.Save : null;
    },
    // SugarCube is still setting itself up until the first passage has been shown; reading or replacing its state
    // before then either fails or captures a game that has not started
    ready: function () {
      var sc = window.SugarCube;
      if (!sc || !sc.Save || !sc.State || !sc.Engine) return false;
      if (sc.Engine.state === sc.Engine.States.Init) return false;
      return sc.State.length > 0;
    },
    read: function () {
      var Save = this.api();
      if (!Save) return null;
      try {
        if (Save.base64 && typeof Save.base64.save === 'function') return Save.base64.save();
        if (typeof Save.serialize === 'function') return Save.serialize();
      } catch (e) {
        this.tell('gameProgressProblem', {what: 'save', reason: String(e)});
      }
      return null;
    },
    write: function (state) {
      var Save = this.api();
      if (!Save) return Promise.reject(new Error('the game is not ready'));
      var loaded;
      // the newer call hands back a promise; the older one may not, so both are wrapped
      try {
        if (Save.base64 && typeof Save.base64.load === 'function') {
          loaded = Promise.resolve(Save.base64.load(state));
        } else if (typeof Save.deserialize === 'function') {
          loaded = Promise.resolve(Save.deserialize(state));
        } else {
          return Promise.reject(new Error('this game cannot be resumed'));
        }
      } catch (e) {
        return Promise.reject(e);
      }
      // Putting the state back does not redraw anything: SugarCube's own Continue button follows its load with
      // Engine.show(), and without that the player is left looking at the opening passage while the game quietly
      // sits at the point they had actually reached.
      return loaded.then(function (result) {
        window.SugarCube.Engine.show();
        return result;
      });
    },
    // Waits for SugarCube to finish starting up, then runs the callback. Gives up after about ten seconds, which
    // is far longer than a story bundled in the app takes to start.
    whenReady: function (run, giveUp) {
      var tries = 0;
      var self = this;
      (function attempt() {
        if (self.ready()) { run(); return; }
        if (++tries > 50) { if (giveUp) giveUp(); return; }
        setTimeout(attempt, 200);
      })();
    }
  };
}
''';

// The passages that end each game, by name. Reaching one clears the saved place instead of saving it, so a finished
// game is not offered as "in progress". A game with no entry here keeps its last page (Space Explorers has no clear
// ending passage; add its final passage name here).
const List<String> endingPassageNames = [
  'ScientistDeath',
  'ScientistSuccess',
  'finishGame',
  'constellation_finish',
];

final String _endingPassagesJs = jsonEncode(endingPassageNames);

// Run once the game has loaded: saves the player's place every time they turn a page, so closing the app, the phone
// dying, or wandering out of the game all leave something to come back to.
//
// Saving is held off while a resume is in progress (see resumeScript), so the start of the story cannot overwrite
// the very save the player is about to be put back into.
final String gameProgressHookScript = '''
(function () {
  $_progressHelpers
  if (window.__netgauge.progressHooked) return;
  var progress = window.__netgauge.progress;
  var endingPassages = $_endingPassagesJs;

  function hook() {
    if (!window.jQuery) { setTimeout(hook, 200); return; }
    window.__netgauge.progressHooked = true;

    jQuery(document).on(':passageend', function () {
      // a resume is under way, so what is on screen is not where the player left off
      if (window.__netgauge.resuming) return;
      if (!progress.ready()) return;
      var sc = window.SugarCube;
      // an ending has been reached: there is nothing to come back to, so forget the save instead of keeping it
      var current = (sc && sc.State && sc.State.passage) || '';
      if (endingPassages.indexOf(current) !== -1) {
        progress.tell('gameFinished', {passage: current});
        return;
      }
      var state = progress.read();
      if (!state) return;
      progress.tell('saveGameProgress', {
        save: String(state),
        passage: (sc && sc.State && sc.State.passage) || null
      });
    });
  }

  hook();
})();
''';

// Puts the game back where the player left off. Injected before the hook above, so the flag it sets is already in
// place when the story's first passage is shown.
String resumeScript(String state) => '''
(function () {
  $_progressHelpers
  var progress = window.__netgauge.progress;
  // The page can finish loading more than once (a reload from inside the game), and the player is only put back
  // where they left off the first time. This is checked before anything is held up, so a second run cannot leave
  // saving switched off for the rest of the game.
  if (window.__netgauge.resumed) return;
  window.__netgauge.resumed = true;
  // Saving is held off up front, before the story shows anything, so the opening passage is not mistaken for the
  // player's own page turn and saved over the very state they are being put back into.
  window.__netgauge.resuming = true;

  var state = ${_jsString(state)};

  function done(ok, reason) {
    window.__netgauge.resuming = false;
    progress.tell(ok ? 'gameResumed' : 'gameResumeFailed', ok ? {} : {reason: reason});
  }

  progress.whenReady(
    function () {
      progress.write(state).then(
        function () { done(true); },
        function (e) { done(false, String(e)); }
      );
    },
    function () { done(false, 'the game did not finish loading'); }
  );
})();
''';

// A Dart string as a JavaScript string literal. jsonEncode produces exactly that, and escapes everything that would
// otherwise break out of it.
String _jsString(String value) => const JsonEncoder().convert(value);
