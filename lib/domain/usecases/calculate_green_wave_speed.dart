/// SignalNav - Calculate Green Wave Speed Use Case (GLOSA)
///
/// Calculates optimal speed to arrive at a green signal.
/// HARD SAFETY RULES:
/// - Never suggest speeds above posted limit + 5mph
/// - For actuated signals, speak ranges only
/// - If no prediction, assume red and advise caution
/// - NEVER show ticking countdown timers

import '../../core/constants.dart';
import '../../core/logger.dart';
import '../../data/models/prediction.dart';
import '../../data/models/route_segment.dart';
import '../../utils/safety_validator.dart';

/// Result of green wave calculation.
class GreenWaveResult {
  /// Recommended speed (mph), or null if should maintain limit
  final double? recommendedSpeedMph;

  /// Seconds until green window, or null if unknown/actuated
  final int? secondsUntilGreen;

  /// Minimum wait time for actuated signals
  final int? typicalWaitMinSeconds;

  /// Maximum wait time for actuated signals
  final int? typicalWaitMaxSeconds;

  /// Human-readable audio message
  final String audioMessage;

  /// Whether this is an actuated range (no precise countdown)
  final bool isRangeEstimate;

  const GreenWaveResult({
    this.recommendedSpeedMph,
    this.secondsUntilGreen,
    this.typicalWaitMinSeconds,
    this.typicalWaitMaxSeconds,
    required this.audioMessage,
    this.isRangeEstimate = false,
  });
}

class CalculateGreenWaveSpeed {
  final SafetyValidator _safety;

  CalculateGreenWaveSpeed(this._safety);

  /// Calculate GLOSA recommendation for approaching [segment].
  ///
  /// [currentSpeedMph] - current GPS speed
  /// [distanceToIntersectionMeters] - remaining distance to end of segment
  GreenWaveResult call({
    required RouteSegment segment,
    required double currentSpeedMph,
    required double distanceToIntersectionMeters,
  }) {
    final prediction = segment.signalPrediction;
    final speedLimit = segment.speedLimitMph ?? 30;

    // No prediction: assume red, advise caution
    if (prediction == null) {
      logSafety('No prediction for ${segment.id}; advising caution');
      return GreenWaveResult(
        audioMessage: kPromptApproachUnknown,
      );
    }

    // Schedule changed: predictions frozen
    if (prediction.predictionType == PredictionType.relearning) {
      return GreenWaveResult(
        audioMessage: kPromptRelearning,
      );
    }

    // Insufficient data
    if (prediction.predictionType == PredictionType.insufficient) {
      return GreenWaveResult(
        audioMessage: kPromptApproachUnknown,
      );
    }

    // Actuated signal: range only, NO precise countdown
    if (prediction.predictionType == PredictionType.actuatedRange) {
      final minWait = prediction.typicalWaitMinSeconds;
      final maxWait = prediction.typicalWaitMaxSeconds;

      if (minWait != null && maxWait != null) {
        final msg = kPromptActuatedRange
            .replaceAll('%min%', minWait.toString())
            .replaceAll('%max%', maxWait.toString());
        return GreenWaveResult(
          typicalWaitMinSeconds: minWait,
          typicalWaitMaxSeconds: maxWait,
          audioMessage: msg,
          isRangeEstimate: true,
        );
      }

      return GreenWaveResult(
        audioMessage: kPromptApproachUnknown,
        isRangeEstimate: true,
      );
    }

    // Coordinated signal with precise prediction
    final now = DateTime.now().toUtc();
    final secs = prediction.secondsUntilGreen(now);

    if (secs == null || secs <= 0) {
      return GreenWaveResult(
        audioMessage: kPromptApproachUnknown,
      );
    }

    // Calculate optimal speed
    final distanceMiles = distanceToIntersectionMeters / 1609.34;
    final hoursToGreen = secs / 3600.0;
    final calculatedSpeedMph = distanceMiles / hoursToGreen;

    // SAFETY: clamp to speed limit
    final safeSpeed = _safety.clampGLOSApeed(calculatedSpeedMph, speedLimit.toDouble());

    if (safeSpeed == null) {
      // Would require speeding - advise maintaining limit
      final msg = kPromptMaintainSpeedLimit.replaceAll(
        '%seconds%',
        secs.toString(),
      );
      return GreenWaveResult(
        secondsUntilGreen: secs,
        audioMessage: msg,
      );
    }

    // Only advise speed change if it differs meaningfully from current
    final speedDiff = safeSpeed - currentSpeedMph;
    if (speedDiff.abs() < 3) {
      // Already at good speed
      final msg = kPromptMaintainSpeedLimit.replaceAll(
        '%seconds%',
        secs.toString(),
      );
      return GreenWaveResult(
        recommendedSpeedMph: safeSpeed,
        secondsUntilGreen: secs,
        audioMessage: msg,
      );
    }

    final direction = speedDiff > 0 ? 'speed up slightly to' : 'slow slightly to';
    final msg =
        'Next green in approximately $secs seconds. $direction ${safeSpeed.round()} miles per hour.';

    return GreenWaveResult(
      recommendedSpeedMph: safeSpeed,
      secondsUntilGreen: secs,
      audioMessage: msg,
    );
  }
}
