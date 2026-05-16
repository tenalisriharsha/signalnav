/// SignalNav - Riverpod Providers
///
/// Central dependency injection and state management.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/route_segment.dart';
import '../../data/repositories/nominatim_repository.dart';
import '../../data/repositories/osrm_repository.dart';
import '../../data/repositories/signal_repository.dart';
import '../../data/repositories/tomtom_repository.dart';
import '../../data/services/audio_service.dart';
import '../../data/services/firebase_service.dart';
import '../../data/services/location_service.dart';
import '../../domain/usecases/calculate_green_wave_speed.dart';
import '../../domain/usecases/get_optimal_route.dart';
import '../../domain/usecases/predict_signal_state.dart';
import '../../domain/usecases/report_signal_state.dart';
import '../../utils/safety_validator.dart';

// ===================== SERVICES =====================

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});

final safetyValidatorProvider = ChangeNotifierProvider<SafetyValidator>((ref) {
  return SafetyValidator();
});

// ===================== REPOSITORIES =====================

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

final osrmRepositoryProvider = Provider<OsrmRepository>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  return OsrmRepository(
    prefs: prefsAsync.valueOrNull,
  );
});

final tomtomRepositoryProvider = Provider<TomTomRepository>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  return TomTomRepository(
    prefs: prefsAsync.valueOrNull,
  );
});

final signalRepositoryProvider = Provider<SignalRepository>((ref) {
  final firebase = ref.watch(firebaseServiceProvider);
  return SignalRepository(firebase);
});

final nominatimRepositoryProvider = Provider<NominatimRepository>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  return NominatimRepository(
    prefs: prefsAsync.valueOrNull,
  );
});

// ===================== USE CASES =====================

final getOptimalRouteProvider = Provider<GetOptimalRoute>((ref) {
  return GetOptimalRoute(
    ref.watch(osrmRepositoryProvider),
    ref.watch(tomtomRepositoryProvider),
  );
});

final reportSignalStateProvider = Provider<ReportSignalState>((ref) {
  return ReportSignalState(
    ref.watch(signalRepositoryProvider),
    ref.watch(safetyValidatorProvider),
    ref.watch(locationServiceProvider),
  );
});

final predictSignalStateProvider = Provider<PredictSignalState>((ref) {
  return PredictSignalState(
    ref.watch(signalRepositoryProvider),
  );
});

final calculateGreenWaveSpeedProvider = Provider<CalculateGreenWaveSpeed>((ref) {
  return CalculateGreenWaveSpeed(
    ref.watch(safetyValidatorProvider),
  );
});

// ===================== APP STATE =====================

/// Whether onboarding has been completed
final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_complete') ?? false;
});

/// Current app mode
enum AppMode { driver, passenger }

final appModeProvider = StateProvider<AppMode>((ref) => AppMode.driver);

/// Passenger mode toggle (unlocks UI at any speed)
final passengerModeProvider = StateProvider<bool>((ref) => false);

/// Current route being navigated
final currentRouteProvider = StateProvider<Route?>((ref) => null);

/// Navigation active state
final navigationActiveProvider = StateProvider<bool>((ref) => false);

/// User authentication state
final authStateProvider = StreamProvider((ref) {
  return ref.watch(firebaseServiceProvider).authStateChanges;
});
