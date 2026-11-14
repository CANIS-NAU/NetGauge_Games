import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:internet_measurement_games_app/game_progress.dart';

void main() {
  late Directory storage;

  // each test starts like a freshly installed app: nobody has a game waiting
  setUp(() async {
    storage = Directory.systemTemp.createTempSync('game_progress_test');
    Hive.init(storage.path);
    await GameProgress.load();
  });

  tearDown(() async {
    await Hive.close();
    storage.deleteSync(recursive: true);
  });

  // puts an entry straight into the store, so a test can place a save with a date of its choosing
  Future<void> storeRaw(String account, String game, Map<String, dynamic> entry) async {
    final box = await Hive.openBox('game_progress');
    await box.put('$account::$game', entry);
  }

  group('saving and coming back', () {
    test('a player comes back to where they left off', () async {
      await GameProgress.save('ada@nau.edu', 'Zombie Apocalypse', 'STATE-1', passage: 'The Lab');

      final saved = GameProgress.progressFor('ada@nau.edu', 'Zombie Apocalypse');
      expect(saved, isNotNull);
      expect(saved!.save, 'STATE-1');
      expect(saved.game, 'Zombie Apocalypse');
      expect(saved.passage, 'The Lab');
      expect(GameProgress.hasProgress('ada@nau.edu', 'Zombie Apocalypse'), isTrue);
    });

    test('a game nobody has started has nothing to come back to', () {
      expect(GameProgress.progressFor('ada@nau.edu', 'Dragon Slayer'), isNull);
      expect(GameProgress.hasProgress('ada@nau.edu', 'Dragon Slayer'), isFalse);
    });

    test('turning another page replaces the place from before', () async {
      await GameProgress.save('ada@nau.edu', 'Soul Seeker', 'STATE-1');
      await GameProgress.save('ada@nau.edu', 'Soul Seeker', 'STATE-2');

      expect(GameProgress.progressFor('ada@nau.edu', 'Soul Seeker')!.save, 'STATE-2');
    });

    test('two people sharing a phone do not land in each other\'s games', () async {
      await GameProgress.save('ada@nau.edu', 'Soul Seeker', 'ADA-STATE');
      await GameProgress.save('grace@nau.edu', 'Soul Seeker', 'GRACE-STATE');

      expect(GameProgress.progressFor('ada@nau.edu', 'Soul Seeker')!.save, 'ADA-STATE');
      expect(GameProgress.progressFor('grace@nau.edu', 'Soul Seeker')!.save, 'GRACE-STATE');
    });

    test('one game can be paused while another is played', () async {
      await GameProgress.save('ada@nau.edu', 'Soul Seeker', 'SOUL');
      await GameProgress.save('ada@nau.edu', 'Dragon Slayer', 'DRAGON');

      expect(GameProgress.progressFor('ada@nau.edu', 'Soul Seeker')!.save, 'SOUL');
      expect(GameProgress.progressFor('ada@nau.edu', 'Dragon Slayer')!.save, 'DRAGON');
    });

    test('a signed-out player, who has no account to save against, saves nothing', () async {
      await GameProgress.save('', 'Soul Seeker', 'STATE-1');
      expect(GameProgress.progressFor('', 'Soul Seeker'), isNull);
    });
  });

  group('states that are not worth keeping', () {
    test('an empty state does not wipe a real save', () async {
      await GameProgress.save('ada@nau.edu', 'Soul Seeker', 'REAL-STATE');
      await GameProgress.save('ada@nau.edu', 'Soul Seeker', '');

      expect(GameProgress.progressFor('ada@nau.edu', 'Soul Seeker')!.save, 'REAL-STATE');
    });

    test('an implausibly large state is not stored', () async {
      await GameProgress.save('ada@nau.edu', 'Soul Seeker', 'x' * (GameProgress.maxSaveLength + 1));
      expect(GameProgress.progressFor('ada@nau.edu', 'Soul Seeker'), isNull);
    });

    test('a stored entry that cannot be read is ignored, not crashed on', () async {
      await storeRaw('ada@nau.edu', 'Soul Seeker', {'something': 'from an older version of the app'});
      expect(GameProgress.progressFor('ada@nau.edu', 'Soul Seeker'), isNull);
    });
  });

  group('finishing and starting over', () {
    test('clearing a game means it starts from the beginning', () async {
      await GameProgress.save('ada@nau.edu', 'Soul Seeker', 'STATE-1');
      await GameProgress.clear('ada@nau.edu', 'Soul Seeker');

      expect(GameProgress.progressFor('ada@nau.edu', 'Soul Seeker'), isNull);
    });

    test('clearing one game leaves the others alone', () async {
      await GameProgress.save('ada@nau.edu', 'Soul Seeker', 'SOUL');
      await GameProgress.save('ada@nau.edu', 'Dragon Slayer', 'DRAGON');
      await GameProgress.clear('ada@nau.edu', 'Soul Seeker');

      expect(GameProgress.progressFor('ada@nau.edu', 'Soul Seeker'), isNull);
      expect(GameProgress.progressFor('ada@nau.edu', 'Dragon Slayer')!.save, 'DRAGON');
    });

    test('clearing everything leaves the other player untouched', () async {
      await GameProgress.save('ada@nau.edu', 'Soul Seeker', 'SOUL');
      await GameProgress.save('ada@nau.edu', 'Dragon Slayer', 'DRAGON');
      await GameProgress.save('grace@nau.edu', 'Soul Seeker', 'GRACE-SOUL');

      await GameProgress.clearAll('ada@nau.edu');

      expect(GameProgress.inProgress('ada@nau.edu'), isEmpty);
      expect(GameProgress.progressFor('grace@nau.edu', 'Soul Seeker')!.save, 'GRACE-SOUL');
    });
  });

  group('the list of games waiting', () {
    test('is most recently played first', () async {
      await GameProgress.save('ada@nau.edu', 'Soul Seeker', 'SOUL');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await GameProgress.save('ada@nau.edu', 'Dragon Slayer', 'DRAGON');

      expect(GameProgress.inProgress('ada@nau.edu').map((s) => s.game), ['Dragon Slayer', 'Soul Seeker']);
    });

    test('is empty for a player who has not paused anything', () {
      expect(GameProgress.inProgress('ada@nau.edu'), isEmpty);
    });
  });

  group('games nobody came back to', () {
    test('are not offered once they are too old', () async {
      await storeRaw('ada@nau.edu', 'Soul Seeker', {
        'game': 'Soul Seeker',
        'save': 'OLD-STATE',
        'savedAt': DateTime.now().subtract(GameProgress.keepFor + const Duration(days: 1)).toIso8601String(),
      });

      expect(GameProgress.progressFor('ada@nau.edu', 'Soul Seeker'), isNull);
      expect(GameProgress.inProgress('ada@nau.edu'), isEmpty);
    });

    test('are still offered just inside the cut-off', () async {
      await storeRaw('ada@nau.edu', 'Soul Seeker', {
        'game': 'Soul Seeker',
        'save': 'RECENT-STATE',
        'savedAt': DateTime.now().subtract(GameProgress.keepFor - const Duration(days: 1)).toIso8601String(),
      });

      expect(GameProgress.progressFor('ada@nau.edu', 'Soul Seeker')!.save, 'RECENT-STATE');
    });

    test('are thrown away when the app next starts', () async {
      await storeRaw('ada@nau.edu', 'Soul Seeker', {
        'game': 'Soul Seeker',
        'save': 'OLD-STATE',
        'savedAt': DateTime.now().subtract(const Duration(days: 365)).toIso8601String(),
      });
      await GameProgress.save('ada@nau.edu', 'Dragon Slayer', 'DRAGON');

      await GameProgress.load();

      final box = Hive.box('game_progress');
      expect(box.get('ada@nau.edu::Soul Seeker'), isNull);
      expect(box.get('ada@nau.edu::Dragon Slayer'), isNotNull);
    });
  });

  group('which games can be resumed', () {
    test('the stories can', () {
      for (final game in ['Zombie Apocalypse', 'Soul Seeker', 'Dragon Slayer', 'Scavenger Hunt', 'Space Explorers']) {
        expect(GameProgress.supportsResume(game), isTrue, reason: game);
      }
    });

    test('a single measurement has no place to come back to', () {
      expect(GameProgress.supportsResume('Measure Internet'), isFalse);
    });
  });

  group('telling the player when they left off', () {
    final now = DateTime(2026, 11, 13, 12, 0);

    test('reads the way a person would say it', () {
      expect(describeSavedAt(now.subtract(const Duration(seconds: 20)), now: now), 'just now');
      expect(describeSavedAt(now.subtract(const Duration(minutes: 1)), now: now), '1 minute ago');
      expect(describeSavedAt(now.subtract(const Duration(minutes: 40)), now: now), '40 minutes ago');
      expect(describeSavedAt(now.subtract(const Duration(hours: 1)), now: now), '1 hour ago');
      expect(describeSavedAt(now.subtract(const Duration(hours: 5)), now: now), '5 hours ago');
      expect(describeSavedAt(now.subtract(const Duration(days: 1)), now: now), '1 day ago');
      expect(describeSavedAt(now.subtract(const Duration(days: 9)), now: now), '9 days ago');
    });
  });

  group('the scripts sent into the game', () {
    test('reaching an ending tells the app the game is finished instead of saving it', () {
      expect(gameProgressHookScript, contains('gameFinished'));
      for (final name in endingPassageNames) {
        expect(gameProgressHookScript, contains('"$name"'));
      }
    });

    test('the resume script carries the state as a quoted string', () {
      final script = resumeScript('ABC-123');
      expect(script, contains('"ABC-123"'));
    });

    test('a state full of quotes and newlines cannot break out of the script', () {
      // SugarCube's own save strings are plain text, but nothing stops a state from containing these
      const awkward = 'a"b\\c\nd\'e</script>';
      final script = resumeScript(awkward);

      // the state appears only as a JSON string literal, which is a valid JavaScript string literal too
      expect(script, contains(jsonEncode(awkward)));
      expect(script, isNot(contains('a"b\\c\nd')));
    });

    test('the resume script reports back whether it worked', () {
      final script = resumeScript('STATE');
      expect(script, contains('gameResumed'));
      expect(script, contains('gameResumeFailed'));
    });

    test('the save hook listens for the player turning a page', () {
      expect(gameProgressHookScript, contains(':passageend'));
      expect(gameProgressHookScript, contains('saveGameProgress'));
    });

    test('the save hook holds off while a resume is under way', () {
      // otherwise the opening passage would overwrite the save the player is being put back into
      expect(gameProgressHookScript, contains('__netgauge.resuming'));
      expect(resumeScript('STATE'), contains('__netgauge.resuming = true'));
    });

    test('a second run of the resume script cannot leave saving switched off', () {
      // the game's page can finish loading more than once; if the "already resumed" check came after saving was
      // held off, the second run would return early and never let saving start again
      final script = resumeScript('STATE');
      expect(
        script.indexOf('__netgauge.resumed'),
        lessThan(script.indexOf('__netgauge.resuming = true')),
      );
    });

    test('the resume script redraws the page after putting the state back', () {
      // SugarCube restores the state without redrawing; its own Continue button follows a load with Engine.show(),
      // and leaving that out strands the player on the opening passage while the game sits where they left off
      expect(resumeScript('STATE'), contains('Engine.show()'));
    });

    test('both scripts try the current save calls and fall back to the older ones', () {
      for (final script in [gameProgressHookScript, resumeScript('STATE')]) {
        expect(script, contains('Save.base64'));
        expect(script, contains('serialize'));
      }
    });
  });
}
