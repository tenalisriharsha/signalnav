/// SignalNav - Get Optimal Route Use Case
///
/// Calculates a route with traffic overlay, respecting the constraint:
/// Never recalculate route audibly more than once per 30 seconds.

import 'dart:async';
import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../core/logger.dart';
import '../../data/models/route_segment.dart';
import '../../data/repositories/osrm_repository.dart';
import '../../data/repositories/tomtom_repository.dart';

class GetOptimalRoute {
  final OsrmRepository _osrm;
  final TomTomRepository _tomtom;

  DateTime? _lastRecalcTime;
  Route? _lastRoute;

  GetOptimalRoute(this._osrm, this._tomtom);

  /// Get route from [fromLat, fromLng] to [toLat, toLng].
  ///
  /// If [force] is true, bypasses the 30-second recalculation limit.
  /// Use [force] only for explicit user actions (e.g., "recalculate" button
  /// pressed by passenger).
  Future<Route> call({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    bool force = false,
  }) async {
    // Enforce minimum recalculation interval
    if (!force && _lastRecalcTime != null) {
      final elapsed = DateTime.now().difference(_lastRecalcTime!).inSeconds;
      if (elapsed < kMinRouteRecalcIntervalSeconds) {
        logInfo(
          LogCategory.navigation,
          'Route recalculation blocked: $elapsed < $kMinRouteRecalcIntervalSeconds seconds',
        );
        if (_lastRoute != null) {
          return _lastRoute!;
        }
      }
    }

    try {
      // Fetch route from OSRM
      final result = await _osrm.getRoute(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
      );

      Route route = result.route;

      // Overlay traffic (enhancement only; never blocks route)
      try {
        final bounds = _computeBounds(route);
        final traffic = await _tomtom.getTrafficFlow(
          minLat: bounds['minLat']!,
          minLng: bounds['minLng']!,
          maxLat: bounds['maxLat']!,
          maxLng: bounds['maxLng']!,
        );

        final segmentsWithTraffic = _tomtom.applyTrafficToSegments(
          route.segments,
          traffic,
        );

        route = route.copyWith(segments: segmentsWithTraffic);
      } catch (e) {
        // Traffic is enhancement-only; log and continue with base route
        logWarning(LogCategory.navigation, 'Traffic overlay failed: $e');
      }

      // Check if traffic changed significantly vs last route
      if (_lastRoute != null &&
          !route.hasSignificantTrafficChange(_lastRoute!) &&
          !force) {
        logInfo(LogCategory.navigation, 'Traffic unchanged; using cached route');
        return _lastRoute!;
      }

      _lastRecalcTime = DateTime.now();
      _lastRoute = route;

      logInfo(
        LogCategory.navigation,
        'Route calculated: ${route.totalDistanceMiles.toStringAsFixed(1)} mi, '
        '${route.totalDurationMinutes.toStringAsFixed(1)} min',
      );
      return route;
    } catch (e, st) {
      logError(LogCategory.navigation, 'Route calculation failed: $e');
      if (_lastRoute != null) {
        logWarning(LogCategory.navigation, 'Returning stale cached route');
        return _lastRoute!;
      }
      throw UnexpectedException(
        'Unable to calculate route',
        stackTrace: st,
      );
    }
  }

  Map<String, double> _computeBounds(Route route) {
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final segment in route.segments) {
      for (final point in segment.polyline) {
        if (point.lat < minLat) minLat = point.lat;
        if (point.lat > maxLat) maxLat = point.lat;
        if (point.lng < minLng) minLng = point.lng;
        if (point.lng > maxLng) maxLng = point.lng;
      }
    }
    // Add padding
    final pad = 0.01; // ~1km
    return {
      'minLat': minLat - pad,
      'maxLat': maxLat + pad,
      'minLng': minLng - pad,
      'maxLng': maxLng + pad,
    };
  }

  /// Clear cached route (e.g., after destination change).
  void clearCache() {
    _lastRoute = null;
    _lastRecalcTime = null;
  }
}
