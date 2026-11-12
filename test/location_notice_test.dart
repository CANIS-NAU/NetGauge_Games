import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:internet_measurement_games_app/location_notice.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// a pretend phone: location services on or off, and what the permission is and becomes when asked
class FakeGeolocator extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  bool servicesEnabled;
  LocationPermission permission;
  LocationPermission answerWhenAsked;
  bool throwOnCheck;
  int timesAsked = 0;

  FakeGeolocator({
    this.servicesEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.answerWhenAsked = LocationPermission.whileInUse,
    this.throwOnCheck = false,
  });

  @override
  Future<bool> isLocationServiceEnabled() async {
    if (throwOnCheck) throw Exception('no location plugin');
    return servicesEnabled;
  }

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    timesAsked++;
    permission = answerWhenAsked;
    return permission;
  }
}

void main() {
  group('checkLocationIssue', () {
    Future<LocationIssue?> check(FakeGeolocator fake) {
      GeolocatorPlatform.instance = fake;
      return checkLocationIssue();
    }

    test('location services off is reported', () async {
      expect(await check(FakeGeolocator(servicesEnabled: false)), LocationIssue.servicesDisabled);
    });

    test('nothing to report when location is on and allowed', () async {
      expect(await check(FakeGeolocator()), isNull);
      expect(await check(FakeGeolocator(permission: LocationPermission.always)), isNull);
    });

    test('a new user is asked for permission, and is left alone if they allow it', () async {
      final fake = FakeGeolocator(permission: LocationPermission.denied, answerWhenAsked: LocationPermission.whileInUse);
      expect(await check(fake), isNull);
      expect(fake.timesAsked, 1);
    });

    test('a user who declines the permission prompt is reported', () async {
      final fake = FakeGeolocator(permission: LocationPermission.denied, answerWhenAsked: LocationPermission.denied);
      expect(await check(fake), LocationIssue.permissionDenied);
    });

    test('a user who blocked location for good is reported, without being asked again', () async {
      final fake = FakeGeolocator(permission: LocationPermission.deniedForever);
      expect(await check(fake), LocationIssue.permissionBlocked);
      expect(fake.timesAsked, 0);
    });

    test('if the check itself fails, nobody is nagged', () async {
      expect(await check(FakeGeolocator(throwOnCheck: true)), isNull);
    });
  });

  group('the pop-up', () {
    Future<List<LocationIssue>> open(WidgetTester tester, LocationIssue issue) async {
      final fixed = <LocationIssue>[];
      await tester.binding.setSurfaceSize(const Size(411, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showLocationNotice(context, issue, onFix: (i) async => fixed.add(i)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return fixed;
    }

    testWidgets('tells the user they will not get the full experience, and offers to continue', (tester) async {
      await open(tester, LocationIssue.servicesDisabled);

      expect(find.text(locationNoticeTitle), findsOneWidget);
      expect(find.textContaining('will not get the full NetGauge experience'), findsOneWidget);
      expect(find.text('Continue Without Location'), findsOneWidget);
    });

    testWidgets('Continue Without Location closes it and does nothing else', (tester) async {
      final fixed = await open(tester, LocationIssue.servicesDisabled);

      await tester.tap(find.text('Continue Without Location'));
      await tester.pumpAndSettle();

      expect(find.text(locationNoticeTitle), findsNothing);
      expect(fixed, isEmpty);
    });

    testWidgets('the main button matches the reason, closes the pop-up and runs the fix', (tester) async {
      for (final entry in {
        LocationIssue.servicesDisabled: 'Open Location Settings',
        LocationIssue.permissionDenied: 'Allow Location',
        LocationIssue.permissionBlocked: 'Open App Settings',
      }.entries) {
        final fixed = await open(tester, entry.key);

        expect(find.text(entry.value), findsOneWidget);
        await tester.tap(find.text(entry.value));
        await tester.pumpAndSettle();

        expect(find.text(locationNoticeTitle), findsNothing);
        expect(fixed, [entry.key]);
      }
    });
  });
}
