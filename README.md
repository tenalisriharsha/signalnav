# SignalNav

**Cross-platform crowdsourced traffic signal navigator.**
Hands-free, voice-first navigation for Springfield, Illinois (expandable to any city).

## Overview

SignalNav provides turn-by-turn routing with live traffic and uses crowdsourced + trajectory-inferred data to estimate traffic signal states. It calculates an optimal "Green Wave" speed to minimize stops while **never** encouraging unsafe driving, screen interaction while moving, or speeding.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart) |
| State Management | Riverpod |
| Maps | MapLibre GL + OpenStreetMap |
| Routing | Self-hosted OSRM / GraphHopper fallback |
| Live Traffic | TomTom Traffic API (enhancement only) |
| Backend | Firebase (Spark Plan) |
| Cloud Functions | Python (Firebase Functions v2) |
| Voice | flutter_tts + speech_to_text |
| CI/CD | GitHub Actions |

## Safety First

SignalNav enforces safety at the architecture level:

- **Speed-based UI lock**: All manual buttons disabled above 5 mph
- **Voice-first design**: All driver info via TTS + haptics
- **Never suggests illegal speeds**: GLOSA clamped to posted limit
- **No countdown timers**: Only spoken ranges or single announcements
- **Auto-dim screen**: 10% brightness at night unless plugged in + passenger mode
- **Headphone safety**: Audio guidance stops if headphones disconnect

## Project Structure

```
/lib
  /core          # Constants, errors, logger
  /data
    /models      # Intersection, SignalReport, RouteSegment, Prediction
    /repositories # OSRM, TomTom, Signal, Nominatim
    /services    # Firebase, Location, Audio
  /domain
    /usecases    # GetOptimalRoute, ReportSignalState, PredictSignalState, CalculateGreenWaveSpeed
  /presentation
    /providers   # Riverpod providers
    /screens     # Splash, Onboarding, Map, Navigation, Settings
    /widgets     # SpeedometerOverlay, AudioModeIndicator, ConfidenceBadge
  /utils         # SafetyValidator, PrivacyAnonymizer, ConsensusFilter
/functions
  /src
    cycle_estimator.py      # ML cycle length estimator
    report_aggregator.py    # Consensus + trust scoring
    stale_data_cleaner.py   # Scheduled cleanup
```

## Getting Started

### Prerequisites

- Flutter 3.19+
- Firebase CLI
- Python 3.11+ (for Cloud Functions)

### Flutter Setup

```bash
cd signalnav
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

### Firebase Setup

```bash
# Install Firebase CLI if needed
npm install -g firebase-tools

# Login and initialize
firebase login
firebase init

# Deploy functions
firebase deploy --only functions
```

### OSRM Setup (Local Routing)

```bash
# Pull and run OSRM backend
docker run -t -i -p 5000:5000 -v "$(pwd)/data:/data" osrm/osrm-backend osrm-routed --algorithm mld /data/illinois.osrm
```

## Configuration

Update API keys in `lib/core/constants.dart`:

```dart
const String kGraphHopperApiKey = 'YOUR_KEY'; // Optional fallback
const String kTomTomApiKey = 'YOUR_KEY';      // Optional traffic enhancement
```

## Database Schema

See specification for full Firestore schema. Collections:
- `intersections` - Public signal metadata
- `signal_reports` - Raw anonymized reports (auto-deleted after 24h)
- `predictions` - Aggregated public predictions
- `users` - Private user data

## Compliance

- **GDPR/CCPA Ready**: Export and delete account flows implemented
- **Privacy**: Zero raw GPS storage beyond 24 hours, zero data sales
- **App Store Safe**: Named "SignalNav" / "Green Wave Assistant", never "Red Light Predictor"

## Testing Checklist

- [ ] Drive MacArthur Blvd, Dirksen Pkwy, Veterans Pkwy with app running
- [ ] Test voice commands with windows down and music at 60% volume
- [ ] Verify UI locks at 6 mph, unlocks below 5 mph
- [ ] Simulate 10 users reporting conflicting colors; verify consensus filter
- [ ] Battery drain test: 30-minute drive
- [ ] Background execution: minimize app, verify geofence triggers
- [ ] Legal review: Replace placeholder ToS/Privacy Policy before v1.0

## License

MIT License - See LICENSE file

## Disclaimer

Signal predictions are community-generated estimates, not official traffic data. Always follow traffic laws and your own judgment. This app is designed for hands-free use only.
