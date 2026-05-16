/// SignalNav - Route Segment Model
///
/// Represents a single leg or segment of a navigation route,
/// with traffic overlay data and signal prediction integration.

import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'intersection.dart';
import 'prediction.dart';

part 'route_segment.g.dart';

/// A point in a polyline with elevation support.
@JsonSerializable()
@immutable
class GeoPoint {
  final double lat;
  final double lng;
  final double? elevation;

  const GeoPoint({
    required this.lat,
    required this.lng,
    this.elevation,
  });

  factory GeoPoint.fromJson(Map<String, dynamic> json) =>
      _$GeoPointFromJson(json);

  Map<String, dynamic> toJson() => _$GeoPointToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lng == other.lng;

  @override
  int get hashCode => lat.hashCode ^ lng.hashCode;
}

/// Turn instruction for audio guidance.
enum TurnType {
  straight,
  slightLeft,
  left,
  sharpLeft,
  slightRight,
  right,
  sharpRight,
  uTurn,
  roundabout,
  destination,
}

/// A navigation instruction.
@JsonSerializable()
@immutable
class TurnInstruction {
  final TurnType type;
  final String text;
  final double? distanceMeters;
  final double? durationSeconds;

  const TurnInstruction({
    required this.type,
    required this.text,
    this.distanceMeters,
    this.durationSeconds,
  });

  factory TurnInstruction.fromJson(Map<String, dynamic> json) =>
      _$TurnInstructionFromJson(json);

  Map<String, dynamic> toJson() => _$TurnInstructionToJson(this);

  /// Audio-friendly text (concise, no visual-only references).
  String get audioText {
    // Remove parentheticals, "on the right/left" visual cues that confuse audio
    return text
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

/// Traffic condition overlay for a segment.
enum TrafficCondition {
  freeFlow,
  light,
  moderate,
  heavy,
  blocked,
  unknown,
}

/// A segment of a route with traffic and signal data.
@JsonSerializable()
@immutable
class RouteSegment {
  final String id;

  /// Ordered list of points forming the segment polyline
  final List<GeoPoint> polyline;

  /// Distance in meters
  final double distanceMeters;

  /// Estimated duration in seconds (without traffic)
  final double durationSeconds;

  /// Estimated duration with traffic
  final double? durationWithTrafficSeconds;

  /// Turn instruction at the start of this segment
  final TurnInstruction? instruction;

  /// Speed limit for this segment (mph)
  final int? speedLimitMph;

  /// Traffic condition
  final TrafficCondition trafficCondition;

  /// Intersection at the end of this segment, if any
  final Intersection? endIntersection;

  /// Signal prediction for the end intersection
  final SignalPrediction? signalPrediction;

  /// Road name
  final String? roadName;

  const RouteSegment({
    required this.id,
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
    this.durationWithTrafficSeconds,
    this.instruction,
    this.speedLimitMph,
    this.trafficCondition = TrafficCondition.unknown,
    this.endIntersection,
    this.signalPrediction,
    this.roadName,
  });

  factory RouteSegment.fromJson(Map<String, dynamic> json) =>
      _$RouteSegmentFromJson(json);

  Map<String, dynamic> toJson() => _$RouteSegmentToJson(this);

  RouteSegment copyWith({
    String? id,
    List<GeoPoint>? polyline,
    double? distanceMeters,
    double? durationSeconds,
    double? durationWithTrafficSeconds,
    TurnInstruction? instruction,
    int? speedLimitMph,
    TrafficCondition? trafficCondition,
    Intersection? endIntersection,
    SignalPrediction? signalPrediction,
    String? roadName,
  }) =>
      RouteSegment(
        id: id ?? this.id,
        polyline: polyline ?? this.polyline,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        durationWithTrafficSeconds:
            durationWithTrafficSeconds ?? this.durationWithTrafficSeconds,
        instruction: instruction ?? this.instruction,
        speedLimitMph: speedLimitMph ?? this.speedLimitMph,
        trafficCondition: trafficCondition ?? this.trafficCondition,
        endIntersection: endIntersection ?? this.endIntersection,
        signalPrediction: signalPrediction ?? this.signalPrediction,
        roadName: roadName ?? this.roadName,
      );

  /// Whether traffic data has significantly changed vs [other].
  bool hasTrafficChangedSignificantly(RouteSegment other) {
    if (trafficCondition != other.trafficCondition) return true;
    if (durationWithTrafficSeconds == null ||
        other.durationWithTrafficSeconds == null) {
      return false;
    }
    final diff = (durationWithTrafficSeconds! - other.durationWithTrafficSeconds!)
        .abs();
    final threshold = durationSeconds * 0.20; // 20% change
    return diff > threshold;
  }

  /// Decode an encoded polyline string (Google polyline encoding algorithm).
  static List<GeoPoint> decodePolyline(String encoded) {
    final points = <GeoPoint>[];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(GeoPoint(lat: lat / 1e5, lng: lng / 1e5));
    }

    return points;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteSegment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A complete route composed of segments.
@JsonSerializable()
@immutable
class Route {
  final String id;
  final List<RouteSegment> segments;
  final double totalDistanceMeters;
  final double totalDurationSeconds;
  final double? totalDurationWithTrafficSeconds;
  final DateTime calculatedAt;

  const Route({
    required this.id,
    required this.segments,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    this.totalDurationWithTrafficSeconds,
    required this.calculatedAt,
  });

  factory Route.fromJson(Map<String, dynamic> json) => _$RouteFromJson(json);

  Map<String, dynamic> toJson() => _$RouteToJson(this);

  Route copyWith({
    String? id,
    List<RouteSegment>? segments,
    double? totalDistanceMeters,
    double? totalDurationSeconds,
    double? totalDurationWithTrafficSeconds,
    DateTime? calculatedAt,
  }) =>
      Route(
        id: id ?? this.id,
        segments: segments ?? this.segments,
        totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
        totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
        totalDurationWithTrafficSeconds:
            totalDurationWithTrafficSeconds ?? this.totalDurationWithTrafficSeconds,
        calculatedAt: calculatedAt ?? this.calculatedAt,
      );

  /// Check if traffic has changed significantly on any segment.
  bool hasSignificantTrafficChange(Route other) {
    if (segments.length != other.segments.length) return true;
    for (int i = 0; i < segments.length; i++) {
      if (segments[i].hasTrafficChangedSignificantly(other.segments[i])) {
        return true;
      }
    }
    return false;
  }

  /// Total distance in miles
  double get totalDistanceMiles => totalDistanceMeters / 1609.34;

  /// Total duration in minutes
  double get totalDurationMinutes => totalDurationSeconds / 60;
}
