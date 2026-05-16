/// SignalNav - Location Service
///
/// Handles GPS, speed tracking, and geofencing for intersection detection.
/// Requests "Always Allow" location ONLY for passive data collection;
/// explains this in the system dialog.

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../core/logger.dart';
import '../models/intersection.dart';

/// Location update with speed and heading.
class LocationUpdate {
  final double latitude;
  final double longitude;
  final double speedMph;
  final double heading;
  final double accuracyMeters;
  final DateTime timestamp;

  const LocationUpdate({
    required this.latitude,
    required this.longitude,
    required this.speedMph,
    required this.heading,
    required this.accuracyMeters,
    required this.timestamp,
  });

  /// Speed in meters per second
  double get speedMps => speedMph * 0.44704;
}

/// Geofence event for intersection proximity.
class GeofenceEvent {
  final String intersectionId;
  final bool entered;
  final double distanceMeters;

  const GeofenceEvent({
    required this.intersectionId,
    required this.entered,
    required this.distanceMeters,
  });
}

/// Central location service.
class LocationService {
  StreamSubscription<Position>? _positionStream;
  final StreamController<LocationUpdate> _locationController =
      StreamController<LocationUpdate>.broadcast();
  final StreamController<GeofenceEvent> _geofenceController =
      StreamController<GeofenceEvent>.broadcast();

  /// Current location stream
  Stream<LocationUpdate> get locationStream => _locationController.stream;

  /// Geofence events stream
  Stream<GeofenceEvent> get geofenceStream => _geofenceController.stream;

  /// Currently monitored intersections for geofencing
  final List<Intersection> _monitoredIntersections = [];

  /// Last known location
  LocationUpdate? _lastLocation;
  LocationUpdate? get lastLocation => _lastLocation;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  /// Check and request location permissions.
  /// Returns true if we have at least "while in use" permission.
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        'Location services are disabled. Please enable GPS in Settings.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const PermissionException(
          'Location permission denied. Crowdsourcing and navigation require location access.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const PermissionException(
        'Location permission permanently denied. Please enable in Settings.',
      );
    }

    return true;
  }

  /// Request "always" location permission for background geofencing.
  /// This is ONLY used for passive data collection to detect intersection stops.
  Future<bool> requestBackgroundPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Start continuous location tracking with geofencing.
  Future<void> startTracking() async {
    if (_isTracking) return;
    await checkPermissions();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5, // meters
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (e) {
        logError(LogCategory.location, 'Position stream error: $e');
      },
    );

    _isTracking = true;
    logInfo(LogCategory.location, 'Location tracking started');
  }

  /// Stop location tracking.
  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
    logInfo(LogCategory.location, 'Location tracking stopped');
  }

  /// Set intersections to monitor for geofencing.
  void setMonitoredIntersections(List<Intersection> intersections) {
    _monitoredIntersections
      ..clear()
      ..addAll(intersections);
    logInfo(
      LogCategory.location,
      'Monitoring ${intersections.length} intersections',
    );
  }

  void _onPositionUpdate(Position position) {
    final speedMph = position.speed * 2.23694; // m/s to mph
    final update = LocationUpdate(
      latitude: position.latitude,
      longitude: position.longitude,
      speedMph: speedMph,
      heading: position.heading,
      accuracyMeters: position.accuracy,
      timestamp: position.timestamp ?? DateTime.now().toUtc(),
    );

    _lastLocation = update;
    _locationController.add(update);

    // Check geofences
    _checkGeofences(update);
  }

  void _checkGeofences(LocationUpdate location) {
    for (final intersection in _monitoredIntersections) {
      final distance = _calculateDistance(
        location.latitude,
        location.longitude,
        intersection.lat,
        intersection.lng,
      );

      // Entered geofence
      if (distance <= kIntersectionGeofenceRadiusMeters) {
        // Auto-detect stop: speed < 3 mph near intersection
        if (location.speedMph < kStopDetectionSpeedMph) {
          _geofenceController.add(
            GeofenceEvent(
              intersectionId: intersection.id,
              entered: true,
              distanceMeters: distance,
            ),
          );
        }
      }
    }
  }

  /// Calculate Haversine distance in meters between two points.
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusM = 6371000;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        (dLat / 2) * (dLat / 2) +
        _cosd(lat1) * _cosd(lat2) * (dLon / 2) * (dLon / 2);
    final c = 2 * _atan2Sqrt(a);
    return earthRadiusM * c;
  }

  static double _toRadians(double degrees) => degrees * 0.017453292519943295;
  static double _cosd(double degrees) => _toRadians(degrees).cos;
  static double _atan2Sqrt(double a) {
    return _customAtan2(_sqrt(a), _sqrt((1 - a).clamp(0, 1)));
  }

  static double _customAtan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0) return (y >= 0 ? 3.141592653589793 : -3.141592653589793) + _atan(y / x);
    if (y > 0) return 1.5707963267948966;
    if (y < 0) return -1.5707963267948966;
    return 0;
  }

  static double _atan(double x) {
    return x - x * x * x / 3 + x * x * x * x * x / 5;
  }

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double z = x;
    double prev;
    do {
      prev = z;
      z = (z + x / z) / 2;
    } while ((z - prev).abs() > 0.0001);
    return z;
  }
}

extension _DoubleMath on double {
  double get cos {
    final x = this % 6.283185307179586;
    double result = 1;
    double term = 1;
    for (int n = 1; n <= 10; n++) {
      term *= -x * x / ((2 * n - 1) * (2 * n));
      result += term;
    }
    return result;
  }
}
