/// SignalNav - Core Constants
///
/// All API endpoints, thresholds, safety limits, and configuration values.
/// Every constant is documented and purpose-built for safe, legal operation.

// ===================== SAFETY LIMITS =====================

/// Maximum GPS speed (mph) below which manual UI interactions are allowed.
/// Above this speed, ONLY voice and Bluetooth reporting is permitted.
const double kSafetySpeedLimitMph = 5.0;

/// Hysteresis buffer: UI re-enables only when speed drops below this value
/// to prevent rapid lock/unlock near the threshold.
const double kSafetySpeedUnlockMph = 4.0;

/// Maximum allowable GLOSA speed recommendation = posted limit + this buffer.
/// Never suggest speeds that could be interpreted as encouraging speeding.
const double kGloSApeedBufferMph = 5.0;

/// Minimum screen brightness (0.0-1.0) during night driving (10%)
const double kNightBrightness = 0.1;

/// Night mode hours (7 PM - 6 AM local time)
const int kNightStartHour = 19;
const int kNightEndHour = 6;

// ===================== ROUTING & TRAFFIC =====================

/// OSRM server base URL. Self-hosted via Docker for completely free operation.
/// Fallback to GraphHopper Directions API (500 credits/day free tier) if OSRM unavailable.
/// See env_config.dart for runtime-loaded values.
const String kOsrmBaseUrl = 'http://localhost:5000'; // Update for production

// API keys are now loaded from .env via EnvConfig class.
// Do NOT hardcode keys in this file.

/// Traffic cache duration in minutes
const int kTrafficCacheMinutes = 5;

/// Route recalculation minimum interval in seconds to prevent driver distraction
const int kMinRouteRecalcIntervalSeconds = 30;

/// Traffic change threshold (%) that triggers a route re-fetch
const double kTrafficChangeThreshold = 0.20;

// ===================== GEOCODING =====================

/// Nominatim (OpenStreetMap) - free, rate-limited. Cache aggressively.
const String kNominatimBaseUrl = 'https://nominatim.openstreetmap.org';
const String kNominatimUserAgent = 'SignalNav/0.1.0 (signalnav@example.com)';

// ===================== SIGNAL PREDICTION =====================

/// Geofence radius around intersections in meters
const double kIntersectionGeofenceRadiusMeters = 30.0;

/// Speed threshold (mph) for auto-detecting a stop at an intersection
const double kStopDetectionSpeedMph = 3.0;

/// Time bucket size for grouping reports (minutes)
const int kTimeBucketMinutes = 30;

/// Minimum reports required before publishing a cycle length
const int kMinReportsForCycle = 3;

/// Outlier threshold: if a single user disagrees with >=3 others in 60s window, discard
const int kConsensusWindowSeconds = 60;
const int kConsensusMinAgreeingReports = 3;

/// Stale data decay thresholds
const int kStaleDataHalfLifeDays = 7;
const int kStaleDataArchiveDays = 30;

/// Schedule change detection threshold
const double kScheduleChangeVarianceThreshold = 0.20;
const int kScheduleChangeMinHours = 6;

/// Cycle length shift threshold that triggers re-learning freeze
const double kCycleLengthShiftThreshold = 0.15;
const int kRelearnFreezeHours = 24;

/// Confidence thresholds for badges
const double kConfidenceHigh = 0.75;
const double kConfidenceMedium = 0.50;

// ===================== AUDIO & HAPTICS =====================

/// Audio prompt strings - must be clear, concise, and never encourage unsafe driving
const String kPromptApproachUnknown =
    'Approach with caution. Signal status unknown.';
const String kPromptMaintainSpeedLimit =
    'Maintain speed limit. Next green in approximately %seconds% seconds.';
const String kPromptActuatedRange =
    'Typical wait: %min% to %max% seconds. Stay alert.';
const String kPromptSignalAhead = 'Signal ahead. Status?';
const String kPromptRelearning =
    'Signal schedule changed. Predictions temporarily unavailable. Drive carefully.';

/// Haptic patterns (vibration durations in milliseconds)
const List<int> kHapticStoppedAtRed = [500]; // 1 long vibration
const List<int> kHapticGreenSoon = [150, 100, 150]; // 2 short vibrations
const List<int> kHapticRerouteAvailable = [100, 100, 100, 100, 100]; // 3 pulses

// ===================== VOICE COMMANDS =====================

/// Wake phrase prefix for voice commands
const String kVoiceWakePhrase = 'hey signal';

/// Accepted color commands after wake phrase
const List<String> kVoiceCommandsRed = ['red', 'stop'];
const List<String> kVoiceCommandsGreen = ['green', 'go'];
const List<String> kVoiceCommandsYellow = ['yellow', 'caution'];

// ===================== PRIVACY & DATA =====================

/// Maximum retention period for raw GPS traces in hours
const int kMaxGpsRetentionHours = 24;

/// Hash algorithm for anonymizing device IDs in public datasets
const String kAnonymizationHashAlgorithm = 'SHA-256';

// ===================== FIREBASE =====================

/// Firestore collection names
const String kCollectionIntersections = 'intersections';
const String kCollectionSignalReports = 'signal_reports';
const String kCollectionPredictions = 'predictions';
const String kCollectionUsers = 'users';

// ===================== APP TEXT =====================

/// App name for display (must NEVER be "Red Light Predictor" per App Store compliance)
const String kAppDisplayName = 'SignalNav';
const String kAppSubtitle = 'Green Wave Assistant';

/// Required disclaimer text
const String kDisclaimerExperimental =
    'Experimental assistant. Does not replace traffic signals or laws.';
const String kDisclaimerLiability =
    'Signal predictions are community-generated estimates, not official traffic data. '
    'Always follow traffic laws and your own judgment.';
const String kDisclaimerIllinoisLaw =
    'This app is designed for hands-free use only. Illinois law prohibits using '
    'hand-held electronic devices while driving.';
