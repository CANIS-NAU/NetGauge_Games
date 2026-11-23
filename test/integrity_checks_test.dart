import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:internet_measurement_games_app/integrity_checks.dart';
import 'package:internet_measurement_games_app/network_context.dart';

Position fix({bool mocked = false}) => Position(
      latitude: 35.0,
      longitude: -111.0,
      timestamp: DateTime.utc(2026, 11, 14),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      isMocked: mocked,
    );

IntegrityChecks checks({
  Future<bool> Function()? vpn,
  Future<bool> Function()? mock,
  bool permitted = true,
}) =>
    IntegrityChecks(
      vpnCheck: vpn ?? () async => false,
      mockCheck: mock ?? () async => false,
      locationPermitted: () async => permitted,
    );

final wifi = NetworkContext.fromResults([ConnectivityResult.wifi]);
final wifiVpn = NetworkContext.fromResults([ConnectivityResult.wifi, ConnectivityResult.vpn]);

void main() {
  group('VPN', () {
    test('clean when the plugin and the connection report agree there is none', () async {
      final s = await checks().capture(network: wifi);
      expect(s.vpnUsed, isFalse);
      expect(s.flags(), isEmpty);
    });

    test('flagged when the plugin sees one', () async {
      final s = await checks(vpn: () async => true).capture(network: wifi);
      expect(s.vpnUsed, isTrue);
      expect(s.flags(), contains(IntegrityFlag.vpn));
    });

    test('flagged when only the connection report shows one (the plugin missed it)', () async {
      final s = await checks().capture(network: wifiVpn);
      expect(s.vpnUsed, isTrue);
    });

    test('a failing plugin is "could not tell", not "no VPN"', () async {
      final s = await checks(vpn: () async => throw Exception('no plugin')).capture();
      expect(s.vpnUsed, isNull);
      expect(s.flags(), contains(IntegrityFlag.vpnUnchecked));
    });

    test('a failing plugin still counts as clean if the connection report was readable and had no VPN', () async {
      final s = await checks(vpn: () async => throw Exception('x')).capture(network: wifi);
      expect(s.vpnUsed, isFalse);
    });

    test('a plugin that never answers times out instead of hanging', () async {
      final s = await checks(vpn: () => Future<bool>.delayed(const Duration(minutes: 5), () => false)).capture();
      expect(s.vpnDetected, isNull);
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  group('fake location', () {
    test('flagged when the fix itself is marked as mocked', () async {
      final s = await checks().capture(position: fix(mocked: true));
      expect(s.mockLocation, isTrue);
      expect(s.flags(), contains(IntegrityFlag.mockLocation));
    });

    test('flagged when the plugin says so even if the fix is not marked', () async {
      final s = await checks(mock: () async => true).capture(position: fix());
      expect(s.mockLocation, isTrue);
    });

    test('clean when both checked and neither objects', () async {
      final s = await checks().capture(position: fix());
      expect(s.mockLocation, isFalse);
    });

    test('without location permission the plugin is not called (it would prompt) and the answer is "unknown"', () async {
      var called = false;
      final s = await checks(permitted: false, mock: () async {
        called = true;
        return false;
      }).capture();
      expect(called, isFalse);
      expect(s.mockLocation, isNull);
      expect(s.flags(), contains(IntegrityFlag.mockUnchecked));
    });

    test('a real fix still gives an answer when the plugin cannot run', () async {
      final s = await checks(permitted: false).capture(position: fix());
      expect(s.mockLocation, isFalse);
    });
  });

  group('combining the readings from before and after a test', () {
    test('a VPN or fake position at either time counts', () async {
      final before = await checks(vpn: () async => true).capture(network: wifi);
      final after = await checks().capture(network: wifi, position: fix());
      final merged = before.mergedWith(after);
      expect(merged.vpnUsed, isTrue);
      expect(merged.mockLocation, isFalse);
    });

    test('unknown stays unknown only when neither reading could tell', () {
      const unknown = IntegritySignals();
      expect(unknown.mergedWith(unknown).vpnUsed, isNull);
      expect(unknown.mergedWith(const IntegritySignals(vpnDetected: false)).vpnUsed, isFalse);
    });
  });

  group('the stored fields', () {
    test('carry the flags, with a changed connection flagged too', () async {
      final s = await checks(vpn: () async => true).capture(network: wifi, position: fix());
      expect(s.toMeasurementFields(networkChanged: true), {
        'vpn_used': true,
        'mock_location': false,
        'integrity_flags': ['vpn', 'network_changed'],
      });
    });
  });
}
