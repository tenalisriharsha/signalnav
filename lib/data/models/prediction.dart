/// SignalNav - Signal Prediction Model
///
/// Represents an aggregated, public-read prediction for a signal phase.
/// These are computed by backend Python Cloud Functions.

import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'intersection.dart';

part 'prediction.g.dart';

/// Type of prediction based on signal control type and data quality.
enum PredictionType {
  /// Coordinated signal with reliable cycle length
  coordinated,

  /// Actuated signal - only a range estimate is possible
  actuatedRange,

  /// Insufficient data for any prediction
  insufficient,

  /// Signal schedule recently changed, re-learning
  relearning,
}

/// An aggregated signal prediction.
@JsonSerializable()
@immutable
class SignalPrediction {
  final String intersectionId;
  final String phase;

  /// Time bucket this prediction applies to (e.g., "13:00-13:30")
  final String timeBucket;

  /// Estimated cycle length in seconds (null for actuated)
  final int? cycleLengthSeconds;

  /// Predicted next green start time
  final DateTime? greenStartPrediction;

  /// Confidence score 0.0-1.0
  final double confidence;

  /// Type of prediction
  final PredictionType predictionType;

  /// For actuated signals: typical wait range
  final int? typicalWaitMinSeconds;
  final int? typicalWaitMaxSeconds;

  final DateTime updatedAt;

  const SignalPrediction({
    required this.intersectionId,
    required this.phase,
    required this.timeBucket,
    this.cycleLengthSeconds,
    this.greenStartPrediction,
    required this.confidence,
    required this.predictionType,
    this.typicalWaitMinSeconds,
    this.typicalWaitMaxSeconds,
    required this.updatedAt,
  });

  factory SignalPrediction.fromJson(Map<String, dynamic> json) =>
      _$SignalPredictionFromJson(json);

  Map<String, dynamic> toJson() => _$SignalPredictionToJson(this);

  SignalPrediction copyWith({
    String? intersectionId,
    String? phase,
    String? timeBucket,
    int? cycleLengthSeconds,
    DateTime? greenStartPrediction,
    double? confidence,
    PredictionType? predictionType,
    int? typicalWaitMinSeconds,
    int? typicalWaitMaxSeconds,
    DateTime? updatedAt,
  }) =>
      SignalPrediction(
        intersectionId: intersectionId ?? this.intersectionId,
        phase: phase ?? this.phase,
        timeBucket: timeBucket ?? this.timeBucket,
        cycleLengthSeconds: cycleLengthSeconds ?? this.cycleLengthSeconds,
        greenStartPrediction: greenStartPrediction ?? this.greenStartPrediction,
        confidence: confidence ?? this.confidence,
        predictionType: predictionType ?? this.predictionType,
        typicalWaitMinSeconds: typicalWaitMinSeconds ?? this.typicalWaitMinSeconds,
        typicalWaitMaxSeconds: typicalWaitMaxSeconds ?? this.typicalWaitMaxSeconds,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Derive confidence status for UI badges.
  ConfidenceStatus get confidenceStatus {
    if (confidence >= 0.75) return ConfidenceStatus.high;
    if (confidence >= 0.50) return ConfidenceStatus.medium;
    return ConfidenceStatus.low;
  }

  /// Human-readable description of the prediction.
  String get description {
    switch (predictionType) {
      case PredictionType.coordinated:
        final next = greenStartPrediction;
        if (next != null) {
          final secs = next.difference(DateTime.now().toUtc()).inSeconds;
          if (secs > 0) {
            return 'Next green in ~${secs}s';
          }
        }
        return 'Coordinated signal';
      case PredictionType.actuatedRange:
        if (typicalWaitMinSeconds != null && typicalWaitMaxSeconds != null) {
          return 'Typical wait: ${typicalWaitMinSeconds}s-${typicalWaitMaxSeconds}s';
        }
        return 'Actuated signal - range estimate';
      case PredictionType.insufficient:
        return 'Insufficient data for prediction';
      case PredictionType.relearning:
        return 'Schedule changed - re-learning';
    }
  }

  /// Whether this prediction is fresh enough to display.
  bool isFresh({Duration maxAge = const Duration(hours: 2)}) {
    return DateTime.now().toUtc().difference(updatedAt) <= maxAge;
  }

  /// Seconds until predicted green from [referenceTime].
  /// Returns null if no precise prediction available.
  int? secondsUntilGreen(DateTime referenceTime) {
    if (predictionType != PredictionType.coordinated ||
        greenStartPrediction == null) {
      return null;
    }
    final diff = greenStartPrediction!.difference(referenceTime).inSeconds;
    return diff > 0 ? diff : null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignalPrediction &&
          runtimeType == other.runtimeType &&
          intersectionId == other.intersectionId &&
          phase == other.phase &&
          timeBucket == other.timeBucket;

  @override
  int get hashCode =>
      intersectionId.hashCode ^ phase.hashCode ^ timeBucket.hashCode;
}
