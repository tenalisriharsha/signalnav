/// SignalNav - Navigation Screen (Driver Mode)
///
/// Audio-first, minimal visual UI. OLED black background with large speed display.
/// All guidance via TTS + haptics. Zero animations.
///
/// SAFETY: This screen is designed for glancing only. Never requires touch
/// while the vehicle is in motion.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../../core/constants.dart';
import '../../core/logger.dart';
import '../../data/models/route_segment.dart' as models;
import '../../data/models/route_segment.dart' show TurnInstruction, TurnType;
import '../../data/models/signal_report.dart';
import '../../data/services/audio_service.dart';
import '../../data/services/location_service.dart';
import '../../domain/usecases/calculate_green_wave_speed.dart';
import '../providers/app_providers.dart';
import '../widgets/audio_mode_indicator.dart';
import '../widgets/speedometer_overlay.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  StreamSubscription? _locationSub;
  StreamSubscription? _geofenceSub;
  final _brightness = ScreenBrightness();
  double? _originalBrightness;

  models.Route? _currentRoute;
  int _currentSegmentIndex = 0;
  bool _approachingIntersection = false;

  @override
  void initState() {
    super.initState();
    _startNavigation();
    _applyNightModeBrightness();
  }

  Future<void> _applyNightModeBrightness() async {
    try {
      _originalBrightness = await _brightness.current;
      final safety = ref.read(safetyValidatorProvider);
      // Simplified: assume not plugged in for night mode check
      if (safety.shouldDimScreen(isPluggedIn: false)) {
        await _brightness.setScreenBrightness(kNightBrightness);
      }
    } catch (e) {
      logWarning(LogCategory.lifecycle, 'Brightness control failed: $e');
    }
  }

  void _startNavigation() {
    final locationService = ref.read(locationServiceProvider);
    final audioService = ref.read(audioServiceProvider);

    _locationSub = locationService.locationStream.listen((location) {
      _onLocationUpdate(location);
    });

    _geofenceSub = locationService.geofenceStream.listen((event) {
      _onGeofenceEvent(event);
    });

    // Load route if available
    final route = ref.read(currentRouteProvider);
    if (route != null) {
      setState(() => _currentRoute = route);
      audioService.speak('Navigation started. Drive safely.');
    }
  }

  void _onLocationUpdate(LocationUpdate location) {
    final safety = ref.read(safetyValidatorProvider);
    safety.updateSpeed(location.speedMph);

    // Check if we need GLOSA advice for upcoming intersection
    _checkUpcomingSignal(location);
  }

  void _onGeofenceEvent(GeofenceEvent event) {
    if (!event.entered) return;

    final audioService = ref.read(audioServiceProvider);

    // Auto-prompt for signal status
    audioService.haptic(kHapticStoppedAtRed);
    audioService.speak(kPromptSignalAhead);

    // Listen for voice command
    _listenForSignalReport(event.intersectionId);
  }

  void _checkUpcomingSignal(LocationUpdate location) {
    if (_currentRoute == null) return;

    final segments = _currentRoute!.segments;
    if (_currentSegmentIndex >= segments.length) return;

    final segment = segments[_currentSegmentIndex];
    if (segment.endIntersection == null) return;

    // Calculate distance to intersection along polyline
    final distance = _distanceToEndOfSegment(location, segment);

    // Trigger GLOSA when within 500m
    if (distance < 500 && distance > 50 && !_approachingIntersection) {
      _approachingIntersection = true;
      _adviseGreenWave(segment, distance, location.speedMph);
    } else if (distance > 600) {
      _approachingIntersection = false;
    }

    // Advance segment if passed
    if (distance < 30) {
      _currentSegmentIndex++;
      _approachingIntersection = false;

      // Speak next turn instruction
      if (_currentSegmentIndex < segments.length) {
        final nextSegment = segments[_currentSegmentIndex];
        if (nextSegment.instruction != null) {
          ref.read(audioServiceProvider).speak(
                nextSegment.instruction!.audioText,
              );
        }
      }
    }
  }

  double _distanceToEndOfSegment(LocationUpdate location, models.RouteSegment segment) {
    if (segment.polyline.isEmpty) return double.infinity;

    // Simple distance to last polyline point
    final end = segment.polyline.last;
    final dx = (end.lat - location.latitude) * 111320;
    final dy = (end.lng - location.longitude) * 111320 * _cosd(location.latitude);
    return (dx * dx + dy * dy).sqrt;
  }

  void _adviseGreenWave(models.RouteSegment segment, double distanceMeters, double currentSpeed) {
    final calculator = ref.read(calculateGreenWaveSpeedProvider);
    final audioService = ref.read(audioServiceProvider);

    final result = calculator.call(
      segment: segment,
      currentSpeedMph: currentSpeed,
      distanceToIntersectionMeters: distanceMeters,
    );

    // Haptic for green wave advice
    if (result.secondsUntilGreen != null && result.secondsUntilGreen! <= 15) {
      audioService.hapticGreenSoon();
    }

    audioService.speak(result.audioMessage);
  }

  Future<void> _listenForSignalReport(String intersectionId) async {
    final audioService = ref.read(audioServiceProvider);
    final result = await audioService.listenForCommand();

    if (result.recognized && result.command != null) {
      SignalColor color;
      switch (result.command) {
        case 'red':
          color = SignalColor.red;
          break;
        case 'green':
          color = SignalColor.green;
          break;
        case 'yellow':
          color = SignalColor.yellow;
          break;
        default:
          return;
      }

      try {
        final user = ref.read(firebaseServiceProvider).currentUser;
        await ref.read(reportSignalStateProvider).call(
              intersectionId: intersectionId,
              phase: 'NB_through', // Simplified - detect from heading in production
              color: color,
              isVoiceOrBluetooth: true,
              userId: user?.uid ?? 'anonymous',
            );
        audioService.speak('Thank you. Report recorded.');
      } catch (e) {
        logError(LogCategory.audio, 'Voice report failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final safety = ref.watch(safetyValidatorProvider);
    final location = ref.read(locationServiceProvider).lastLocation;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: minimal info
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AudioModeIndicator(),
                  if (_currentRoute != null)
                    Text(
                      '${_currentRoute!.totalDistanceMiles.toStringAsFixed(1)} mi',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                      ),
                    ),
                ],
              ),
            ),

            // Large speed display
            Expanded(
              child: Center(
                child: SpeedometerOverlay(
                  speedMph: location?.speedMph ?? 0,
                  speedLimit: _currentRoute?.segments[_currentSegmentIndex.clamp(
                    0,
                    (_currentRoute?.segments.length ?? 1) - 1,
                  )].speedLimitMph,
                ),
              ),
            ),

            // Next turn instruction (large, high contrast)
            if (_currentRoute != null && _currentSegmentIndex < _currentRoute!.segments.length)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: _buildTurnInstruction(
                  _currentRoute!.segments[_currentSegmentIndex].instruction,
                ),
              ),

            // Bottom safety bar
            Container(
              padding: const EdgeInsets.all(16),
              color: safety.canInteract ? Colors.green.shade900 : Colors.red.shade900,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    safety.canInteract ? Icons.lock_open : Icons.lock,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    safety.canInteract
                        ? 'STOPPED - UI UNLOCKED'
                        : 'MOVING - VOICE ONLY',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Floating stop button for emergency
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: () {
          _stopNavigation();
          Navigator.of(context).pop();
        },
        child: const Text('END NAVIGATION', style: TextStyle(fontSize: 18)),
      ),
    );
  }

  Widget _buildTurnInstruction(TurnInstruction? instruction) {
    if (instruction == null) {
      return const Text(
        'Continue straight',
        style: TextStyle(color: Colors.white, fontSize: 24),
      );
    }

    return Column(
      children: [
        Icon(
          _turnIcon(instruction.type),
          color: Colors.white,
          size: 48,
        ),
        const SizedBox(height: 8),
        Text(
          instruction.audioText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (instruction.distanceMeters != null)
          Text(
            '${(instruction.distanceMeters! / 1609.34).toStringAsFixed(1)} mi',
            style: const TextStyle(color: Colors.white54, fontSize: 18),
          ),
      ],
    );
  }

  IconData _turnIcon(TurnType type) {
    switch (type) {
      case TurnType.straight:
        return Icons.arrow_upward;
      case TurnType.slightLeft:
        return Icons.arrow_forward_ios;
      case TurnType.left:
        return Icons.turn_left;
      case TurnType.sharpLeft:
        return Icons.reply;
      case TurnType.slightRight:
        return Icons.arrow_back_ios;
      case TurnType.right:
        return Icons.turn_right;
      case TurnType.sharpRight:
        return Icons.reply;
      case TurnType.uTurn:
        return Icons.u_turn_left;
      case TurnType.roundabout:
        return Icons.roundabout_left;
      case TurnType.destination:
        return Icons.place;
    }
  }

  void _stopNavigation() {
    final audioService = ref.read(audioServiceProvider);
    audioService.speak('Navigation ended.');
    audioService.stop();
    ref.read(navigationActiveProvider.notifier).state = false;
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _geofenceSub?.cancel();

    // Restore brightness
    if (_originalBrightness != null) {
      _brightness.setScreenBrightness(_originalBrightness!);
    }

    super.dispose();
  }
}

extension _DoubleMath on double {
  double get sqrt {
    if (this <= 0) return 0;
    double z = this;
    double prev;
    do {
      prev = z;
      z = (z + this / z) / 2;
    } while ((z - prev).abs() > 0.0001);
    return z;
  }
}

// ignore: unused_element
double _cosd(double degrees) {
  final rad = degrees * 0.017453292519943295;
  return rad.cos;
}

extension _DoubleCos on double {
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
