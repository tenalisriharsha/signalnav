#!/usr/bin/env python3
"""
SignalNav - Standalone Cycle Estimator

Runs on a schedule (e.g., every 15 minutes via GitHub Actions).
Processes recent signal reports and generates predictions.

Usage:
    export GOOGLE_APPLICATION_CREDENTIALS=service-account.json
    python cycle_estimator.py
"""

import os
import sys
import statistics
from datetime import datetime, timedelta, timezone
from collections import defaultdict

import firebase_admin
from firebase_admin import credentials, firestore

# Constants
TIME_BUCKET_MINUTES = 30
MIN_REPORTS_FOR_CYCLE = 3
SCHEDULE_CHANGE_THRESHOLD = 0.15
VARIANCE_THRESHOLD = 0.20


def get_time_bucket(dt: datetime) -> str:
    bucket_minute = (dt.minute // TIME_BUCKET_MINUTES) * TIME_BUCKET_MINUTES
    return f"{dt.hour:02d}:{bucket_minute:02d}"


def calculate_mode(values):
    if not values:
        return None
    counts = {}
    mode_val = values[0]
    max_count = 0
    for v in values:
        counts[v] = counts.get(v, 0) + 1
        if counts[v] > max_count:
            max_count = counts[v]
            mode_val = v
    return mode_val


def calculate_variance(values):
    if len(values) < 2:
        return float('inf')
    mean = statistics.mean(values)
    if mean == 0:
        return float('inf')
    stddev = statistics.stdev(values)
    return stddev / mean


def calculate_confidence(report_count, variance, signal_type):
    if report_count >= 50:
        count_conf = 1.0
    elif report_count >= 20:
        count_conf = 0.8
    elif report_count >= 10:
        count_conf = 0.6
    elif report_count >= 3:
        count_conf = 0.4
    else:
        count_conf = 0.2

    if variance > VARIANCE_THRESHOLD:
        var_conf = 0.3
    elif variance > 0.10:
        var_conf = 0.7
    else:
        var_conf = 1.0

    if signal_type == 'fully_actuated':
        type_conf = 0.5
    elif signal_type == 'coordinated_actuated':
        type_conf = 0.9
    else:
        type_conf = 0.8

    return min(1.0, count_conf * var_conf * type_conf)


def estimate_cycle_length(report_docs):
    sorted_reports = sorted(report_docs, key=lambda r: r.get('timestamp', datetime.min))
    green_starts = []
    for i in range(1, len(sorted_reports)):
        prev = sorted_reports[i - 1]
        curr = sorted_reports[i]
        if prev.get('color') == 'red' and curr.get('color') == 'green':
            ts = curr.get('timestamp')
            if isinstance(ts, datetime):
                green_starts.append(ts)

    if len(green_starts) < 2:
        return None, float('inf'), len(green_starts)

    gaps = []
    for i in range(1, len(green_starts)):
        gap = (green_starts[i] - green_starts[i - 1]).total_seconds()
        if gap > 10:
            gaps.append(gap)

    if len(gaps) < MIN_REPORTS_FOR_CYCLE:
        return None, float('inf'), len(green_starts)

    cycle_length = calculate_mode(gaps)
    variance = calculate_variance(gaps)
    return cycle_length, variance, len(green_starts)


def detect_schedule_change(db, intersection_id, phase, current_cycle):
    seven_days_ago = datetime.now(timezone.utc) - timedelta(days=7)
    docs = (
        db.collection('predictions')
        .where('intersection_id', '==', intersection_id)
        .where('phase', '==', phase)
        .where('updated_at', '>=', seven_days_ago)
        .stream()
    )

    historical_cycles = []
    for doc in docs:
        data = doc.to_dict()
        cl = data.get('cycle_length_seconds')
        if cl is not None:
            historical_cycles.append(float(cl))

    if len(historical_cycles) < 3:
        return False

    historical_avg = statistics.mean(historical_cycles)
    if historical_avg == 0:
        return False

    shift = abs(current_cycle - historical_avg) / historical_avg
    return shift > SCHEDULE_CHANGE_THRESHOLD


def update_prediction(db, intersection_id, phase, time_bucket, data):
    existing = (
        db.collection('predictions')
        .where('intersection_id', '==', intersection_id)
        .where('phase', '==', phase)
        .where('time_bucket', '==', time_bucket)
        .limit(1)
        .stream()
    )

    doc_id = None
    for doc in existing:
        doc_id = doc.id

    payload = {
        'intersection_id': intersection_id,
        'phase': phase,
        'time_bucket': time_bucket,
        'updated_at': datetime.now(timezone.utc),
        **data,
    }

    if doc_id:
        db.collection('predictions').document(doc_id).set(payload, merge=True)
    else:
        db.collection('predictions').add(payload)


def main():
    print(f"[{datetime.now(timezone.utc).isoformat()}] Starting cycle estimator...")

    # Initialize Firebase
    if not firebase_admin._apps:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)
    db = firestore.client()

    # Fetch all intersections
    intersections = db.collection('intersections').stream()

    total_updated = 0
    for intersection_doc in intersections:
        intersection = intersection_doc.to_dict()
        intersection_id = intersection_doc.id
        signal_type = intersection.get('signal_type', 'pre_timed')

        for phase in intersection.get('phases', []):
            cutoff = datetime.now(timezone.utc) - timedelta(days=7)
            reports_query = (
                db.collection('signal_reports')
                .where('intersection_id', '==', intersection_id)
                .where('phase', '==', phase)
                .where('timestamp', '>=', cutoff)
                .stream()
            )

            report_docs = []
            for r in reports_query:
                rd = r.to_dict()
                rd['id'] = r.id
                report_docs.append(rd)

            if len(report_docs) < MIN_REPORTS_FOR_CYCLE:
                continue

            # Group by time bucket
            bucketed = defaultdict(list)
            for rd in report_docs:
                ts = rd.get('timestamp')
                if isinstance(ts, datetime):
                    bucket = get_time_bucket(ts)
                    bucketed[bucket].append(rd)

            for bucket, bucket_reports in bucketed.items():
                cycle_length, variance, transition_count = estimate_cycle_length(bucket_reports)

                if cycle_length is None:
                    continue

                if detect_schedule_change(db, intersection_id, phase, cycle_length):
                    update_prediction(db, intersection_id, phase, bucket, {
                        'cycle_length_seconds': None,
                        'green_start_prediction': None,
                        'confidence': 0.0,
                        'prediction_type': 'relearning',
                        'typical_wait_min_seconds': None,
                        'typical_wait_max_seconds': None,
                    })
                    continue

                if signal_type == 'fully_actuated' or variance > VARIANCE_THRESHOLD:
                    waits = []
                    for i, rd in enumerate(bucket_reports):
                        if rd.get('color') == 'red':
                            for j in range(i + 1, len(bucket_reports)):
                                if bucket_reports[j].get('color') == 'green':
                                    wait = (bucket_reports[j]['timestamp'] - rd['timestamp']).total_seconds()
                                    waits.append(wait)
                                    break

                    typical_min = int(min(waits)) if waits else None
                    typical_max = int(max(waits)) if waits else None
                    confidence = calculate_confidence(len(bucket_reports), variance, signal_type)

                    update_prediction(db, intersection_id, phase, bucket, {
                        'cycle_length_seconds': None,
                        'green_start_prediction': None,
                        'confidence': confidence,
                        'prediction_type': 'actuated_range',
                        'typical_wait_min_seconds': typical_min,
                        'typical_wait_max_seconds': typical_max,
                    })
                else:
                    last_green = None
                    for rd in sorted(bucket_reports, key=lambda x: x.get('timestamp', datetime.min), reverse=True):
                        if rd.get('color') == 'green':
                            last_green = rd.get('timestamp')
                            break

                    next_green = None
                    if last_green and isinstance(last_green, datetime):
                        now = datetime.now(timezone.utc)
                        n = 1
                        while last_green + timedelta(seconds=cycle_length * n) < now:
                            n += 1
                        next_green = last_green + timedelta(seconds=cycle_length * n)

                    confidence = calculate_confidence(len(bucket_reports), variance, signal_type)

                    update_prediction(db, intersection_id, phase, bucket, {
                        'cycle_length_seconds': int(cycle_length),
                        'green_start_prediction': next_green,
                        'confidence': confidence,
                        'prediction_type': 'coordinated',
                        'typical_wait_min_seconds': None,
                        'typical_wait_max_seconds': None,
                    })
                total_updated += 1

    print(f"[{datetime.now(timezone.utc).isoformat()}] Updated {total_updated} predictions.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
