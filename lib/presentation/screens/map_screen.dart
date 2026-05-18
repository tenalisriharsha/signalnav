/// SignalNav - Map Screen (Passenger Mode)
///
/// Full interactive MapLibre map with signal icons, confidence badges,
/// and manual report buttons. This is the primary UI when NOT in driver mode
/// or when passenger mode is enabled.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../core/constants.dart';
import '../../core/logger.dart';
import '../../data/models/intersection.dart';
import '../../data/models/signal_report.dart';
import '../providers/app_providers.dart';
import '../widgets/confidence_badge.dart';
import 'navigation_screen.dart';
import 'settings_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapLibreMapController? _mapController;
  List<Intersection> _intersections = [];
  bool _isLoading = true;

  static const String _mapStyleUrl =
      'https://demotiles.maplibre.org/style.json';

  @override
  void initState() {
    super.initState();
    _loadIntersections();
    _startLocationTracking();
  }

  Future<void> _loadIntersections() async {
    try {
      final repo = ref.read(signalRepositoryProvider);
      final intersections = await repo.getIntersections();
      setState(() {
        _intersections = intersections;
        _isLoading = false;
      });
      _addSignalMarkers();
    } catch (e) {
      logError(LogCategory.signal, 'Failed to load intersections: $e');
      setState(() => _isLoading = false);
    }
  }

  void _startLocationTracking() {
    final locationService = ref.read(locationServiceProvider);
    locationService.startTracking();
    locationService.setMonitoredIntersections(_intersections);
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    _addSignalMarkers();
  }

  void _addSignalMarkers() {
    if (_mapController == null) return;

    // Add circle markers for intersections
    for (final intersection in _intersections) {
      _mapController!.addCircle(
        CircleOptions(
          geometry: LatLng(intersection.lat, intersection.lng),
          circleRadius: 8,
          circleColor: _colorForConfidence(intersection.confidenceStatus),
          circleStrokeWidth: 2,
          circleStrokeColor: '#FFFFFF',
        ),
      );
    }
  }

  String _colorForConfidence(ConfidenceStatus status) {
    switch (status) {
      case ConfidenceStatus.high:
        return '#4CAF50'; // Green
      case ConfidenceStatus.medium:
        return '#FFC107'; // Yellow/amber
      case ConfidenceStatus.low:
        return '#F44336'; // Red
    }
  }

  void _onSignalTap(Intersection intersection) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (context) => _SignalBottomSheet(intersection: intersection),
    );
  }

  @override
  Widget build(BuildContext context) {
    final passengerMode = ref.watch(passengerModeProvider);
    final safety = ref.watch(safetyValidatorProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(kAppDisplayName),
        actions: [
          // Passenger mode toggle
          Row(
            children: [
              const Icon(Icons.person, size: 18, color: Colors.white70),
              const SizedBox(width: 4),
              Switch(
                value: passengerMode,
                onChanged: (v) {
                  ref.read(passengerModeProvider.notifier).state = v;
                  ref.read(safetyValidatorProvider).setPassengerMode(v);
                },
                activeColor: Colors.green,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MapLibreMap(
            styleString: _mapStyleUrl,
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(39.7817, -89.6501), // Springfield, IL
              zoom: 13,
            ),
            trackCameraPosition: true,
            myLocationEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.tracking,
            onMapClick: (_, latLng) {
              // Find nearest intersection
              final nearest = _intersections.where((i) {
                return i.isNear(latLng.latitude, latLng.longitude, 50);
              }).toList();
              if (nearest.isNotEmpty) {
                _onSignalTap(nearest.first);
              }
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          // Speed safety indicator overlay
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: safety.canInteract ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                safety.canInteract
                    ? 'SAFE: ${safety.currentSpeedMph.toStringAsFixed(1)} mph'
                    : 'LOCKED: ${safety.currentSpeedMph.toStringAsFixed(1)} mph',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'nav',
            backgroundColor: Colors.green,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NavigationScreen(),
                ),
              );
            },
            child: const Icon(Icons.navigation),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'report',
            backgroundColor: Colors.orange,
            onPressed: () {
              // Show nearest intersection report dialog
              _showQuickReportDialog();
            },
            child: const Icon(Icons.report),
          ),
        ],
      ),
    );
  }

  void _showQuickReportDialog() {
    final location = ref.read(locationServiceProvider).lastLocation;
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available')),
      );
      return;
    }

    final nearby = _intersections
        .where((i) => i.isNear(location.latitude, location.longitude, 100))
        .toList();

    if (nearby.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No intersections nearby')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Report Signal',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: nearby.map((i) {
            return ListTile(
              title: Text(
                i.displayName,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: ConfidenceBadge(status: i.confidenceStatus),
              onTap: () {
                Navigator.of(context).pop();
                _showColorPicker(i);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showColorPicker(Intersection intersection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text(
          'Signal at ${intersection.displayName}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _colorButton(intersection, SignalColor.red, Colors.red, 'Red'),
            _colorButton(intersection, SignalColor.yellow, Colors.yellow, 'Yellow'),
            _colorButton(intersection, SignalColor.green, Colors.green, 'Green'),
          ],
        ),
      ),
    );
  }

  Widget _colorButton(
    Intersection intersection,
    SignalColor color,
    Color buttonColor,
    String label,
  ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: Colors.black,
        minimumSize: const Size(80, 60),
      ),
      onPressed: () async {
        try {
          final user = ref.read(firebaseServiceProvider).currentUser;
          await ref.read(reportSignalStateProvider).call(
                intersectionId: intersection.id,
                phase: intersection.phases.first,
                color: color,
                isVoiceOrBluetooth: false,
                userId: user?.uid ?? 'anonymous',
              );
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Reported $label at ${intersection.displayName}')),
            );
          }
        } catch (e) {
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${e.toString()}')),
            );
          }
        }
      },
      child: Text(label),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class _SignalBottomSheet extends StatelessWidget {
  final Intersection intersection;

  const _SignalBottomSheet({required this.intersection});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            intersection.displayName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ConfidenceBadge(status: intersection.confidenceStatus),
              const SizedBox(width: 8),
              Text(
                'Speed limit: ${intersection.speedLimitMph} mph',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Type: ${intersection.signalType.name}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Text(
            'Phases: ${intersection.phases.join(", ")}',
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
