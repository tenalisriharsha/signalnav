# SignalNav - Setup Guide

Follow these steps to get SignalNav running locally and in production.

---

## 1. Configure API Keys (`.env`)

Copy the example file and fill in your keys:

```bash
cp .env.example .env
```

Edit `.env`:

```ini
# Get free API keys at:
# GraphHopper: https://www.graphhopper.com/
# TomTom:      https://developer.tomtom.com/

GRAPH_HOPPER_API_KEY=your_actual_key_here
TOMTOM_API_KEY=your_actual_key_here
```

**Never commit `.env` to Git.** It is already in `.gitignore`.

---

## 2. Firebase Setup

### Install Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

### Create Firebase Project

```bash
firebase projects:create signalnav-yourname
```

### Configure Flutter Firebase

```bash
cd signalnav
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart` and platform-specific config files.

### Deploy Security Rules

```bash
firebase deploy --only firestore:rules
```

---

## 3. Backend (GitHub Actions)

SignalNav uses **GitHub Actions** for the backend instead of Firebase Cloud Functions. This avoids the Blaze plan requirement.

### What runs on GitHub Actions

| Workflow | Schedule | Purpose |
|----------|----------|---------|
| `cycle-estimator.yml` | Every 15 min | Recalculates signal predictions |
| `report-aggregator.yml` | Every 10 min | Consensus filter + trust scoring |
| `stale-data-cleaner.yml` | Every 6 hours | Deletes old reports + GPS traces |

### Setup GitHub Actions

1. **Push this repo to GitHub** (must be public for free Actions minutes):
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   gh repo create signalnav --public --source=. --push
   ```

2. **Create a Firebase Service Account**:
   - Go to [Google Cloud Console > IAM & Admin > Service Accounts](https://console.cloud.google.com/iam-admin/serviceaccounts)
   - Select your Firebase project
   - Click **Create Service Account**
   - Name: `github-actions-backend`
   - Roles: `Cloud Datastore User`, `Firebase Admin`
   - Create Key → JSON → download the `.json` file

3. **Add the key to GitHub Secrets**:
   - Go to your GitHub repo → Settings → Secrets and variables → Actions
   - Click **New repository secret**
   - Name: `FIREBASE_SERVICE_ACCOUNT`
   - Value: Paste the entire contents of the downloaded JSON file

4. **Enable the workflows**:
   - Go to Actions tab in your GitHub repo
   - Click each workflow and hit "Enable"
   - Or manually trigger them with "Run workflow"

---

## 4. Run OSRM (Local Routing)

### Option A: Docker Compose (Recommended)

```bash
# From project root
docker compose up -d

# OSRM will download Illinois OSM data on first run (~5-10 minutes)
# Then serves on http://localhost:5000
```

### Option B: Manual Docker

```bash
mkdir -p osrm-data
docker run -t -v "$(pwd)/osrm-data:/data" osrm/osrm-backend \
  bash -c "wget -O /data/illinois.osm.pbf https://download.geofabrik.de/north-america/us/illinois-latest.osm.pbf && \
           osrm-extract -p /opt/car.lua /data/illinois.osm.pbf && \
           osrm-partition /data/illinois.osrm && \
           osrm-customize /data/illinois.osrm"

docker run -t -i -p 5000:5000 -v "$(pwd)/osrm-data:/data" osrm/osrm-backend \
  osrm-routed --algorithm mld /data/illinois.osrm
```

---

## 5. Seed Test Intersections

### Option A: From Flutter App (Debug Menu)
Add a temporary button in `MapScreen` that calls:

```dart
await ref.read(signalRepositoryProvider).seedSpringfieldIntersections();
```

### Option B: Standalone Dart Script

```bash
dart tools/seed_intersections.dart
```

Requires `GOOGLE_APPLICATION_CREDENTIALS` env var pointing to a service account key.

### Option C: Firebase Console (Manual)
Import `tools/intersections.json` (generate it first) into Firestore.

---

## 6. Run the App

```bash
# iOS Simulator
flutter run -d ios

# Android Emulator
flutter run -d android

# Or simply
flutter run
```

---

## Architecture (Spark Plan)

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│   Flutter App   │────▶│  OSRM Local  │     │ GraphHopper API │
│                 │     │   (Docker)   │────▶│   (Fallback)    │
│  - Driver Mode  │     └──────────────┘     └─────────────────┘
│  - Passenger    │
│  - Voice/TTS    │────▶┌──────────────┐
└─────────────────┘     │  TomTom API  │
         │              │  (Enhancement)│
         │              └──────────────┘
         ▼
┌─────────────────┐     ┌─────────────────────────┐
│  Firebase Auth  │     │   Firebase Firestore    │
│  (Anon + Google)│     │  - intersections        │
└─────────────────┘     │  - signal_reports       │
         │              │  - predictions          │
         ▼              │  - users                │
┌─────────────────┐     │  - deletion_requests    │
│   GitHub Actions│     └─────────────────────────┘
│  (Free / Public)│              ▲
│  - cycle_estimator         │
│  - report_aggregator       │
│  - stale_data_cleaner      │
│  (reads/writes via        │
│   service account key)     │
└─────────────────┘
```

**Note:** No Firebase Cloud Functions are deployed. Everything backend runs on GitHub Actions scheduled workflows, keeping you on the free Spark plan.

---

## What You Lose vs Blaze Plan

| Feature | Spark (Current) | Blaze (Not Used) |
|---------|----------------|------------------|
| **Real-time triggers** | Predictions update every 15 min via cron | Instant on report submission |
| **Cloud Functions** | Not available | Available (requires Blaze) |
| **Cost** | $0 | ~$0 at low scale, but requires credit card |
| **Backend uptime** | Runs on GitHub Actions schedule | Always-on serverless functions |

For an MVP, the 15-minute prediction delay is acceptable. If you need real-time predictions later, you can upgrade to Blaze and deploy Firebase Functions.

---

## Production Checklist

Before releasing to App Store / Play Store:

- [ ] Replace placeholder Terms of Service with lawyer-approved copy
- [ ] Replace placeholder Privacy Policy with lawyer-approved copy
- [ ] Update `kNominatimUserAgent` in `constants.dart` with your real contact email
- [ ] Configure custom Firebase Hosting domain for privacy policy URL
- [ ] Add crash reporting (Firebase Crashlytics)
- [ ] Test voice commands with real road noise
- [ ] Conduct battery drain test (target <5% per 30min drive)
- [ ] Verify UI lock at 6 mph, unlock below 5 mph
- [ ] Run full testing checklist from README.md
