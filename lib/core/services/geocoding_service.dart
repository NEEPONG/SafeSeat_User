import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Service for reverse geocoding coordinates (lat, lng) to human-readable place names.
/// Uses OpenStreetMap Nominatim with in-memory caching to optimize API requests.
class GeocodingService {
  static final Map<String, String> _cache = {};

  /// Reverse geocodes [lat] and [lng] into a clean, concise place name.
  /// Returns cached result if available. Returns null on network error or empty result.
  static Future<String?> reverseGeocode(double lat, double lng) async {
    if (lat == 0.0 && lng == 0.0) return null;

    // Cache key rounded to 5 decimal places (~1.1 meter accuracy)
    final cacheKey = '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'SafeSeatMiniApp/1.0',
          'Accept-Language': 'th,en',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        final displayName = data['display_name'] as String?;

        String? formattedPlace;

        if (address != null) {
          // 1. Specific POI / Landmark / Building
          final poi = address['amenity'] ??
              address['building'] ??
              address['shop'] ??
              address['tourism'] ??
              address['leisure'] ??
              address['office'] ??
              address['historic'] ??
              address['aeroway'] ??
              address['railway'];

          final road = address['road'] ?? address['pedestrian'] ?? address['footway'];
          final suburb = address['suburb'] ??
              address['neighbourhood'] ??
              address['quarter'] ??
              address['subdistrict'];
          final city = address['city'] ??
              address['town'] ??
              address['municipality'] ??
              address['district'] ??
              address['province'];

          if (poi != null && poi.toString().trim().isNotEmpty) {
            final poiStr = poi.toString().trim();
            if (suburb != null && suburb.toString().trim().isNotEmpty && !poiStr.contains(suburb.toString().trim())) {
              formattedPlace = '$poiStr, ${suburb.toString().trim()}';
            } else if (road != null && road.toString().trim().isNotEmpty && !poiStr.contains(road.toString().trim())) {
              formattedPlace = '$poiStr, ${road.toString().trim()}';
            } else {
              formattedPlace = poiStr;
            }
          } else {
            // 2. Road & Suburb / City
            final parts = <String>[];
            if (road != null && road.toString().trim().isNotEmpty) {
              parts.add(road.toString().trim());
            }
            if (suburb != null && suburb.toString().trim().isNotEmpty) {
              parts.add(suburb.toString().trim());
            }
            if (parts.isEmpty && city != null && city.toString().trim().isNotEmpty) {
              parts.add(city.toString().trim());
            }

            if (parts.isNotEmpty) {
              formattedPlace = parts.join(', ');
            }
          }
        }

        // 3. Fallback to first 2 parts of display_name
        if ((formattedPlace == null || formattedPlace.trim().isEmpty) &&
            displayName != null &&
            displayName.trim().isNotEmpty) {
          final rawParts = displayName.split(',');
          formattedPlace = rawParts
              .take(2)
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .join(', ');
        }

        if (formattedPlace != null && formattedPlace.trim().isNotEmpty) {
          final cleanResult = formattedPlace.trim();
          _cache[cacheKey] = cleanResult;
          return cleanResult;
        }
      }
    } catch (e) {
      debugPrint('GeocodingService reverseGeocode error: $e');
    }

    return null;
  }

  /// Convenience wrapper for [LatLng]
  static Future<String?> reverseGeocodeLatLng(LatLng latLng) {
    return reverseGeocode(latLng.latitude, latLng.longitude);
  }
}
