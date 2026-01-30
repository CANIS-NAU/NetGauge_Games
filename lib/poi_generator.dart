// import files
import 'location_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

// This file will contain all functions for generating POIs

// I may move other POI related functions, like POICheck, here for clean code


// Reference for OSM API: https://wiki.openstreetmap.org/wiki/Overpass_API
// ^^ if Overpass API is too resource intensive, may switch to wikidata API
// Potential issue: People will likely use this when they have poor internet connection.
  // Should we download all POIs to a local database? Or every day, try to
  // install XX POIs from a radius of YY, search through that if location close enough
//^^ I will hold off on storing locally for now, but may revisit this later

// currently this is how it works
// Games have predefined lists of POIs that get sent to the flutter side
// So instead, what if we just send over the player's current location, and then generate POIs here?
// or even do that on the flutter side

// This class was written with the help of Claude
class OverpassService {
  // The main Overpass API endpoint
  static const String _baseUrl = 'https://overpass-api.de/api/interpreter';

  /// Fetches POIs around a location
  ///
  /// [latitude] and [longitude]: Center point for the search
  /// [radius]: Search radius in meters
  /// [amenityType]: Optional - Type of amenity (e.g., 'cafe', 'restaurant')
  /// [tags]: Optional - Additional tag filters (e.g., {'shop': 'supermarket'})
  ///
  /// If neither amenityType nor tags are provided, fetches ALL POIs with names
  Future<List<PointOfInterest>> fetchPOIs({
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    // Build the Overpass QL query
    final query = _buildQuery(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      //amenityType: amenityType,
      //tags: tags,
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
  /// [amenityType]: Optional - Type of amenity to search for
  /// [tags]: Optional - Additional tag filters
  /// [limit]: Maximum number of results to return (default: 10)
  ///
  /// If neither amenityType nor tags are provided, fetches ALL POIs with names
  Future<List<PointOfInterest>> fetchNearestPOIs({
    required double latitude,
    required double longitude,
    required double radius,
    int limit = 10,
  }) async {
    // First, get all POIs within the radius
    final pois = await fetchPOIs(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      //amenityType: amenityType,
      //tags: tags,
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
  ///
  /// This query searches for nodes and ways with specified tags
  /// within a radius of a given point
  String _buildQuery({
    required double latitude,
    required double longitude,
    required double radius,
    String? amenityType,
    Map<String, String>? tags,
  }) {
    // Build the tag filters
    String tagFilters = '';

    if (amenityType != null) {
      tagFilters += '["amenity"="$amenityType"]';
    }

    if (tags != null) {
      for (var entry in tags.entries) {
        tagFilters += '["${entry.key}"="${entry.value}"]';
      }
    }

    // If no filters specified, search for anything with a name
    // This gives you all POIs (shops, amenities, tourism spots, etc.)
    if (tagFilters.isEmpty) {
      tagFilters = '["name"]';
    }

    return '''
      [out:json][timeout:25];
      (
        node$tagFilters(around:$radius,$latitude,$longitude);
        way$tagFilters(around:$radius,$latitude,$longitude);
      );
      out center;
    ''';
  }

  /// Parses the Overpass API response into POI objects
  List<PointOfInterest> _parseResponse(Map<String, dynamic> jsonData) {
    final elements = jsonData['elements'] as List<dynamic>;

    return elements.map((element) {
      // Extract coordinates (different for nodes vs ways)
      final lat = element['lat'] ?? element['center']?['lat'];
      final lon = element['lon'] ?? element['center']?['lon'];

      // Extract tags (all the descriptive information)
      final tags = element['tags'] as Map<String, dynamic>? ?? {};

      // Try to determine the type of POI
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

/// Represents a Point of Interest from OpenStreetMap
class PointOfInterest {
  final String id;
  final double latitude;
  final double longitude;
  final String name;
  final String amenityType;
  final Map<String, String> tags; // All OSM tags for this POI

  // Distance from the search origin (calculated after fetching)
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

  @override
  String toString() {
    final distanceStr = distanceFromOrigin != null
        ? ' - ${distanceFromOrigin!.toStringAsFixed(0)}m away'
        : '';
    return 'POI: $name ($amenityType) at ($latitude, $longitude)$distanceStr';
  }
}

class PoiListGenerator {
  // each of these get reset as subsequent functions are called
  double user_longitude = 0.0;
  double user_latitude = 0.0;

  // this needs to get reset when the class is called, but default can be 5K
  double max_distance = 5000; // kilometers
  int num_pois = 0; // reset when class is initialized

  Future<List<PointOfInterest>> generatePOIList(int list_size) async{
    num_pois = list_size;
    await getCurrentLocation();
    List<PointOfInterest> poiList = await callOverpassAPI();
    return poiList;
  }


  /*
  Function Name: getCurrentLocation
  Input:
  Output: None, this is a get and set function
  Dependencies:
  Description: Sets the coordinate points for user
   */
  Future<void> getCurrentLocation() async {
    final loc = await determineLocationData();
    user_longitude = loc.position.longitude;
    user_latitude = loc.position.latitude;
  }

  /*
  Function Name: callOverpassAPI
  Input:
  Output:
  Dependencies:
  Description: Calls the Overpass API to access POIs from Open Street Map
   */
  Future<List<PointOfInterest>> callOverpassAPI() async{
    // start service, call instance of class
    final service = await OverpassService();
    final allPOIs = service.fetchNearestPOIs(
      latitude: user_latitude,
      longitude: user_longitude,
      radius: max_distance, //kilometers
      limit: num_pois,
    );
    debugPrint("[POI_GENERATOR] Printing allPOIs");
    debugPrint("[POI_GENERATOR] POIs: $allPOIs");
    return allPOIs;
  }
}