import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_measurement_games_app/network_context.dart';
import 'package:internet_measurement_games_app/public_measurements.dart';

void main() {
  group('which connection a test is attributed to', () {
    test('Wi-Fi', () => expect(NetworkContext.fromResults([ConnectivityResult.wifi]).type, 'wifi'));
    test('mobile data is called cellular', () {
      final c = NetworkContext.fromResults([ConnectivityResult.mobile]);
      expect(c.type, 'cellular');
      expect(c.interfaces, ['cellular']);
    });
    test('wired wins over Wi-Fi, and Wi-Fi over mobile data', () {
      expect(NetworkContext.fromResults([ConnectivityResult.wifi, ConnectivityResult.ethernet]).type, 'ethernet');
      expect(NetworkContext.fromResults([ConnectivityResult.mobile, ConnectivityResult.wifi]).type, 'wifi');
    });
    test('a VPN is flagged and the underlying network still decides the type', () {
      final c = NetworkContext.fromResults([ConnectivityResult.wifi, ConnectivityResult.vpn]);
      expect(c.type, 'wifi');
      expect(c.vpnReported, isTrue);
    });
    test('a VPN alone, no connection and an empty answer', () {
      expect(NetworkContext.fromResults([ConnectivityResult.vpn]).type, 'other');
      expect(NetworkContext.fromResults([ConnectivityResult.none]).type, 'none');
      expect(NetworkContext.fromResults([]).type, 'unknown');
    });
  });

  group('capturing', () {
    test('a phone that fails to answer gives unknown instead of an error', () async {
      final c = await NetworkContext.capture(check: () async => throw Exception('no plugin'));
      expect(c.type, 'unknown');
    });
  });

  group('the stored field', () {
    final wifi = NetworkContext.fromResults([ConnectivityResult.wifi]);
    final mobile = NetworkContext.fromResults([ConnectivityResult.mobile]);

    test('has the type, interfaces and VPN flag', () {
      expect(wifi.toMeasurementField(atEnd: wifi),
          {'type': 'wifi', 'interfaces': ['wifi'], 'vpn_reported': false, 'changed_during_test': false});
    });
    test('flags a change of connection during the test', () {
      expect(wifi.toMeasurementField(atEnd: mobile)['changed_during_test'], isTrue);
    });
  });

  test('the shared copy gets only the connection type', () {
    final copy = PublicMeasurements.anonymize({
      'latitude': 35.0, 'longitude': -111.0, 'download_speed': 1, 'upload_speed': 1, 'latency': 1,
      'network': {'type': 'wifi', 'interfaces': ['wifi', 'vpn'], 'vpn_reported': true, 'changed_during_test': false},
    });
    expect(copy!['network_type'], 'wifi');
    expect(copy.containsKey('network'), isFalse);
  });
}
