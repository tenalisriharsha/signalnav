#!/usr/bin/env python3
"""
SignalNav - Standalone Stale Data Cleaner

Runs on a schedule (e.g., every 6 hours via GitHub Actions).
Deletes old signal reports and strips GPS data.

Usage:
    export GOOGLE_APPLICATION_CREDENTIALS=service-account.json
    python stale_data_cleaner.py
"""

import os
import sys
from datetime import datetime, timedelta, timezone

import firebase_admin
from firebase_admin import credentials, firestore

# Constants
MAX_GPS_RETENTION_HOURS = 24
STALE_DATA_ARCHIVE_DAYS = 30
BATCH_SIZE = 500


def delete_old_reports(db):
    cutoff = datetime.now(timezone.utc) - timedelta(hours=MAX_GPS_RETENTION_HOURS)
    old_reports = (
        db.collection('signal_reports')
        .where('timestamp', '<', cutoff)
        .where('archived', '!=', True)
        .limit(BATCH_SIZE)
        .stream()
    )

    count = 0
    batch = db.batch()
    for doc in old_reports:
        batch.delete(doc.reference)
        count += 1

    if count > 0:
        batch.commit()
        print(f"Deleted {count} old reports (older than {MAX_GPS_RETENTION_HOURS}h)")
    return count


def archive_very_old_reports(db):
    archive_cutoff = datetime.now(timezone.utc) - timedelta(days=STALE_DATA_ARCHIVE_DAYS)
    old_reports = (
        db.collection('signal_reports')
        .where('timestamp', '<', archive_cutoff)
        .where('archived', '!=', True)
        .limit(BATCH_SIZE)
        .stream()
    )

    count = 0
    batch = db.batch()
    for doc in old_reports:
        batch.update(doc.reference, {
            'archived': True,
            'raw_gps_stripped': True,
        })
        count += 1

    if count > 0:
        batch.commit()
        print(f"Archived {count} very old reports (older than {STALE_DATA_ARCHIVE_DAYS} days)")
    return count


def strip_gps_from_remaining(db):
    recent_reports = (
        db.collection('signal_reports')
        .limit(BATCH_SIZE)
        .stream()
    )

    count = 0
    batch = db.batch()
    for doc in recent_reports:
        data = doc.to_dict()
        updates = {}
        gps_fields = ['raw_lat', 'raw_lng', 'exact_location', 'gps_trace']
        for field in gps_fields:
            if field in data:
                updates[field] = firestore.DELETE_FIELD
        if updates:
            batch.update(doc.reference, updates)
            count += 1

    if count > 0:
        batch.commit()
        print(f"Stripped GPS from {count} reports")
    return count


def process_deletion_requests(db):
    """Process GDPR/CCPA deletion requests from the queue."""
    requests = (
        db.collection('deletion_requests')
        .where('status', '==', 'pending')
        .limit(BATCH_SIZE)
        .stream()
    )

    processed = 0
    for req in requests:
        data = req.to_dict()
        uid = data.get('uid')
        device_hash = data.get('device_hash')

        if not uid or not device_hash:
            req.reference.update({'status': 'failed', 'error': 'Missing uid or device_hash'})
            continue

        # Anonymize reports
        reports = (
            db.collection('signal_reports')
            .where('device_hash', '==', device_hash)
            .limit(BATCH_SIZE)
            .stream()
        )

        batch = db.batch()
        for report in reports:
            batch.update(report.reference, {
                'device_hash': 'deleted_user',
                'trust_score': firestore.DELETE_FIELD,
            })
        batch.commit()

        # Delete user doc
        user_docs = (
            db.collection('users')
            .where('uid', '==', uid)
            .limit(1)
            .stream()
        )
        for user_doc in user_docs:
            user_doc.reference.delete()

        req.reference.update({
            'status': 'completed',
            'completed_at': datetime.now(timezone.utc),
        })
        processed += 1

    if processed > 0:
        print(f"Processed {processed} deletion requests")
    return processed


def main():
    print(f"[{datetime.now(timezone.utc).isoformat()}] Starting stale data cleanup...")

    # Debug: show what auth method is available
    sa_path = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS', 'NOT SET')
    print(f"Service account path: {sa_path}")
    if sa_path != 'NOT SET' and os.path.exists(sa_path):
        print(f"Service account file exists, size: {os.path.getsize(sa_path)} bytes")
    else:
        print("WARNING: Service account file not found at path")

    try:
        if not firebase_admin._apps:
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred)
        db = firestore.client()
        print("Firebase initialized successfully")
    except Exception as e:
        print(f"FATAL: Firebase initialization failed: {e}")
        return 1

    deleted = delete_old_reports(db)
    archived = archive_very_old_reports(db)
    stripped = strip_gps_from_remaining(db)
    deletion_processed = process_deletion_requests(db)

    print(f"[{datetime.now(timezone.utc).isoformat()}] Cleanup complete: "
          f"{deleted} deleted, {archived} archived, {stripped} stripped, "
          f"{deletion_processed} deletions processed.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
