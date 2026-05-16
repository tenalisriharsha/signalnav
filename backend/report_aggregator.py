#!/usr/bin/env python3
"""
SignalNav - Standalone Report Aggregator

Runs on a schedule (e.g., every 10 minutes via GitHub Actions).
Applies consensus filter and updates user trust scores.

Usage:
    export GOOGLE_APPLICATION_CREDENTIALS=service-account.json
    python report_aggregator.py
"""

import os
import sys
from datetime import datetime, timedelta, timezone
from collections import defaultdict

import firebase_admin
from firebase_admin import credentials, firestore

# Constants
CONSENSUS_WINDOW_SECONDS = 60
MIN_AGREEING_REPORTS = 3
TRUST_PENALTY_OUTLIER = 0.1
TRUST_REWARD_CORRECT = 0.02
STALE_DATA_HALF_LIFE_DAYS = 7
STALE_DATA_ARCHIVE_DAYS = 30


def group_into_windows(reports):
    if not reports:
        return []
    sorted_reports = sorted(reports, key=lambda r: r.get('timestamp', datetime.min))
    windows = []
    current_window = [sorted_reports[0]]

    for i in range(1, len(sorted_reports)):
        prev_time = current_window[0].get('timestamp', datetime.min)
        curr_time = sorted_reports[i].get('timestamp', datetime.min)
        if isinstance(prev_time, datetime) and isinstance(curr_time, datetime):
            if (curr_time - prev_time).total_seconds() <= CONSENSUS_WINDOW_SECONDS:
                current_window.append(sorted_reports[i])
            else:
                windows.append(current_window)
                current_window = [sorted_reports[i]]
        else:
            current_window.append(sorted_reports[i])

    if current_window:
        windows.append(current_window)
    return windows


def apply_consensus_filter(db, intersection_id, phase, window):
    if len(window) < 2:
        return

    color_counts = defaultdict(int)
    for r in window:
        color_counts[r.get('color', 'unknown')] += 1

    dominant_color = max(color_counts, key=color_counts.get)
    dominant_count = color_counts[dominant_color]

    for r in window:
        ref = db.collection('signal_reports').document(r['id'])
        if r.get('color') != dominant_color:
            if dominant_count >= MIN_AGREEING_REPORTS:
                ref.update({
                    'consensus_outlier': True,
                    'consensus_dominant_color': dominant_color,
                })
                penalize_reporter(db, r.get('device_hash'))
            else:
                ref.update({'consensus_outlier': False})
        else:
            ref.update({'consensus_outlier': False})
            reward_reporter(db, r.get('device_hash'))


def penalize_reporter(db, device_hash):
    if not device_hash:
        return
    user_docs = (
        db.collection('users')
        .where('device_hash', '==', device_hash)
        .limit(1)
        .stream()
    )
    for doc in user_docs:
        current_trust = doc.to_dict().get('trust_score', 1.0)
        doc.reference.update({'trust_score': max(0.1, current_trust - TRUST_PENALTY_OUTLIER)})


def reward_reporter(db, device_hash):
    if not device_hash:
        return
    user_docs = (
        db.collection('users')
        .where('device_hash', '==', device_hash)
        .limit(1)
        .stream()
    )
    for doc in user_docs:
        current_trust = doc.to_dict().get('trust_score', 1.0)
        doc.reference.update({'trust_score': min(5.0, current_trust + TRUST_REWARD_CORRECT)})


def update_trust_scores(db, reports):
    reporter_stats = defaultdict(lambda: {'total': 0, 'helpful': 0})
    for r in reports:
        device_hash = r.get('device_hash')
        if not device_hash:
            continue
        reporter_stats[device_hash]['total'] += 1
        if not r.get('consensus_outlier', False):
            reporter_stats[device_hash]['helpful'] += 1

    for device_hash, stats in reporter_stats.items():
        user_docs = (
            db.collection('users')
            .where('device_hash', '==', device_hash)
            .limit(1)
            .stream()
        )
        for doc in user_docs:
            doc.reference.update({
                'total_reports': stats['total'],
                'reports_helped_drivers': stats['helpful'],
            })


def process_intersection_phase(db, intersection_id, phase):
    cutoff = datetime.now(timezone.utc) - timedelta(days=STALE_DATA_ARCHIVE_DAYS)
    reports_query = (
        db.collection('signal_reports')
        .where('intersection_id', '==', intersection_id)
        .where('phase', '==', phase)
        .where('timestamp', '>=', cutoff)
        .order_by('timestamp')
        .stream()
    )

    reports = []
    for doc in reports_query:
        data = doc.to_dict()
        data['id'] = doc.id
        reports.append(data)

    if len(reports) < 3:
        return

    windows = group_into_windows(reports)
    for window in windows:
        apply_consensus_filter(db, intersection_id, phase, window)

    update_trust_scores(db, reports)


def main():
    print(f"[{datetime.now(timezone.utc).isoformat()}] Starting report aggregation...")

    if not firebase_admin._apps:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)
    db = firestore.client()

    intersections = db.collection('intersections').stream()
    total_processed = 0

    for intersection_doc in intersections:
        intersection = intersection_doc.to_dict()
        intersection_id = intersection_doc.id
        for phase in intersection.get('phases', []):
            process_intersection_phase(db, intersection_id, phase)
            total_processed += 1

    print(f"[{datetime.now(timezone.utc).isoformat()}] Processed {total_processed} intersection/phase combos.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
