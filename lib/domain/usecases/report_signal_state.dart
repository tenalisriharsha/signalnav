/// SignalNav - Report Signal State Use Case
///
/// Handles the full flow of submitting a crowdsourced signal report:
/// 1. Validates the report
/// 2. Anonymizes user data
/// 3. Checks safety (no manual reports while moving unless passenger mode)
/// 4. Submits to Firestore

import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../core/logger.dart';
import '../../data/models/signal_report.dart';
import '../../data/repositories/signal_repository.dart';
import '../../data/services/location_service.dart';
import '../../utils/privacy_anonymizer.dart';
import '../../utils/safety_validator.dart';

class ReportSignalState {
  final SignalRepository _repository;
  final SafetyValidator _safety;
  final LocationService _location;

  ReportSignalState(this._repository, this._safety, this._location);

  /// Submit a signal report.
  ///
  /// [intersectionId] - which intersection
  /// [phase] - which traffic phase
  /// [color] - observed signal color
  /// [isVoiceOrBluetooth] - true if triggered by voice/Bluetooth; false if manual UI
  ///
  /// Throws [SafetyViolationException] if manual report while moving.
  Future<void> call({
    required String intersectionId,
    required String phase,
    required SignalColor color,
    required bool isVoiceOrBluetooth,
    required String userId,
  }) async {
    // Safety check: manual UI reports blocked while moving
    if (!isVoiceOrBluetooth) {
      try {
        _safety.assertCanInteractManually();
      } on SafetyViolationException {
        logSafety(
          'Manual signal report blocked: moving at ${_safety.currentSpeedMph.toStringAsFixed(1)} mph',
        );
        rethrow;
      }
    }

    // Get current location/speed for metadata
    final location = _location.lastLocation;
    final gpsSpeed = location?.speedMph;

    // Anonymize: hash the user ID
    final deviceHash = PrivacyAnonymizer.hashUserId(userId);

    final report = SignalReport(
      intersectionId: intersectionId,
      phase: phase,
      color: color,
      timestamp: DateTime.now().toUtc(),
      deviceHash: deviceHash,
      gpsSpeedAtReportMph: gpsSpeed,
      trustScore: 1.0, // Default; backend adjusts based on history
    );

    await _repository.submitReport(report);

    logInfo(
      LogCategory.signal,
      'Signal report submitted: $intersectionId $phase $color',
    );
  }
}
