/// SignalNav - Signal Report Model
///
/// A crowdsourced report of a traffic signal's current state.
/// When stored in Firestore, this is anonymized per PrivacyAnonymizer.
/// Raw reports are auto-deleted after 24 hours by a scheduled function.

import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'signal_report.g.dart';

/// Valid signal colors that can be reported.
enum SignalColor {
  red,
  yellow,
  green,
  unknown,
}

/// A single crowdsourced signal report.
@JsonSerializable()
@immutable
class SignalReport {
  /// Intersection identifier
  final String intersectionId;

  /// Traffic phase (e.g., "NB_through", "SB_left")
  final String phase;

  /// Observed signal color
  final SignalColor color;

  /// UTC timestamp of observation
  final DateTime timestamp;

  /// Hashed device identifier (NOT the raw Firebase UID)
  final String deviceHash;

  /// GPS speed at time of report (mph)
  final double? gpsSpeedAtReportMph;

  /// Direction of approach (cardinal or relative)
  final String? approachDirection;

  /// Trust score of the reporting device at time of report
  final double trustScore;

  const SignalReport({
    required this.intersectionId,
    required this.phase,
    required this.color,
    required this.timestamp,
    required this.deviceHash,
    this.gpsSpeedAtReportMph,
    this.approachDirection,
    this.trustScore = 1.0,
  });

  factory SignalReport.fromJson(Map<String, dynamic> json) =>
      _$SignalReportFromJson(json);

  Map<String, dynamic> toJson() => _$SignalReportToJson(this);

  SignalReport copyWith({
    String? intersectionId,
    String? phase,
    SignalColor? color,
    DateTime? timestamp,
    String? deviceHash,
    double? gpsSpeedAtReportMph,
    String? approachDirection,
    double? trustScore,
  }) =>
      SignalReport(
        intersectionId: intersectionId ?? this.intersectionId,
        phase: phase ?? this.phase,
        color: color ?? this.color,
        timestamp: timestamp ?? this.timestamp,
        deviceHash: deviceHash ?? this.deviceHash,
        gpsSpeedAtReportMph: gpsSpeedAtReportMph ?? this.gpsSpeedAtReportMph,
        approachDirection: approachDirection ?? this.approachDirection,
        trustScore: trustScore ?? this.trustScore,
      );

  /// Convert color to a human-readable string.
  String get colorLabel {
    switch (color) {
      case SignalColor.red:
        return 'Red';
      case SignalColor.yellow:
        return 'Yellow';
      case SignalColor.green:
        return 'Green';
      case SignalColor.unknown:
        return 'Unknown';
    }
  }

  /// Whether this report is fresh enough for live prediction.
  bool isFresh({DateTime? referenceTime, Duration maxAge = const Duration(hours: 24)}) {
    final ref = referenceTime ?? DateTime.now().toUtc();
    return ref.difference(timestamp) <= maxAge;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignalReport &&
          runtimeType == other.runtimeType &&
          intersectionId == other.intersectionId &&
          phase == other.phase &&
          timestamp == other.timestamp &&
          deviceHash == other.deviceHash;

  @override
  int get hashCode =>
      intersectionId.hashCode ^
      phase.hashCode ^
      timestamp.hashCode ^
      deviceHash.hashCode;
}
