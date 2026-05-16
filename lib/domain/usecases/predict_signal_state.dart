/// SignalNav - Predict Signal State Use Case
///
/// Retrieves the current prediction for an intersection.
/// Frontend counterpart to the backend Python cycle estimator.

import '../../core/errors.dart';
import '../../core/logger.dart';
import '../../data/models/prediction.dart';
import '../../data/repositories/signal_repository.dart';

class PredictSignalState {
  final SignalRepository _repository;

  PredictSignalState(this._repository);

  /// Get the best available prediction for [intersectionId] and [phase].
  /// Returns null if no prediction exists.
  Future<SignalPrediction?> call({
    required String intersectionId,
    required String phase,
  }) async {
    try {
      final prediction = await _repository.getPrediction(intersectionId, phase);

      if (prediction == null) {
        logDebug(LogCategory.signal, 'No prediction for $intersectionId/$phase');
        return null;
      }

      if (!prediction.isFresh()) {
        logWarning(
          LogCategory.signal,
          'Stale prediction for $intersectionId/${prediction.confidence}',
        );
      }

      return prediction;
    } catch (e, st) {
      logError(LogCategory.signal, 'Prediction fetch failed: $e');
      throw UnexpectedException(
        'Unable to load signal prediction',
        stackTrace: st,
      );
    }
  }

  /// Stream of predictions for real-time updates.
  Stream<SignalPrediction?> stream({
    required String intersectionId,
  }) {
    return _repository.getPredictionStream(intersectionId);
  }
}
