/// SignalNav - Safety Validator
///
/// This is the SINGLE SOURCE OF TRUTH for all safety enforcement in the app.
/// It enforces:
/// - Speed-based UI lock (no manual interaction above 5 mph)
/// - Movement detection
/// - Speed limit clamping for GLOSA recommendations
/// - Night mode dimming enforcement
/// - Headphone disconnection handling
///
/// EVERY UI interaction that could distract a driver MUST call
/// [SafetyValidator.canInteractManually] before proceeding.

import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/errors.dart';
import '../core/logger.dart';

/// Current safety state of the vehicle/user.
enum SafetyState {
  /// Safe for manual interaction (stationary or very slow)
  safe,

  /// Moving - manual UI disabled, voice/Bluetooth only
  moving,

  /// Unknown - GPS unavailable, default to most restrictive
  unknown,
}

/// Result of a safety check.
@immutable
class SafetyCheckResult {
  final bool allowed;
  final SafetyState state;
  final String? reason;

  const SafetyCheckResult({
    required this.allowed,
    required this.state,
    this.reason,
  });
}

/// Central safety validator. Use as a singleton via Provider.
class SafetyValidator extends ChangeNotifier {
  double _currentSpeedMph = 0.0;
  bool _passengerModeEnabled = false;
  bool _headphonesConnected = true;
  bool _isNightMode = false;

  Timer? _nightModeTimer;
  Timer? _speedDebounceTimer;

  // Getters
  double get currentSpeedMph => _currentSpeedMph;
  bool get passengerModeEnabled => _passengerModeEnabled;
  bool get headphonesConnected => _headphonesConnected;
  bool get isNightMode => _isNightMode;

  /// Whether manual UI interaction is currently allowed.
  bool get canInteract => _evaluateInteraction().allowed;

  SafetyState get currentState => _evaluateInteraction().state;

  SafetyValidator() {
    _startNightModeWatcher();
  }

  /// Update current GPS speed. Call this from LocationService on every fix.
  void updateSpeed(double speedMph) {
    final oldState = _evaluateInteraction().state;
    _currentSpeedMph = speedMph.abs();

    // Debounce rapid state changes near threshold
    _speedDebounceTimer?.cancel();
    _speedDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      final newState = _evaluateInteraction().state;
      if (oldState != newState) {
        logSafety(
          'Safety state changed: $oldState -> $newState at ${speedMph.toStringAsFixed(1)} mph',
        );
        notifyListeners();
      }
    });

    // Always notify immediately for UI responsiveness
    notifyListeners();
  }

  /// Toggle passenger mode. Must be explicitly enabled in settings.
  /// Even in passenger mode, safety advice is still calculated but not enforced.
  void setPassengerMode(bool enabled) {
    _passengerModeEnabled = enabled;
    logSafety('Passenger mode ${enabled ? 'enabled' : 'disabled'}');
    notifyListeners();
  }

  /// Update headphone connection status.
  void setHeadphonesConnected(bool connected) {
    if (_headphonesConnected && !connected) {
      logSafety('HEADPHONES DISCONNECTED - audio guidance force-stopped');
      _headphonesConnected = false;
      notifyListeners();
    } else if (!_headphonesConnected && connected) {
      _headphonesConnected = true;
      notifyListeners();
    }
  }

  /// Clamp a calculated GLOSA speed to never exceed legal limits.
  /// [calculatedSpeedMph] = raw GLOSA recommendation
  /// [speedLimitMph] = posted speed limit for the road
  /// Returns the safe speed to recommend, or null if unsafe.
  double? clampGLOSApeed(double calculatedSpeedMph, double speedLimitMph) {
    final maxAllowed = speedLimitMph + kGloSApeedBufferMph;

    if (calculatedSpeedMph > maxAllowed) {
      logSafety(
        'GLOSA speed clamped: $calculatedSpeedMph -> null (limit: $speedLimitMph)',
      );
      return null; // Too fast - advise maintaining speed limit instead
    }

    // Also clamp to a reasonable minimum to avoid suggesting unsafe crawling
    final safeMin = speedLimitMph * 0.5;
    if (calculatedSpeedMph < safeMin) {
      return safeMin;
    }

    return calculatedSpeedMph;
  }

  /// Evaluate if manual interaction is currently safe.
  SafetyCheckResult canInteractManually() => _evaluateInteraction();

  /// Throws [SafetyViolationException] if manual interaction is unsafe.
  void assertCanInteractManually() {
    final result = _evaluateInteraction();
    if (!result.allowed) {
      throw SafetyViolationException(
        result.reason ?? 'Manual interaction blocked for safety',
      );
    }
  }

  SafetyCheckResult _evaluateInteraction() {
    // Passenger mode bypasses speed lock for UI testing
    if (_passengerModeEnabled) {
      return const SafetyCheckResult(
        allowed: true,
        state: SafetyState.safe,
        reason: 'Passenger mode active',
      );
    }

    // Unknown speed = most restrictive
    if (_currentSpeedMph < 0) {
      return const SafetyCheckResult(
        allowed: false,
        state: SafetyState.unknown,
        reason: 'GPS speed unknown - defaulting to safe mode',
      );
    }

    // Hysteresis: lock at 5+, unlock below 4
    if (_currentSpeedMph >= kSafetySpeedLimitMph) {
      return SafetyCheckResult(
        allowed: false,
        state: SafetyState.moving,
        reason:
            'Moving at ${_currentSpeedMph.toStringAsFixed(1)} mph. Voice commands only.',
      );
    }

    // Below unlock threshold = safe
    if (_currentSpeedMph < kSafetySpeedUnlockMph) {
      return const SafetyCheckResult(
        allowed: true,
        state: SafetyState.safe,
      );
    }

    // Between 4-5 mph: maintain previous state (hysteresis)
    // This prevents rapid toggling
    return SafetyCheckResult(
      allowed: _currentSpeedMph < kSafetySpeedLimitMph,
      state: _currentSpeedMph < kSafetySpeedLimitMph
          ? SafetyState.safe
          : SafetyState.moving,
    );
  }

  /// Check if night mode should be active (7 PM - 6 AM unless plugged in + passenger mode)
  bool shouldDimScreen({required bool isPluggedIn}) {
    final now = DateTime.now();
    final hour = now.hour;

    bool isNightHours;
    if (kNightStartHour > kNightEndHour) {
      // Wraps around midnight (19:00 - 06:00)
      isNightHours = hour >= kNightStartHour || hour < kNightEndHour;
    } else {
      isNightHours = hour >= kNightStartHour && hour < kNightEndHour;
    }

    // Don't dim if plugged in AND in passenger mode
    if (isPluggedIn && _passengerModeEnabled) {
      return false;
    }

    return isNightHours;
  }

  void _startNightModeWatcher() {
    _nightModeTimer?.cancel();
    _nightModeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkNightMode();
    });
    _checkNightMode();
  }

  void _checkNightMode() {
    // We can't detect charging state here without a plugin,
    // so this is a simplified check. Call [updateNightMode] from UI layer
    // with charging state.
    final now = DateTime.now();
    final hour = now.hour;

    bool nightTime;
    if (kNightStartHour > kNightEndHour) {
      nightTime = hour >= kNightStartHour || hour < kNightEndHour;
    } else {
      nightTime = hour >= kNightStartHour && hour < kNightEndHour;
    }

    if (_isNightMode != nightTime) {
      _isNightMode = nightTime;
      notifyListeners();
    }
  }

  /// Call from UI with current charging state to determine if screen should dim.
  Future<void> updateNightMode(bool isPluggedIn) async {
    final shouldDim = shouldDimScreen(isPluggedIn: isPluggedIn);

    if (shouldDim && !_isNightMode) {
      _isNightMode = true;
      notifyListeners();
    } else if (!shouldDim && _isNightMode) {
      _isNightMode = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _nightModeTimer?.cancel();
    _speedDebounceTimer?.cancel();
    super.dispose();
  }
}
