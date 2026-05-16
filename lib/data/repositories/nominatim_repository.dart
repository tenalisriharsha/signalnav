/// SignalNav - Nominatim Repository
///
/// OpenStreetMap Nominatim geocoding.
/// Free, rate-limited. Cache results aggressively.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../core/logger.dart';

/// Geocoding result.
class GeocodeResult {
  final String displayName;
  final double lat;
  final double lng;
  final String? road;
  final String? city;
  final String? state;
  final String? country;
  final String? postcode;

  const GeocodeResult({
    required this.displayName,
    required this.lat,
    required this.lng,
    this.road,
    this.city,
    this.state,
    this.country,
    this.postcode,
  });
}

class NominatimRepository {
  final http.Client _client;
  final SharedPreferences? _prefs;

  NominatimRepository({http.Client? client, SharedPreferences? prefs})
      : _client = client ?? http.Client(),
        _prefs = prefs;

  /// Geocode a search query (e.g., "123 Main St, Springfield, IL").
  Future<List<GeocodeResult>> search(String query, {int limit = 5}) async {
    final cacheKey = 'nominatim_search:${Uri.encodeComponent(query)}:$limit';
    if (_prefs != null) {
      final cached = _prefs!.getString(cacheKey);
      if (cached != null) {
        try {
          return _parseSearchResults(jsonDecode(cached));
        } catch (_) {
          // Invalid cache
        }
      }
    }

    final url = Uri.parse(
      '$kNominatimBaseUrl/search?format=json&q=${Uri.encodeComponent(query)}&limit=$limit',
    );

    try {
      final response = await _client.get(
        url,
        headers: {'User-Agent': kNominatimUserAgent},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw NetworkException(
          'Nominatim search failed',
          statusCode: response.statusCode,
        );
      }

      final data = jsonDecode(response.body) as List<dynamic>;
      final results = _parseSearchResults(data);

      // Cache for 24 hours
      if (_prefs != null) {
        await _prefs!.setString(cacheKey, response.body);
      }

      logDebug(LogCategory.network, 'Nominatim search: $query (${results.length} results)');
      return results;
    } catch (e, st) {
      logError(LogCategory.network, 'Nominatim search failed: $e');
      throw NetworkException('Geocoding failed', stackTrace: st);
    }
  }

  /// Reverse geocode: coordinates to address.
  Future<GeocodeResult?> reverseGeocode(double lat, double lng) async {
    final cacheKey = 'nominatim_rev:${lat.toStringAsFixed(5)}:${lng.toStringAsFixed(5)}';
    if (_prefs != null) {
      final cached = _prefs!.getString(cacheKey);
      if (cached != null) {
        try {
          return _parseReverseResult(jsonDecode(cached));
        } catch (_) {
          // Invalid cache
        }
      }
    }

    final url = Uri.parse(
      '$kNominatimBaseUrl/reverse?format=json&lat=$lat&lon=$lng',
    );

    try {
      final response = await _client.get(
        url,
        headers: {'User-Agent': kNominatimUserAgent},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw NetworkException(
          'Nominatim reverse geocode failed',
          statusCode: response.statusCode,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final result = _parseReverseResult(data);

      if (_prefs != null && result != null) {
        await _prefs!.setString(cacheKey, response.body);
      }

      logDebug(LogCategory.network, 'Reverse geocode: $lat, $lng');
      return result;
    } catch (e, st) {
      logError(LogCategory.network, 'Reverse geocode failed: $e');
      throw NetworkException('Reverse geocoding failed', stackTrace: st);
    }
  }

  List<GeocodeResult> _parseSearchResults(List<dynamic> data) {
    return data.map((item) {
      final map = item as Map<String, dynamic>;
      return GeocodeResult(
        displayName: map['display_name'] ?? 'Unknown',
        lat: double.tryParse(map['lat']?.toString() ?? '') ?? 0.0,
        lng: double.tryParse(map['lon']?.toString() ?? '') ?? 0.0,
        road: map['address']?['road'],
        city: map['address']?['city'] ?? map['address']?['town'],
        state: map['address']?['state'],
        country: map['address']?['country'],
        postcode: map['address']?['postcode'],
      );
    }).toList();
  }

  GeocodeResult? _parseReverseResult(Map<String, dynamic> data) {
    if (data.containsKey('error')) return null;
    final address = data['address'] as Map<String, dynamic>? ?? {};
    return GeocodeResult(
      displayName: data['display_name'] ?? 'Unknown',
      lat: double.tryParse(data['lat']?.toString() ?? '') ?? 0.0,
      lng: double.tryParse(data['lon']?.toString() ?? '') ?? 0.0,
      road: address['road'],
      city: address['city'] ?? address['town'],
      state: address['state'],
      country: address['country'],
      postcode: address['postcode'],
    );
  }
}
