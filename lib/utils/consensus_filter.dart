/// SignalNav - Consensus Filter
///
/// Outlier rejection logic for crowdsourced signal reports.
///
/// Rules:
/// 1. If a single user reports "green" while >=3 others report "red"
///    within the same 60-second window, discard the outlier and reduce
///    that user's trust score.
/// 2. Minimum 3 agreeing reports before publishing a cycle length.
/// 3. Reports older than 7 days get 50% weight.
/// 4. Reports older than 30 days are archived, not used for live prediction.

import '../core/constants.dart';
import '../core/logger.dart';

/// A raw signal report for consensus evaluation.
class ReportForConsensus {
  final String deviceHash;
  final String color;
  final DateTime timestamp;
  final double trustScore;

  ReportForConsensus({
    required this.deviceHash,
    required this.color,
    required this.timestamp,
    this.trustScore = 1.0,
  });
}

/// Result of consensus evaluation for a set of reports.
class ConsensusResult {
  final String? dominantColor;
  final double confidence;
  final List<ReportForConsensus> acceptedReports;
  final List<ReportForConsensus> rejectedOutliers;
  final Map<String, double> trustScoreAdjustments;

  const ConsensusResult({
    this.dominantColor,
    required this.confidence,
    required this.acceptedReports,
    required this.rejectedOutliers,
    required this.trustScoreAdjustments,
  });
}

/// Consensus filter implementing the outlier rejection logic.
class ConsensusFilter {
  /// Evaluate a batch of reports for a specific intersection and phase.
  ///
  /// [referenceTime] is typically now, or the center of the time window.
  ConsensusResult evaluate(
    List<ReportForConsensus> reports, {
    required DateTime referenceTime,
  }) {
    final accepted = <ReportForConsensus>[];
    final rejected = <ReportForConsensus>[];
    final trustAdjustments = <String, double>{};

    if (reports.isEmpty) {
      return ConsensusResult(
        confidence: 0.0,
        acceptedReports: accepted,
        rejectedOutliers: rejected,
        trustScoreAdjustments: trustAdjustments,
      );
    }

    // Filter to the consensus window
    final windowReports =
        reports.where((r) {
          final diff = referenceTime.difference(r.timestamp).inSeconds.abs();
          return diff <= kConsensusWindowSeconds;
        }).toList();

    if (windowReports.isEmpty) {
      return ConsensusResult(
        confidence: 0.0,
        acceptedReports: accepted,
        rejectedOutliers: rejected,
        trustScoreAdjustments: trustAdjustments,
      );
    }

    // Count weighted votes by color
    final colorVotes = <String, double>{};
    for (final report in windowReports) {
      final weight = _calculateWeight(report, referenceTime);
      colorVotes[report.color] = (colorVotes[report.color] ?? 0) + weight;
    }

    // Find dominant color
    String? dominantColor;
    double maxVotes = 0;
    colorVotes.forEach((color, votes) {
      if (votes > maxVotes) {
        maxVotes = votes;
        dominantColor = color;
      }
    });

    // Identify outliers: reports that disagree with the dominant consensus
    if (dominantColor != null && windowReports.length >= 2) {
      final agreeingCount = windowReports
          .where((r) => r.color == dominantColor)
          .length;

      for (final report in windowReports) {
        if (report.color != dominantColor) {
          // Outlier: single user disagrees with >=3 others
          if (agreeingCount >= kConsensusMinAgreeingReports) {
            rejected.add(report);
            // Reduce trust score for outlier reporter
            trustAdjustments[report.deviceHash] =
                -(0.1 * (1.0 / report.trustScore.clamp(0.1, 10.0)));
            logSafety(
              'Outlier rejected: ${report.deviceHash} reported ${report.color} vs dominant $dominantColor',
            );
            continue;
          }
        }
        accepted.add(report);
      }
    } else {
      accepted.addAll(windowReports);
    }

    // Calculate confidence based on agreement and data freshness
    final confidence = _calculateConfidence(accepted, referenceTime);

    return ConsensusResult(
      dominantColor: dominantColor,
      confidence: confidence,
      acceptedReports: accepted,
      rejectedOutliers: rejected,
      trustScoreAdjustments: trustAdjustments,
    );
  }

  /// Calculate the weight of a report based on age and reporter trust.
  double _calculateWeight(ReportForConsensus report, DateTime referenceTime) {
    double weight = report.trustScore;

    final ageDays = referenceTime.difference(report.timestamp).inDays;
    if (ageDays >= kStaleDataArchiveDays) {
      weight = 0; // Archived, not used
    } else if (ageDays >= kStaleDataHalfLifeDays) {
      weight *= 0.5; // 50% weight after 7 days
    }

    return weight;
  }

  /// Calculate overall confidence of the consensus.
  double _calculateConfidence(
    List<ReportForConsensus> accepted,
    DateTime referenceTime,
  ) {
    if (accepted.isEmpty) return 0.0;

    // Base confidence from report count
    double countConfidence;
    if (accepted.length >= 20) {
      countConfidence = 1.0;
    } else if (accepted.length >= 10) {
      countConfidence = 0.7;
    } else if (accepted.length >= 3) {
      countConfidence = 0.4;
    } else {
      countConfidence = 0.2;
    }

    // Freshness factor: average age of reports
    double totalAgeHours = 0;
    for (final r in accepted) {
      totalAgeHours += referenceTime.difference(r.timestamp).inHours.abs();
    }
    final avgAgeHours = totalAgeHours / accepted.length;
    double freshnessFactor;
    if (avgAgeHours <= 1) {
      freshnessFactor = 1.0;
    } else if (avgAgeHours <= 6) {
      freshnessFactor = 0.9;
    } else if (avgAgeHours <= 24) {
      freshnessFactor = 0.7;
    } else {
      freshnessFactor = 0.5;
    }

    return (countConfidence * freshnessFactor).clamp(0.0, 1.0);
  }

  /// Check if there are enough agreeing reports to publish a cycle length.
  bool hasEnoughReportsForCycle(List<ReportForConsensus> reports) {
    return reports.length >= kMinReportsForCycle;
  }
}
