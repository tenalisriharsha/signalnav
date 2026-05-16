/// SignalNav - Intersection Entity
///
/// Represents a traffic signal intersection with metadata for routing
/// and prediction purposes.

import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'intersection.g.dart';

/// Types of traffic signal control systems.
enum SignalType {
  /// Pre-timed fixed cycle
  preTimed,

  /// Coordinated actuated (responds to traffic but within a network pattern)
  coordinatedActuated,

  /// Fully actuated (responds only to detected traffic)
  fullyActuated,

  /// Unknown or unclassified
  unknown,
}

/// Confidence status for display badges.
enum ConfidenceStatus {
  high,
  medium,
  low,
}

/// A traffic signal intersection.
@JsonSerializable()
@immutable
class Intersection {
  final String id;
  final double lat;
  final double lng;
  final String roadName;
  final String crossStreet;
  final SignalType signalType;
  final int speedLimitMph;
  final List<String> phases;
  final ConfidenceStatus confidenceStatus;
  final DateTime lastUpdated;

  const Intersection({
    required this.id,
    required this.lat,
    required this.lng,
    required this.roadName,
    required this.crossStreet,
    this.signalType = SignalType.unknown,
    required this.speedLimitMph,
    this.phases = const [],
    this.confidenceStatus = ConfidenceStatus.low,
    required this.lastUpdated,
  });

  factory Intersection.fromJson(Map<String, dynamic> json) =>
      _$IntersectionFromJson(json);

  Map<String, dynamic> toJson() => _$IntersectionToJson(this);

  Intersection copyWith({
    String? id,
    double? lat,
    double? lng,
    String? roadName,
    String? crossStreet,
    SignalType? signalType,
    int? speedLimitMph,
    List<String>? phases,
    ConfidenceStatus? confidenceStatus,
    DateTime? lastUpdated,
  }) =>
      Intersection(
        id: id ?? this.id,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        roadName: roadName ?? this.roadName,
        crossStreet: crossStreet ?? this.crossStreet,
        signalType: signalType ?? this.signalType,
        speedLimitMph: speedLimitMph ?? this.speedLimitMph,
        phases: phases ?? this.phases,
        confidenceStatus: confidenceStatus ?? this.confidenceStatus,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );

  /// Display name for UI
  String get displayName => '$roadName & $crossStreet';

  /// Check if this intersection is within [radiusMeters] of [latitude, longitude].
  bool isNear(double latitude, double longitude, double radiusMeters) {
    // Simple haversine approximation for small distances
    const double earthRadiusM = 6371000;
    final dLat = _toRadians(latitude - lat);
    final dLon = _toRadians(longitude - lng);
    final a =
        (dLat / 2) * (dLat / 2) +
        _cosRadians(lat) * _cosRadians(latitude) * (dLon / 2) * (dLon / 2);
    final c = 2 * _atan2Sqrt(a.toDouble());
    final distance = earthRadiusM * c;
    return distance <= radiusMeters;
  }

  static double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;
  static double _cosRadians(double degrees) => _toRadians(degrees).cos;
  static double _atan2Sqrt(double a) {
    // atan2(sqrt(a), sqrt(1-a))
    return _customAtan2(a.sqrt, ((1 - a).clamp(0, 1) as double).sqrt);
  }

  static double _customAtan2(double y, double x) {
    // Simple atan2 approximation for distance check
    if (x > 0) return _atan(y / x);
    if (x < 0) return (y >= 0 ? 3.141592653589793 : -3.141592653589793) + _atan(y / x);
    if (y > 0) return 1.5707963267948966;
    if (y < 0) return -1.5707963267948966;
    return 0;
  }

  static double _atan(double x) {
    // Taylor series approximation for atan, good enough for small angles
    // which is all we need for nearby intersections
    return x - x * x * x / 3 + x * x * x * x * x / 5;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Intersection &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// Extension for math helpers
extension _DoubleMath on double {
  double get sqrt {
    if (this <= 0) return 0;
    double x = this;
    double prev;
    do {
      prev = x;
      x = (x + this / x) / 2;
    } while ((x - prev).abs() > 0.0001);
    return x;
  }

  double get cos {
    // cos(x) using Taylor series
    final x = this % (2 * 3.141592653589793);
    double result = 1;
    double term = 1;
    for (int n = 1; n <= 10; n++) {
      term *= -x * x / ((2 * n - 1) * (2 * n));
      result += term;
    }
    return result;
  }
}
