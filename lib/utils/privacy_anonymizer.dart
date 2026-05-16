/// SignalNav - Privacy Anonymizer
///
/// Strips all PII from data before it leaves the device or before it is
/// stored in shared/aggregated collections. This is a hard requirement:
/// ZERO raw GPS storage beyond 24 hours, ZERO user IDs in public datasets.

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Privacy settings that prevent any analytics export to third parties.
/// Monetization must be via future premium features, never data resale.
class PrivacySettings {
  /// Whether to allow any network analytics at all
  final bool allowAnalytics;

  /// Whether crash reporting is enabled
  final bool allowCrashReporting;

  /// Whether to share anonymized signal reports
  final bool allowCrowdsourcing;

  const PrivacySettings({
    this.allowAnalytics = false,
    this.allowCrashReporting = true,
    this.allowCrowdsourcing = true,
  });

  PrivacySettings copyWith({
    bool? allowAnalytics,
    bool? allowCrashReporting,
    bool? allowCrowdsourcing,
  }) =>
      PrivacySettings(
        allowAnalytics: allowAnalytics ?? this.allowAnalytics,
        allowCrashReporting: allowCrashReporting ?? this.allowCrashReporting,
        allowCrowdsourcing: allowCrowdsourcing ?? this.allowCrowdsourcing,
      );

  Map<String, dynamic> toJson() => {
    'allowAnalytics': allowAnalytics,
    'allowCrashReporting': allowCrashReporting,
    'allowCrowdsourcing': allowCrowdsourcing,
  };

  factory PrivacySettings.fromJson(Map<String, dynamic> json) =>
      PrivacySettings(
        allowAnalytics: json['allowAnalytics'] ?? false,
        allowCrashReporting: json['allowCrashReporting'] ?? true,
        allowCrowdsourcing: json['allowCrowdsourcing'] ?? true,
      );
}

/// Central anonymization utility.
class PrivacyAnonymizer {
  /// Hash a Firebase Auth UID to a deterministic but irreversible device hash.
  /// Used for trust scoring internally; exposed ONLY as hashed IDs.
  static String hashUserId(String uid) {
    final bytes = utf8.encode(uid);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16); // Use first 16 chars for brevity
  }

  /// Round coordinates to reduce precision (~100m accuracy) for logging.
  static Map<String, double> fuzzCoordinates(double lat, double lng) {
    return {
      'lat': (lat * 1000).roundToDouble() / 1000,
      'lng': (lng * 1000).roundToDouble() / 1000,
    };
  }

  /// Strip all PII from a raw GPS trace before any storage or transmission.
  /// Only retain what is necessary for signal prediction.
  static Map<String, dynamic> anonymizeGpsTrace({
    required String intersectionId,
    required String phase,
    required String signalColor,
    required DateTime timestamp,
    required String hashedDeviceId,
    double? gpsSpeedAtReportMph,
    String? approachDirection,
  }) {
    return {
      'intersection_id': intersectionId,
      'phase': phase,
      'color': signalColor,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'device_hash': hashedDeviceId,
      if (gpsSpeedAtReportMph != null)
        'gps_speed_at_report_mph': gpsSpeedAtReportMph,
      if (approachDirection != null) 'approach_direction': approachDirection,
    };
  }

  /// Verify that a data object contains no obvious PII keys.
  /// Used in debug mode as a safety net.
  static bool containsPii(Map<String, dynamic> data) {
    final forbiddenKeys = [
      'uid',
      'user_id',
      'email',
      'phone',
      'name',
      'device_id',
      'raw_lat',
      'raw_lng',
      'latitude',
      'longitude',
      'exact_location',
    ];

    for (final key in data.keys) {
      final lower = key.toLowerCase();
      if (forbiddenKeys.contains(lower)) {
        return true;
      }
    }
    return false;
  }

  /// Sanitize a map by removing forbidden keys entirely.
  static Map<String, dynamic> sanitizeMap(Map<String, dynamic> data) {
    final forbiddenKeys = {
      'uid',
      'user_id',
      'email',
      'phone',
      'name',
      'device_id',
      'raw_lat',
      'raw_lng',
      'exact_location',
    };

    return Map<String, dynamic>.fromEntries(
      data.entries.where((e) => !forbiddenKeys.contains(e.key.toLowerCase())),
    );
  }
}
