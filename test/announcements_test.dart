import 'package:flutter_test/flutter_test.dart';
import 'package:internet_measurement_games_app/announcements.dart';

void main() {
  final now = DateTime.utc(2026, 11, 20, 12);
  bool applies(Announcement a, {bool guest = false, String platform = 'android', Set<String> seen = const {}}) =>
      a.appliesTo(now: now, isGuest: guest, currentPlatform: platform, seenIds: seen);

  group('parse', () {
    test('empty, broken or incomplete values give no announcement', () {
      expect(Announcement.parse(null), isNull);
      expect(Announcement.parse(''), isNull);
      expect(Announcement.parse('   '), isNull);
      expect(Announcement.parse('not json'), isNull);
      expect(Announcement.parse('[1,2]'), isNull);
      expect(Announcement.parse('{"message":"hi"}'), isNull); // no id
      expect(Announcement.parse('{"id":"a"}'), isNull); // no message
      expect(Announcement.parse('{"id":"a","message":"  "}'), isNull);
      expect(Announcement.parse('{"id":5,"message":"hi"}'), isNull);
    });

    test('only id and message are required, the rest has safe defaults', () {
      final a = Announcement.parse('{"id":"x","message":"Hello"}')!;
      expect(a.title, '');
      expect(a.button, 'OK');
      expect(a.audience, AnnouncementAudience.all);
      expect(a.platform, 'all');
      expect(a.frequency, AnnouncementFrequency.once);
      expect(a.start, isNull);
      expect(a.end, isNull);
    });

    test('reads every field', () {
      final a = Announcement.parse('''{"id":"x","title":"T","message":"M","button":"Go","audience":"Guests",
        "platform":"iOS","show":"always","start":"2026-11-01T00:00:00Z","end":"2026-12-01T00:00:00Z"}''')!;
      expect(a.title, 'T');
      expect(a.button, 'Go');
      expect(a.audience, AnnouncementAudience.guests);
      expect(a.platform, 'ios');
      expect(a.frequency, AnnouncementFrequency.always);
      expect(a.start, DateTime.utc(2026, 11, 1));
      expect(a.end, DateTime.utc(2026, 12, 1));
    });

    test('unknown values fall back to the defaults and a bad date is ignored', () {
      final a = Announcement.parse('{"id":"x","message":"M","audience":"nobody","show":"sometimes","start":"soon"}')!;
      expect(a.audience, AnnouncementAudience.all);
      expect(a.frequency, AnnouncementFrequency.once);
      expect(a.start, isNull);
    });
  });

  group('appliesTo', () {
    test('a plain message applies', () {
      expect(applies(const Announcement(id: 'x', message: 'm')), isTrue);
    });

    test('a once message is not shown again after it was seen, but a new id is', () {
      const a = Announcement(id: 'x', message: 'm');
      expect(applies(a, seen: {'x'}), isFalse);
      expect(applies(const Announcement(id: 'y', message: 'm'), seen: {'x'}), isTrue);
    });

    test('an always message ignores the seen list', () {
      const a = Announcement(id: 'x', message: 'm', frequency: AnnouncementFrequency.always);
      expect(applies(a, seen: {'x'}), isTrue);
    });

    test('respects the start and end times', () {
      expect(applies(Announcement(id: 'x', message: 'm', start: DateTime.utc(2026, 11, 21))), isFalse);
      expect(applies(Announcement(id: 'x', message: 'm', end: DateTime.utc(2026, 11, 19))), isFalse);
      expect(applies(Announcement(id: 'x', message: 'm', start: DateTime.utc(2026, 11, 1), end: DateTime.utc(2026, 12, 1))), isTrue);
    });

    test('respects the audience', () {
      const guests = Announcement(id: 'x', message: 'm', audience: AnnouncementAudience.guests);
      const registered = Announcement(id: 'x', message: 'm', audience: AnnouncementAudience.registered);
      expect(applies(guests, guest: true), isTrue);
      expect(applies(guests, guest: false), isFalse);
      expect(applies(registered, guest: false), isTrue);
      expect(applies(registered, guest: true), isFalse);
    });

    test('respects the platform', () {
      const ios = Announcement(id: 'x', message: 'm', platform: 'ios');
      expect(applies(ios, platform: 'ios'), isTrue);
      expect(applies(ios, platform: 'android'), isFalse);
    });
  });
}
