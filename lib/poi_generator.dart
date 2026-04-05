// import files
import 'location_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

// This file contains functions for generating POIs using the OpenStreetMap Overpass API

class OverpassService {
  // The main Overpass API endpoint
  static const String _baseUrl = 'https://overpass-api.de/api/interpreter';
  // Main and mirror endpoints for better reliability
  /*static const List<String> _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.nchc.org.tw/api/interpreter',
  ];*/
  /// Fetches POIs around a location with retry and fallback logic
  Future<List<PointOfInterest>> fetchPOIs({
    required double latitude,
    required double longitude,
    required double radius,
    String? amenityType,
    Map<String, String>? tags,
    int? limit,
  }) async {
    final query = _buildQuery(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      amenityType: amenityType,
      tags: tags,
      limit: limit,
    );

    Exception? lastException;

    try {
      debugPrint("[POI_GENERATION]: Requesting from $_baseUrl");
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': query},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return _parseResponse(jsonData);
      } else if (response.statusCode == 429) {
        debugPrint("[POI_GENERATION]: Rate limited on $_baseUrl");
      } else {
        lastException = Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("[POI_GENERATION]: Error with $_baseUrl: $e");
      lastException = e is Exception ? e : Exception(e.toString());
    }


    throw lastException ?? Exception('Failed to load POIs from all available servers');
  }

  /// Fetches the nearest POIs to a location, sorted by distance
  Future<List<PointOfInterest>> fetchNearestPOIs({
    required double latitude,
    required double longitude,
    required double radius,
    String? amenityType,
    Map<String, String>? tags,
    int limit = 10,
  }) async {
    debugPrint("[POI_GENERATION]: Fetching nearest POIs.");
    
    // Fetch a pool of candidates (double the limit)
    final pois = await fetchPOIs(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      amenityType: amenityType,
      tags: tags,
      limit: limit * 2, 
    );

    // Calculate distance for each POI
    for (var poi in pois) {
      poi.distanceFromOrigin = _calculateDistance(
        latitude,
        longitude,
        poi.latitude,
        poi.longitude,
      );
    }

    // Sort by distance (nearest first)
    pois.sort((a, b) => a.distanceFromOrigin!.compareTo(b.distanceFromOrigin!));

    return pois.take(limit).toList();
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  String _buildQuery({
    required double latitude,
    required double longitude,
    required double radius,
    String? amenityType,
    Map<String, String>? tags,
    int? limit,
  }) {
    String tagFilters = '';
    if (amenityType != null) tagFilters += '["amenity"="$amenityType"]';
    if (tags != null) {
      for (var entry in tags.entries) {
        tagFilters += '["${entry.key}"="${entry.value}"]';
      }
    }
    if (tagFilters.isEmpty) tagFilters = '["name"]';

    return '''
      [out:json][timeout:30];
      nwr$tagFilters(around:$radius,$latitude,$longitude);
      out center ${limit ?? ''};
    '''.trim();
  }

  List<PointOfInterest> _parseResponse(Map<String, dynamic> jsonData) {
    final elements = jsonData['elements'] as List<dynamic>? ?? [];

    return elements.map((element) {
      final lat = element['lat'] ?? element['center']?['lat'];
      final lon = element['lon'] ?? element['center']?['lon'];
      final tags = element['tags'] as Map<String, dynamic>? ?? {};

      return PointOfInterest(
        id: element['id'].toString(),
        latitude: lat?.toDouble() ?? 0.0,
        longitude: lon?.toDouble() ?? 0.0,
        name: tags['name'] ?? 'Unnamed',
        amenityType: tags['amenity'] ?? tags['shop'] ?? tags['tourism'] ?? 'poi',
        tags: Map<String, String>.from(tags),
      );
    }).toList();
  }
}

class PointOfInterest {
  final String id, name, amenityType;
  final double latitude, longitude;
  final Map<String, String> tags;
  double? distanceFromOrigin;

  PointOfInterest({
    required this.id, required this.latitude, required this.longitude,
    required this.name, required this.amenityType, required this.tags,
  });
}

class PoiListGenerator {
  double user_longitude = 0.0;
  double user_latitude = 0.0;
  double max_distance = 1500; // Increased default slightly to 1.5km

  Future<List<PointOfInterest>> generatePOIList(int listSize) async {
    try {
      await _getCurrentLocation();
      return await _callOverpassAPI(listSize);
    } catch (e) {
      debugPrint("[POI_GENERATOR] Final error: $e");
      return [];
    }
  }

  Future<void> _getCurrentLocation() async {
    // Add a timeout to location fetching to prevent hanging
    final loc = await determineLocationData().timeout(const Duration(seconds: 10));
    user_longitude = loc.position.longitude;
    user_latitude = loc.position.latitude;
  }

  Future<List<PointOfInterest>> _callOverpassAPI(int numPois) async {
    final service = OverpassService();
    final results = await service.fetchNearestPOIs(
      latitude: user_latitude,
      longitude: user_longitude,
      radius: max_distance,
      limit: numPois,
    );
    
    if (results.isEmpty) {
      debugPrint("[POI_GENERATOR] No POIs found. Radius might be too small.");
    }
    return results;
  }
}
