// Checks that say how far a measurement can be trusted: was the phone on a VPN (so the test shows the VPN company's
// network, not the person's own provider), and was the position faked (so the coordinates may be made up).
//
// Every check has three outcomes: true, false, or null for "could not tell" (the plugin failed, timed out, or
// location permission was not granted). null is never turned into false, because "not checked" and "checked and
// clean" are different things when the data is looked at later.
//
// The checks are soft signals, not proof: VPN detection can miss some tunnels, and mock-location detection is
// strongest on Android and can be beaten on a rooted phone. They are meant to flag measurements for review, never to
// delete them.

import 'dart:async';

import 'package:detect_fake_location/detect_fake_location.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vpn_connection_detector/vpn_connection_detector.dart';

import 'network_context.dart';

// the reasons a measurement can be flagged (stored in `integrity_flags`)
class IntegrityFlag {
  static const String vpn = 'vpn';
  static const String mockLocation = 'mock_location';
  static const String networkChanged = 'network_changed';
  static const String vpnUnchecked = 'vpn_unchecked';
  static const String mockUnchecked = 'mock_location_unchecked';
}

class IntegritySignals {
  // what the VPN plugin said (null = it could not tell)
  final bool? vpnDetected;
  // whether the phone's connection report included a VPN (see NetworkContext)
  final bool vpnReported;
  // whether the network type could be read at all, so `vpnReported == false` means something
  final bool networkKnown;
  // the position's own "mocked" marker, and the fake-location plugin's answer (null = could not tell)
  final bool? positionMocked;
  final bool? pluginMock;

  const IntegritySignals({
    this.vpnDetected,
    this.vpnReported = false,
    this.networkKnown = false,
    this.positionMocked,
    this.pluginMock,
  });

  // true if any signal says VPN; false if something checked and nothing said VPN; null if nothing could check
  bool? get vpnUsed {
    if (vpnDetected == true || vpnReported) return true;
    if (vpnDetected == false || networkKnown) return false;
    return null;
  }

  // true if either source says the position is fake; false if something checked and neither did; null if neither
  // could check
  bool? get mockLocation {
    if (positionMocked == true || pluginMock == true) return true;
    if (positionMocked == false || pluginMock == false) return false;
    return null;
  }

  // The result of two readings of the same test (before and after it): a VPN or fake position at either time counts.
  IntegritySignals mergedWith(IntegritySignals other) => IntegritySignals(
        vpnDetected: _or(vpnDetected, other.vpnDetected),
        vpnReported: vpnReported || other.vpnReported,
        networkKnown: networkKnown || other.networkKnown,
        positionMocked: _or(positionMocked, other.positionMocked),
        pluginMock: _or(pluginMock, other.pluginMock),
      );

  static bool? _or(bool? a, bool? b) {
    if (a == true || b == true) return true;
    if (a == null && b == null) return null;
    return false;
  }

  // Why this measurement should be looked at before it is relied on; empty when nothing is wrong.
  List<String> flags({bool networkChanged = false}) => [
        if (vpnUsed == true) IntegrityFlag.vpn,
        if (mockLocation == true) IntegrityFlag.mockLocation,
        if (networkChanged) IntegrityFlag.networkChanged,
        if (vpnUsed == null) IntegrityFlag.vpnUnchecked,
        if (mockLocation == null) IntegrityFlag.mockUnchecked,
      ];

  // the fields stored on a measurement
  Map<String, dynamic> toMeasurementFields({bool networkChanged = false}) => {
        'vpn_used': vpnUsed,
        'mock_location': mockLocation,
        'integrity_flags': flags(networkChanged: networkChanged),
      };
}

class IntegrityChecks {
  final Future<bool> Function() _vpnCheck;
  final Future<bool> Function() _mockCheck;
  final Future<bool> Function() _locationPermitted;

  // the plugins by default; tests pass their own
  IntegrityChecks({
    Future<bool> Function()? vpnCheck,
    Future<bool> Function()? mockCheck,
    Future<bool> Function()? locationPermitted,
  })  : _vpnCheck = vpnCheck ?? VpnConnectionDetector.isVpnActive,
        _mockCheck = mockCheck ?? (() => DetectFakeLocation().detectFakeLocation()),
        _locationPermitted = locationPermitted ?? _defaultLocationPermitted;

  static final IntegrityChecks instance = IntegrityChecks();

  static Future<bool> _defaultLocationPermitted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  static const Duration _timeout = Duration(seconds: 3);

  Future<bool?> vpnActive() async {
    try {
      return await _vpnCheck().timeout(_timeout);
    } catch (e) {
      debugPrint('[INTEGRITY] VPN check failed: $e');
      return null;
    }
  }

  // The fake-location plugin asks for location permission itself when it does not have it, which would pop a
  // permission prompt in the middle of saving a measurement; so it is only used when permission is already granted.
  Future<bool?> pluginMockLocation() async {
    try {
      if (!await _locationPermitted().timeout(_timeout)) return null;
      return await _mockCheck().timeout(_timeout);
    } catch (e) {
      debugPrint('[INTEGRITY] Fake-location check failed: $e');
      return null;
    }
  }

  // Reads every signal now. [network] is the connection reading taken at the same moment; [position] is the fix
  // the measurement is stored with (its own marker is the most direct evidence about that fix).
  Future<IntegritySignals> capture({NetworkContext? network, Position? position}) async {
    final results = await Future.wait([vpnActive(), pluginMockLocation()]);
    return IntegritySignals(
      vpnDetected: results[0],
      vpnReported: network?.vpnReported ?? false,
      networkKnown: network != null && network.type != NetworkType.unknown,
      positionMocked: position?.isMocked,
      pluginMock: results[1],
    );
  }
}
