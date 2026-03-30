// import files
import 'location_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

class OverpassService {
  static const String _baseUrl = 'https://overpass-api.de/api/interpreter';

  Future<List<PointOfInterest>> fetchPOIs({
    required double latitude,
    required double longitude,
    required double radius,
    String? amenityType,
    Map<String, String>? tags,
  }) async {
    final query = _buildQuery(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      amenityType: amenityType,
      tags: tags,
    );

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': query},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return _parseResponse(jsonData);
      } else {
        throw Exception('Failed to load POIs: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching POIs: $e');
    }
  }

  Future<List<PointOfInterest>> fetchNearestPOIs({
    required double latitude,
    required double longitude,
    required double radius,
    String? amenityType,
    Map<String, String>? tags,
    int limit = 10,
  }) async {
    final pois = await fetchPOIs(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      amenityType: amenityType,
      tags: tags,
    );

    for (var poi in pois) {
      poi.distanceFromOrigin = _calculateDistance(
        latitude,
        longitude,
        poi.latitude,
        poi.longitude,
      );
    }

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
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  String _buildQuery({
    required double latitude,
    required double longitude,
    required double radius,
    String? amenityType,
    Map<String, String>? tags,
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
      [out:json][timeout:25];
      (
        node$tagFilters(around:$radius,$latitude,$longitude);
        way$tagFilters(around:$radius,$latitude,$longitude);
      );
      out center;
    ''';
  }

  List<PointOfInterest> _parseResponse(Map<String, dynamic> jsonData) {
    final elements = jsonData['elements'] as List<dynamic>;
    return elements.map((element) {
      final lat = element['lat'] ?? element['center']?['lat'];
      final lon = element['lon'] ?? element['center']?['lon'];
      final tags = element['tags'] as Map<String, dynamic>? ?? {};
      final amenityType = tags['amenity'] ?? tags['shop'] ?? tags['tourism'] ?? tags['leisure'] ?? 'unknown';

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

  PointOfInterest({required this.id, required this.latitude, required this.longitude, 
    required this.name, required this.amenityType, required this.tags, this.distanceFromOrigin});
}

class PoiListGenerator {
  double user_longitude = 0.0;
  double user_latitude = 0.0;
  double max_distance = 5000.0; // Changed to meters for Overpass API
  int num_pois = 0;

  Future<List<PointOfInterest>> generatePOIList(int listSize) async {
    num_pois = listSize;
    // FIXED: Must await location before moving to the next line
    await getCurrentLocation();
    
    debugPrint("[POI_GENERATOR]: Coordinates gathered: $user_latitude, $user_longitude");
    
    List<PointOfInterest> poiList = await callOverpassAPI(num_pois);
    return poiList;
  }

  Future<void> getCurrentLocation() async {
    final loc = await determineLocationData();
    user_longitude = loc.position.longitude;
    user_latitude = loc.position.latitude;
  }

  Future<List<PointOfInterest>> callOverpassAPI(int num_pois) async {
    final service = OverpassService();
    // FIXED: Must await the API call
    final allPois = await service.fetchNearestPOIs(
      latitude: user_latitude,
      longitude: user_longitude,
      radius: max_distance,
      limit: num_pois,
    );
    
    debugPrint("[POI_GENERATOR]: Successfully fetched ${allPois.length} POIs");
    return allPois;
  }
}
