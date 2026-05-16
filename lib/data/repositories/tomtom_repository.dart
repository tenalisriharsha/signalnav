/// SignalNav - TomTom Traffic Repository
///
/// Enhancement-only live traffic overlay.
/// Free tier: 2,500 requests/day. Cache aggressively (5 min per tile).

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/env_config.dart';
import '../../core/errors.dart';
import '../../core/logger.dart';
import '../models/route_segment.dart';

/// Traffic flow data for a bounding box.
class TrafficFlowData {
  final String segmentId;
  final TrafficCondition condition;
  final double? currentSpeed;
  final double? freeFlowSpeed;
  final double confidence;

  const TrafficFlowData({
    required this.segmentId,
    required this.condition,
    this.currentSpeed,
    this.freeFlowSpeed,
    this.confidence = 0.0,
  });
}

class TomTomRepository {
  final http.Client _client;
  final SharedPreferences? _prefs;

  TomTomRepository({http.Client? client, SharedPreferences? prefs})
      : _client = client ?? http.Client(),
        _prefs = prefs;

  /// Fetch traffic flow for a bounding box.
  ///
  /// [minLat], [minLng], [maxLat], [maxLng] - bounding box coordinates
  Future<List<TrafficFlowData>> getTrafficFlow({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
  }) async {
    final apiKey = EnvConfig.tomTomApiKey;
    if (apiKey == null || apiKey == 'YOUR_TOMTOM_KEY') {
      logWarning(LogCategory.network, 'TomTom API key not configured');
      return [];
    }

    final cacheKey = _cacheKey(minLat, minLng, maxLat, maxLng);
    if (_prefs != null) {
      final cached = _prefs!.getString(cacheKey);
      final cachedTime = _prefs!.getInt('${cacheKey}_time');
      if (cached != null &&
          cachedTime != null &&
          DateTime.now().millisecondsSinceEpoch - cachedTime <
              kTrafficCacheMinutes * 60 * 1000) {
        try {
          return _parseFlowResponse(jsonDecode(cached));
        } catch (_) {
          // Invalid cache
        }
      }
    }

    final bbox = '$minLng,$minLat,$maxLng,$maxLat';
    final url = Uri.parse(
      '${EnvConfig.tomTomTrafficBaseUrl}/flowSegmentData/absolute/10/json'
      '?key=$apiKey&bbox=$bbox',
    );

    try {
      final response = await _client.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        throw NetworkException(
          'TomTom traffic request failed',
          statusCode: response.statusCode,
        );
      }

      final data = jsonDecode(response.body);
      final result = _parseFlowResponse(data);

      // Cache result
      if (_prefs != null) {
        await _prefs!.setString(cacheKey, response.body);
        await _prefs!.setInt(
          '${cacheKey}_time',
          DateTime.now().millisecondsSinceEpoch,
        );
      }

      logDebug(LogCategory.network, 'Traffic flow fetched for bbox: $bbox');
      return result;
    } catch (e, st) {
      logError(LogCategory.network, 'TomTom traffic failed: $e');
      // Traffic is enhancement-only; return empty on failure
      return [];
    }
  }

  /// Apply traffic data to route segments (simplified overlay).
  List<RouteSegment> applyTrafficToSegments(
    List<RouteSegment> segments,
    List<TrafficFlowData> trafficData,
  ) {
    // Simplified: match by road name or nearest traffic segment
    // In production, this would use precise polyline matching
    return segments.map((segment) {
      final matched = trafficData.where((t) {
        // Very simplified matching
        return true;
      }).toList();

      if (matched.isEmpty) return segment;

      // Average the traffic conditions
      final avgCondition = _averageCondition(
        matched.map((t) => t.condition).toList(),
      );

      return segment.copyWith(trafficCondition: avgCondition);
    }).toList();
  }

  List<TrafficFlowData> _parseFlowResponse(dynamic data) {
    final flowSegmentData = data['flowSegmentData'];
    if (flowSegmentData == null) return [];

    final condition = _mapTomTomCondition(
      flowSegmentData['confidence'] as double? ?? 0.0,
      flowSegmentData['currentSpeed'] as double? ?? 0.0,
      flowSegmentData['freeFlowSpeed'] as double? ?? 0.0,
    );

    return [
      TrafficFlowData(
        segmentId: flowSegmentData['@version']?.toString() ?? 'unknown',
        condition: condition,
        currentSpeed: (flowSegmentData['currentSpeed'] as num?)?.toDouble(),
        freeFlowSpeed: (flowSegmentData['freeFlowSpeed'] as num?)?.toDouble(),
        confidence: (flowSegmentData['confidence'] as num?)?.toDouble() ?? 0.0,
      ),
    ];
  }

  TrafficCondition _mapTomTomCondition(
    double confidence,
    double currentSpeed,
    double freeFlowSpeed,
  ) {
    if (freeFlowSpeed <= 0 || confidence < 0.5) return TrafficCondition.unknown;
    final ratio = currentSpeed / freeFlowSpeed;
    if (ratio > 0.9) return TrafficCondition.freeFlow;
    if (ratio > 0.7) return TrafficCondition.light;
    if (ratio > 0.5) return TrafficCondition.moderate;
    if (ratio > 0.2) return TrafficCondition.heavy;
    return TrafficCondition.blocked;
  }

  TrafficCondition _averageCondition(List<TrafficCondition> conditions) {
    if (conditions.isEmpty) return TrafficCondition.unknown;
    final values = conditions.map((c) => c.index).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    return TrafficCondition.values[avg.round().clamp(0, 5)];
  }

  String _cacheKey(double minLat, double minLng, double maxLat, double maxLng) {
    final bbox =
        '${minLat.toStringAsFixed(3)},${minLng.toStringAsFixed(3)},${maxLat.toStringAsFixed(3)},${maxLng.toStringAsFixed(3)}';
    return 'tomtom_traffic:$bbox';
  }
}
