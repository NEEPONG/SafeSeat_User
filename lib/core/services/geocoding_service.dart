import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Service for reverse geocoding coordinates (lat, lng) to human-readable place names.
/// Uses OpenStreetMap Nominatim. All callers share a cache and a single request
/// queue so even simultaneous screens respect the public service's rate limit.
class GeocodingService {
  static final Map<String, String> _cache = {};
  static final Map<String, Future<String?>> _inFlight = {};
  static final Map<String, int> _failedUntilMs = {};
  static final Stopwatch _clock = Stopwatch()..start();
  static Future<void> _queueTail = Future<void>.value();
  static int? _lastRequestStartMs;
  static Duration _minimumRequestSpacing = const Duration(seconds: 1);
  static Duration _failureCooldown = const Duration(seconds: 10);
  static Future<http.Response> Function(Uri, Map<String, String>) _httpGet =
      _defaultHttpGet;

  static Future<http.Response> _defaultHttpGet(
    Uri url,
    Map<String, String> headers,
  ) => http.get(url, headers: headers);

  /// Reverse geocodes [lat] and [lng] into a clean, concise place name.
  /// Returns null for invalid coordinates or when the service has no place name.
  /// Failed lookups cool down briefly, then may be retried.
  static Future<String?> reverseGeocode(double lat, double lng) {
    if (!lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180 ||
        (lat == 0 && lng == 0)) {
      return Future<String?>.value(null);
    }

    // Cache key rounded to 5 decimal places (~1.1 meter accuracy)
    final cacheKey = '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
    final cached = _cache[cacheKey];
    if (cached != null) return Future<String?>.value(cached);

    final pending = _inFlight[cacheKey];
    if (pending != null) return pending;

    final failedUntil = _failedUntilMs[cacheKey];
    if (failedUntil != null) {
      if (_clock.elapsedMilliseconds < failedUntil) {
        return Future<String?>.value(null);
      }
      _failedUntilMs.remove(cacheKey);
    }

    // Chaining the whole request serializes network calls as well as their
    // starts. Other screens can join this future for the same coordinates.
    final request = _queueTail.then((_) async {
      try {
        final lastStart = _lastRequestStartMs;
        if (lastStart != null) {
          final waitMs =
              _minimumRequestSpacing.inMilliseconds -
              (_clock.elapsedMilliseconds - lastStart);
          if (waitMs > 0) {
            await Future<void>.delayed(Duration(milliseconds: waitMs));
          }
        }
        _lastRequestStartMs = _clock.elapsedMilliseconds;
        final place = await _fetchPlace(lat, lng);
        if (place == null) {
          _failedUntilMs[cacheKey] =
              _clock.elapsedMilliseconds + _failureCooldown.inMilliseconds;
        } else {
          _cache[cacheKey] = place;
          _failedUntilMs.remove(cacheKey);
        }
        return place;
      } catch (error) {
        debugPrint('GeocodingService reverseGeocode error: $error');
        _failedUntilMs[cacheKey] =
            _clock.elapsedMilliseconds + _failureCooldown.inMilliseconds;
        return null;
      } finally {
        _inFlight.remove(cacheKey);
      }
    });
    _inFlight[cacheKey] = request;
    _queueTail = request.then<void>((_) {});
    return request;
  }

  static Future<String?> _fetchPlace(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );

      final response = await _httpGet(url, {
        'User-Agent': 'SafeSeatMiniApp/1.0',
        'Accept-Language': 'th,en',
      }).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        final displayName = data['display_name'] as String?;

        String? formattedPlace;

        if (address != null) {
          // 1. Specific POI / Landmark / Building
          final poi =
              address['amenity'] ??
              address['building'] ??
              address['shop'] ??
              address['tourism'] ??
              address['leisure'] ??
              address['office'] ??
              address['historic'] ??
              address['aeroway'] ??
              address['railway'];

          final road =
              address['road'] ?? address['pedestrian'] ?? address['footway'];
          final suburb =
              address['suburb'] ??
              address['neighbourhood'] ??
              address['quarter'] ??
              address['subdistrict'];
          final city =
              address['city'] ??
              address['town'] ??
              address['municipality'] ??
              address['district'] ??
              address['province'];

          if (poi != null && poi.toString().trim().isNotEmpty) {
            final poiStr = poi.toString().trim();
            if (suburb != null &&
                suburb.toString().trim().isNotEmpty &&
                !poiStr.contains(suburb.toString().trim())) {
              formattedPlace = '$poiStr, ${suburb.toString().trim()}';
            } else if (road != null &&
                road.toString().trim().isNotEmpty &&
                !poiStr.contains(road.toString().trim())) {
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
            if (parts.isEmpty &&
                city != null &&
                city.toString().trim().isNotEmpty) {
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

  /// Replaces the HTTP transport and resets transient state for isolated tests.
  /// Only call while no reverse-geocoding request is pending.
  @visibleForTesting
  static void configureForTesting({
    required Future<http.Response> Function(Uri, Map<String, String>) request,
    Duration minimumRequestSpacing = const Duration(seconds: 1),
    Duration failureCooldown = const Duration(seconds: 10),
  }) {
    assert(_inFlight.isEmpty);
    _httpGet = request;
    _minimumRequestSpacing = minimumRequestSpacing;
    _failureCooldown = failureCooldown;
    _cache.clear();
    _failedUntilMs.clear();
    _queueTail = Future<void>.value();
    _lastRequestStartMs = null;
  }

  @visibleForTesting
  static void resetForTesting() {
    configureForTesting(request: _defaultHttpGet);
  }
}
