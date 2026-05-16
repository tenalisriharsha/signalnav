/// SignalNav - Signal Repository
///
/// Manages local + remote signal data:
/// - Intersection metadata
/// - Crowdsourced reports (write-only anonymized)
/// - Predictions (read-only aggregated)

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../core/logger.dart';
import '../../utils/privacy_anonymizer.dart';
import '../models/intersection.dart';
import '../models/prediction.dart';
import '../models/signal_report.dart';
import '../services/firebase_service.dart';

class SignalRepository {
  final FirebaseService _firebase;

  SignalRepository(this._firebase);

  FirebaseFirestore get _firestore => _firebase.firestore;

  /// Fetch all known intersections.
  Future<List<Intersection>> getIntersections() async {
    try {
      final snapshot = await _firestore
          .collection(kCollectionIntersections)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Intersection.fromJson(data);
      }).toList();
    } on FirebaseException catch (e, st) {
      logError(LogCategory.signal, 'Failed to fetch intersections: ${e.code}');
      throw BackendException(
        'Failed to load intersection data',
        code: e.code,
        stackTrace: st,
      );
    }
  }

  /// Get intersections near a location.
  Future<List<Intersection>> getIntersectionsNear(
    double lat,
    double lng,
    double radiusMeters,
  ) async {
    try {
      // Firestore doesn't support native geoqueries on free tier easily.
      // For MVP, we fetch all and filter client-side.
      // In production, use geohash-based querying.
      final all = await getIntersections();
      return all
          .where((i) => i.isNear(lat, lng, radiusMeters))
          .toList();
    } catch (e, st) {
      logError(LogCategory.signal, 'Failed to fetch nearby intersections: $e');
      throw BackendException(
        'Failed to load nearby intersections',
        stackTrace: st,
      );
    }
  }

  /// Stream of predictions for a specific intersection.
  Stream<SignalPrediction?> getPredictionStream(String intersectionId) {
    return _firestore
        .collection(kCollectionPredictions)
        .where('intersection_id', isEqualTo: intersectionId)
        .orderBy('updated_at', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final data = snapshot.docs.first.data();
          data['intersection_id'] = intersectionId;
          return SignalPrediction.fromJson(data);
        })
        .handleError((e) {
          logError(LogCategory.signal, 'Prediction stream error: $e');
          return null;
        });
  }

  /// Get current prediction for an intersection and phase.
  Future<SignalPrediction?> getPrediction(
    String intersectionId,
    String phase,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(kCollectionPredictions)
          .where('intersection_id', isEqualTo: intersectionId)
          .where('phase', isEqualTo: phase)
          .orderBy('updated_at', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      final data = snapshot.docs.first.data();
      data['intersection_id'] = intersectionId;
      return SignalPrediction.fromJson(data);
    } on FirebaseException catch (e, st) {
      logError(LogCategory.signal, 'Failed to fetch prediction: ${e.code}');
      throw BackendException(
        'Failed to load signal prediction',
        code: e.code,
        stackTrace: st,
      );
    }
  }

  /// Submit an anonymized signal report.
  /// This is the ONLY way signal reports enter the system.
  Future<void> submitReport(SignalReport report) async {
    try {
      // Additional safety: verify no PII in the report
      final json = report.toJson();
      if (PrivacyAnonymizer.containsPii(json)) {
        throw const ValidationException(
          'Report contains PII and was rejected by privacy filter',
        );
      }

      await _firestore.collection(kCollectionSignalReports).add(json);
      logInfo(
        LogCategory.signal,
        'Report submitted for ${report.intersectionId}',
      );
    } on FirebaseException catch (e, st) {
      logError(LogCategory.signal, 'Failed to submit report: ${e.code}');
      throw BackendException(
        'Failed to submit signal report',
        code: e.code,
        stackTrace: st,
      );
    }
  }

  /// Seed initial intersections (for development/testing).
  /// In production, intersections are loaded from Firestore admin setup.
  Future<void> seedSpringfieldIntersections() async {
    final intersections = _getSpringfieldTestIntersections();
    final batch = _firestore.batch();

    for (final intersection in intersections) {
      final ref = _firestore
          .collection(kCollectionIntersections)
          .doc(intersection.id);
      batch.set(ref, intersection.toJson()..remove('id'));
    }

    try {
      await batch.commit();
      logInfo(LogCategory.signal, 'Seeded ${intersections.length} intersections');
    } on FirebaseException catch (e, st) {
      logError(LogCategory.signal, 'Failed to seed intersections: ${e.code}');
      throw BackendException(
        'Failed to seed intersection data',
        code: e.code,
        stackTrace: st,
      );
    }
  }

  /// Hardcoded 20 test intersections for Springfield downtown grid.
  List<Intersection> _getSpringfieldTestIntersections() {
    final now = DateTime.now().toUtc();
    return [
      Intersection(
        id: 'springfield_5th_adams',
        lat: 39.7817,
        lng: -89.6501,
        roadName: '5th St',
        crossStreet: 'Adams St',
        signalType: SignalType.coordinatedActuated,
        speedLimitMph: 30,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_5th_jefferson',
        lat: 39.7830,
        lng: -89.6501,
        roadName: '5th St',
        crossStreet: 'Jefferson St',
        signalType: SignalType.coordinatedActuated,
        speedLimitMph: 30,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_5th_monroe',
        lat: 39.7843,
        lng: -89.6501,
        roadName: '5th St',
        crossStreet: 'Monroe St',
        signalType: SignalType.preTimed,
        speedLimitMph: 30,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_6th_adams',
        lat: 39.7817,
        lng: -89.6488,
        roadName: '6th St',
        crossStreet: 'Adams St',
        signalType: SignalType.coordinatedActuated,
        speedLimitMph: 30,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_6th_jefferson',
        lat: 39.7830,
        lng: -89.6488,
        roadName: '6th St',
        crossStreet: 'Jefferson St',
        signalType: SignalType.coordinatedActuated,
        speedLimitMph: 30,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_6th_monroe',
        lat: 39.7843,
        lng: -89.6488,
        roadName: '6th St',
        crossStreet: 'Monroe St',
        signalType: SignalType.preTimed,
        speedLimitMph: 30,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_4th_adams',
        lat: 39.7817,
        lng: -89.6514,
        roadName: '4th St',
        crossStreet: 'Adams St',
        signalType: SignalType.fullyActuated,
        speedLimitMph: 25,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_4th_jefferson',
        lat: 39.7830,
        lng: -89.6514,
        roadName: '4th St',
        crossStreet: 'Jefferson St',
        signalType: SignalType.fullyActuated,
        speedLimitMph: 25,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_macarthur_dirksen',
        lat: 39.7950,
        lng: -89.6700,
        roadName: 'MacArthur Blvd',
        crossStreet: 'Dirksen Pkwy',
        signalType: SignalType.coordinatedActuated,
        speedLimitMph: 45,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_macarthur_veterans',
        lat: 39.7950,
        lng: -89.6800,
        roadName: 'MacArthur Blvd',
        crossStreet: 'Veterans Pkwy',
        signalType: SignalType.coordinatedActuated,
        speedLimitMph: 45,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_dirksen_5th',
        lat: 39.7900,
        lng: -89.6700,
        roadName: 'Dirksen Pkwy',
        crossStreet: '5th St',
        signalType: SignalType.preTimed,
        speedLimitMph: 40,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_dirksen_6th',
        lat: 39.7900,
        lng: -89.6687,
        roadName: 'Dirksen Pkwy',
        crossStreet: '6th St',
        signalType: SignalType.preTimed,
        speedLimitMph: 40,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_veterans_5th',
        lat: 39.8000,
        lng: -89.6800,
        roadName: 'Veterans Pkwy',
        crossStreet: '5th St',
        signalType: SignalType.coordinatedActuated,
        speedLimitMph: 45,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_veterans_6th',
        lat: 39.8000,
        lng: -89.6787,
        roadName: 'Veterans Pkwy',
        crossStreet: '6th St',
        signalType: SignalType.coordinatedActuated,
        speedLimitMph: 45,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_9th_cook',
        lat: 39.7760,
        lng: -89.6440,
        roadName: '9th St',
        crossStreet: 'Cook St',
        signalType: SignalType.fullyActuated,
        speedLimitMph: 25,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_9th_edwards',
        lat: 39.7773,
        lng: -89.6440,
        roadName: '9th St',
        crossStreet: 'Edwards St',
        signalType: SignalType.fullyActuated,
        speedLimitMph: 25,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_11th_madison',
        lat: 39.7786,
        lng: -89.6420,
        roadName: '11th St',
        crossStreet: 'Madison St',
        signalType: SignalType.preTimed,
        speedLimitMph: 30,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_11th_jefferson',
        lat: 39.7830,
        lng: -89.6420,
        roadName: '11th St',
        crossStreet: 'Jefferson St',
        signalType: SignalType.preTimed,
        speedLimitMph: 30,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_2nd_capital',
        lat: 39.7850,
        lng: -89.6530,
        roadName: '2nd St',
        crossStreet: 'Capital Ave',
        signalType: SignalType.coordinatedActuated,
        speedLimitMph: 30,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
      Intersection(
        id: 'springfield_2nd_monroe',
        lat: 39.7843,
        lng: -89.6530,
        roadName: '2nd St',
        crossStreet: 'Monroe St',
        signalType: SignalType.coordinatedActuated,
        speedLimitMph: 30,
        phases: const ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
        lastUpdated: now,
      ),
    ];
  }
}
