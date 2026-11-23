// What kind of network a measurement was taken on.
//
// A speed test over Wi-Fi measures the home router and Wi-Fi link as much as the internet provider, and a test over
// a mobile connection is a different kind of evidence again, so every measurement is stored with the connection type
// it ran on. The type is read before the test starts and again after it ends; if the two differ (for example the
// phone dropped from Wi-Fi to mobile data part way through) the measurement is flagged, because its result mixes
// two networks.
//
// Not recorded yet: carrier name, radio generation (4G/5G) and signal strength. Reading those needs a platform
// plugin and extra phone permissions that the app does not have.

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

// the kinds of connection a measurement can be taken on
class NetworkType {
  static const String wifi = 'wifi';
  static const String cellular = 'cellular';
  static const String ethernet = 'ethernet';
  static const String bluetooth = 'bluetooth';
  static const String other = 'other';
  static const String none = 'none';
  // the phone would not say (the check failed or timed out)
  static const String unknown = 'unknown';
}

class NetworkContext {
  // the connection the test is attributed to: wired, then Wi-Fi, then mobile data, as a phone that has several
  // routes up (for example Wi-Fi and mobile data) uses the first of those for most traffic
  final String type;
  // every connection the phone reported, e.g. ['wifi', 'vpn']
  final List<String> interfaces;
  // true if a VPN is among the reported connections (its traffic is carried by another provider's network)
  final bool vpnReported;

  const NetworkContext({required this.type, required this.interfaces, required this.vpnReported});

  static const NetworkContext unknown =
      NetworkContext(type: NetworkType.unknown, interfaces: [], vpnReported: false);

  // Reads the phone's current connections. Never throws and never waits long: if the phone does not answer the
  // type is "unknown" and the measurement is still recorded.
  static Future<NetworkContext> capture({Future<List<ConnectivityResult>> Function()? check}) async {
    try {
      final results = await (check ?? Connectivity().checkConnectivity)().timeout(const Duration(seconds: 2));
      return fromResults(results);
    } catch (e) {
      debugPrint('[NETWORK_CONTEXT] Could not read the connection type: $e');
      return unknown;
    }
  }

  static NetworkContext fromResults(List<ConnectivityResult> results) {
    if (results.isEmpty) return unknown;
    bool has(ConnectivityResult r) => results.contains(r);
    final String type;
    if (has(ConnectivityResult.ethernet)) {
      type = NetworkType.ethernet;
    } else if (has(ConnectivityResult.wifi)) {
      type = NetworkType.wifi;
    } else if (has(ConnectivityResult.mobile)) {
      type = NetworkType.cellular;
    } else if (has(ConnectivityResult.bluetooth)) {
      type = NetworkType.bluetooth;
    } else if (has(ConnectivityResult.none)) {
      type = NetworkType.none;
    } else {
      // vpn-only or "other": the underlying network is not known
      type = NetworkType.other;
    }
    final names = results.map(_nameOf).toSet().toList()..sort();
    return NetworkContext(type: type, interfaces: names, vpnReported: has(ConnectivityResult.vpn));
  }

  static String _nameOf(ConnectivityResult r) => r == ConnectivityResult.mobile ? NetworkType.cellular : r.name;

  // The field stored on a measurement. [atEnd] is the connection after the test; if it is a different type than at
  // the start, `changed_during_test` is true.
  Map<String, dynamic> toMeasurementField({NetworkContext? atEnd}) => {
        'type': type,
        'interfaces': interfaces,
        'vpn_reported': vpnReported,
        'changed_during_test': atEnd != null && atEnd.type != type,
      };
}
