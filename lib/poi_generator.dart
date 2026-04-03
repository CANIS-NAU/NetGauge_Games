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

  /// Fetches POIs around a location
  ///
  /// [latitude] and [longitude]: Center point for the search
  /// [radius]: Search radius in meters
  /// [amenityType]: Optional - Type of amenity (e.g., 'cafe', 'restaurant')
  /// [tags]: Optional - Additional tag filters (e.g., {'shop': 'supermarket'})
  /// [limit]: Optional - Limit the number of results from the server to prevent timeouts
  Future<List<PointOfInterest>> fetchPOIs({
    required double latitude,
    required double longitude,
    required double radius,
    String? amenityType,
    Map<String, String>? tags,
    int? limit,
  }) async {
    // Build the Overpass QL query
    final query = _buildQuery(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      amenityType: amenityType,
      tags: tags,
      limit: limit,
    );

    try {
      // Make the HTTP POST request
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': query},
      );

      if (response.statusCode == 200) {
        // Parse the JSON response
        final jsonData = json.decode(response.body);
        return _parseResponse(jsonData);
      } else {
        throw Exception('Failed to load POIs: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching POIs: $e');
    }
  }

  /// Fetches the nearest POIs to a location, sorted by distance
  ///
  /// [latitude] and [longitude]: Your current location
  /// [radius]: Maximum search radius in meters
  /// [limit]: Maximum number of results to return
  Future<List<PointOfInterest>> fetchNearestPOIs({
    required double latitude,
    required double longitude,
    required double radius,
    String? amenityType,
    Map<String, String>? tags,
    int limit = 10,
  }) async {
    debugPrint("[POI_GENERATION]: Fetching nearest POIs.");
    
    // We fetch a slightly larger pool (limit * 2) from the server to ensure 
    // we have enough candidates to sort locally for the truly "nearest".
    final pois = await fetchPOIs(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      amenityType: amenityType,
      tags: tags,
      limit: limit * 2, 
    );

    debugPrint("[POI_GENERATION]: Found ${pois.length} candidates.");

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

    // Return only the requested number of results
    return pois.take(limit).toList();
  }

  /// Calculates distance between two points using Haversine formula
  /// Returns distance in meters
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  /// Builds an Overpass QL query string
  String _buildQuery({
    required double latitude,
    required double longitude,
    required double radius,
    String? amenityType,
    Map<String, String>? tags,
    int? limit,
  }) {
    String tagFilters = '';
    if (amenityType != null) {
      tagFilters += '["amenity"="$amenityType"]';
    }

    if (tags != null) {
      for (var entry in tags.entries) {
        tagFilters += '["${entry.key}"="${entry.value}"]';
      }
    }

    // Default to everything with a name if no filter is provided
    if (tagFilters.isEmpty) {
      tagFilters = '["name"]';
    }

    // 'nwr' searches nodes, ways, and relations efficiently.
    // 'out center [limit]' is key to avoiding 504 timeouts on public servers.
    return '''
      [out:json][timeout:25];
      nwr$tagFilters(around:$radius,$latitude,$longitude);
      out center ${limit ?? ''};
    '''.trim();
  }

  List<PointOfInterest> _parseResponse(Map<String, dynamic> jsonData) {
    final elements = jsonData['elements'] as List<dynamic>;

    return elements.map((element) {
      final lat = element['lat'] ?? element['center']?['lat'];
      final lon = element['lon'] ?? element['center']?['lon'];
      final tags = element['tags'] as Map<String, dynamic>? ?? {};

      final amenityType = tags['amenity'] ??
          tags['shop'] ??
          tags['tourism'] ??
          tags['leisure'] ??
          'unknown';

      return PointOfInterest(
        id: element['id'].toString(),
        latitude: lat?.toDouble() ?? 0.0,
        longitude: lon?.toDouble() ?? 0.0,
        name: tags['name'] ?? 'Unnamed',
        amenityType: amenityType,
        tags: Map<String, String>.from(tags),
      );
    }).toList();
  }
}

class PointOfInterest {
  final String id;
  final double latitude;
  final double longitude;
  final String name;
  final String amenityType;
  final Map<String, String> tags;
  double? distanceFromOrigin;

  PointOfInterest({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.amenityType,
    required this.tags,
    this.distanceFromOrigin,
  });
}

class PoiListGenerator {
  double user_longitude = 0.0;
  double user_latitude = 0.0;
  double max_distance = 1000; // Search radius in meters (1km)

  Future<List<PointOfInterest>> generatePOIList(int listSize) async {
    try {
      await _getCurrentLocation();
      return await _callOverpassAPI(listSize);
    } catch (e) {
      debugPrint("[POI_GENERATOR] Error: $e");
      return [];
    }
  }

  Future<void> _getCurrentLocation() async {
    final loc = await determineLocationData();
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
    
    debugPrint("[POI_GENERATOR] Found ${results.length} POIs near user.");
    return results;
  }
}
