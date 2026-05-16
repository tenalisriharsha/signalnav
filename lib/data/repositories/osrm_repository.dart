/// SignalNav - OSRM Repository
///
/// Open Source Routing Machine integration.
/// Self-hosted via Docker for completely free, offline-capable routing.
/// Falls back to GraphHopper Directions API if OSRM unavailable.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/env_config.dart';
import '../../core/errors.dart';
import '../../core/logger.dart';
import '../models/route_segment.dart';

/// OSRM route response.
class OsrmRouteResult {
  final Route route;
  final bool fromCache;

  OsrmRouteResult({required this.route, this.fromCache = false});
}

class OsrmRepository {
  final http.Client _client;
  final SharedPreferences? _prefs;

  OsrmRepository({http.Client? client, SharedPreferences? prefs})
      : _client = client ?? http.Client(),
        _prefs = prefs;

  /// Calculate a driving route between two points.
  ///
  /// [fromLat], [fromLng] - start coordinates
  /// [toLat], [toLng] - destination coordinates
  /// [alternatives] - number of alternative routes to request
  Future<OsrmRouteResult> getRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    int alternatives = 0,
  }) async {
    // Check cache first
    final cacheKey = _cacheKey(fromLat, fromLng, toLat, toLng);
    if (_prefs != null) {
      final cached = _prefs!.getString(cacheKey);
      if (cached != null) {
        try {
          final json = jsonDecode(cached) as Map<String, dynamic>;
          final route = _parseOsrmResponse(json);
          logInfo(LogCategory.navigation, 'Route served from cache');
          return OsrmRouteResult(route: route, fromCache: true);
        } catch (_) {
          // Invalid cache, continue to fetch
        }
      }
    }

    // Build OSRM request
    final coords = '$fromLng,$fromLat;$toLng,$toLat';
    final url = Uri.parse(
      '$kOsrmBaseUrl/route/v1/driving/$coords'
      '?overview=full&geometries=polyline&alternatives=$alternatives&steps=true',
    );

    try {
      final response = await _client.get(url).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        throw NetworkException(
          'OSRM routing failed',
          statusCode: response.statusCode,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') {
        throw NetworkException('OSRM error: ${data['message']}');
      }

      final route = _parseOsrmResponse(data);

      // Cache the result
      if (_prefs != null) {
        await _prefs!.setString(cacheKey, response.body);
      }

      logInfo(LogCategory.navigation, 'Route fetched from OSRM');
      return OsrmRouteResult(route: route);
    } on NetworkException {
      rethrow;
    } catch (e, st) {
      logError(LogCategory.navigation, 'OSRM request failed: $e');
      // Try GraphHopper fallback
      return await _fallbackGraphHopper(fromLat, fromLng, toLat, toLng);
    }
  }

  Future<OsrmRouteResult> _fallbackGraphHopper(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) async {
    final apiKey = EnvConfig.graphHopperApiKey;
    if (apiKey == null || apiKey == 'YOUR_GRAPH_HOPPER_KEY') {
      throw const NetworkException(
        'OSRM unavailable and no GraphHopper API key configured',
      );
    }

    final url = Uri.parse(
      '${EnvConfig.graphHopperBaseUrl}/route?point=$fromLat,$fromLng&point=$toLat,$toLng'
      '&vehicle=car&locale=en&instructions=true&calc_points=true&key=$apiKey',
    );

    try {
      final response = await _client.get(url).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        throw NetworkException(
          'GraphHopper fallback failed',
          statusCode: response.statusCode,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final route = _parseGraphHopperResponse(data);

      logInfo(LogCategory.navigation, 'Route fetched from GraphHopper fallback');
      return OsrmRouteResult(route: route);
    } catch (e, st) {
      logError(LogCategory.navigation, 'GraphHopper fallback failed: $e');
      throw NetworkException(
        'All routing services unavailable',
        stackTrace: st,
      );
    }
  }

  Route _parseOsrmResponse(Map<String, dynamic> data) {
    final routes = data['routes'] as List<dynamic>;
    if (routes.isEmpty) {
      throw const ValidationException('No route found');
    }

    final routeData = routes.first as Map<String, dynamic>;
    final legs = routeData['legs'] as List<dynamic>;

    final segments = <RouteSegment>[];
    int segmentIndex = 0;

    for (final leg in legs) {
      final steps = leg['steps'] as List<dynamic>;
      for (final step in steps) {
        final stepData = step as Map<String, dynamic>;
        final geometry = stepData['geometry'] as String;
        final points = RouteSegment.decodePolyline(geometry);

        final maneuver = stepData['maneuver'] as Map<String, dynamic>;
        final type = _mapOsrmType(maneuver['type'] as String?);
        final instructionText = stepData['name'] as String? ?? 'Continue';

        segments.add(
          RouteSegment(
            id: 'seg_${segmentIndex++}',
            polyline: points,
            distanceMeters: (stepData['distance'] as num).toDouble(),
            durationSeconds: (stepData['duration'] as num).toDouble(),
            instruction: TurnInstruction(
              type: type,
              text: instructionText,
              distanceMeters: (stepData['distance'] as num).toDouble(),
              durationSeconds: (stepData['duration'] as num).toDouble(),
            ),
            roadName: stepData['name'] as String?,
          ),
        );
      }
    }

    return Route(
      id: 'route_${DateTime.now().millisecondsSinceEpoch}',
      segments: segments,
      totalDistanceMeters: (routeData['distance'] as num).toDouble(),
      totalDurationSeconds: (routeData['duration'] as num).toDouble(),
      calculatedAt: DateTime.now().toUtc(),
    );
  }

  Route _parseGraphHopperResponse(Map<String, dynamic> data) {
    final paths = data['paths'] as List<dynamic>;
    if (paths.isEmpty) {
      throw const ValidationException('No route found');
    }

    final path = paths.first as Map<String, dynamic>;
    final points = RouteSegment.decodePolyline(path['points'] as String);

    final instructions = path['instructions'] as List<dynamic>? ?? [];
    final segments = <RouteSegment>[];

    if (instructions.isEmpty) {
      segments.add(
        RouteSegment(
          id: 'seg_0',
          polyline: points,
          distanceMeters: (path['distance'] as num).toDouble(),
          durationSeconds: (path['time'] as num).toDouble() / 1000,
        ),
      );
    } else {
      for (int i = 0; i < instructions.length; i++) {
        final inst = instructions[i] as Map<String, dynamic>;
        segments.add(
          RouteSegment(
            id: 'seg_$i',
            polyline: [], // Simplified: full polyline in first segment
            distanceMeters: (inst['distance'] as num).toDouble(),
            durationSeconds: (inst['time'] as num).toDouble() / 1000,
            instruction: TurnInstruction(
              type: _mapGraphHopperType(inst['sign'] as int?),
              text: inst['text'] as String,
              distanceMeters: (inst['distance'] as num).toDouble(),
              durationSeconds: (inst['time'] as num).toDouble() / 1000,
            ),
          ),
        );
      }
      // Attach full polyline to first segment for display
      if (segments.isNotEmpty) {
        segments[0] = segments[0].copyWith(polyline: points);
      }
    }

    return Route(
      id: 'route_${DateTime.now().millisecondsSinceEpoch}',
      segments: segments,
      totalDistanceMeters: (path['distance'] as num).toDouble(),
      totalDurationSeconds: (path['time'] as num).toDouble() / 1000,
      calculatedAt: DateTime.now().toUtc(),
    );
  }

  TurnType _mapOsrmType(String? type) {
    switch (type) {
      case 'straight':
      case 'continue':
        return TurnType.straight;
      case 'turn':
      case 'end of road':
        return TurnType.straight;
      case 'uturn':
        return TurnType.uTurn;
      case 'roundabout':
      case 'rotary':
        return TurnType.roundabout;
      case 'depart':
        return TurnType.straight;
      case 'arrive':
        return TurnType.destination;
      default:
        return TurnType.straight;
    }
  }

  TurnType _mapGraphHopperType(int? sign) {
    switch (sign) {
      case -98:
        return TurnType.uTurn;
      case -3:
        return TurnType.sharpLeft;
      case -2:
        return TurnType.left;
      case -1:
        return TurnType.slightLeft;
      case 0:
        return TurnType.straight;
      case 1:
        return TurnType.slightRight;
      case 2:
        return TurnType.right;
      case 3:
        return TurnType.sharpRight;
      case 4:
        return TurnType.destination;
      case 5:
      case 6:
        return TurnType.roundabout;
      default:
        return TurnType.straight;
    }
  }

  String _cacheKey(double fLat, double fLng, double tLat, double tLng) {
    // Round to 4 decimal places (~11m) for cache matching
    final from = '${fLat.toStringAsFixed(4)},${fLng.toStringAsFixed(4)}';
    final to = '${tLat.toStringAsFixed(4)},${tLng.toStringAsFixed(4)}';
    return 'osrm_route:$from:$to';
  }

  /// Clear all cached routes.
  Future<void> clearCache() async {
    if (_prefs == null) return;
    final keys = _prefs!.getKeys().where((k) => k.startsWith('osrm_route:'));
    for (final key in keys) {
      await _prefs!.remove(key);
    }
    logInfo(LogCategory.navigation, 'OSRM cache cleared');
  }
}
