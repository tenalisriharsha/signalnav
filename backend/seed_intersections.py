#!/usr/bin/env python3
"""Seed Springfield test intersections into Firestore."""

import os
import sys
from datetime import datetime, timezone

import firebase_admin
from firebase_admin import credentials, firestore


def main():
    print("Seeding SignalNav test intersections...")

    sa_path = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS', 'NOT SET')
    print(f"Service account path: {sa_path}")

    try:
        if not firebase_admin._apps:
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred)
        db = firestore.client()
        print("Firebase initialized")
    except Exception as e:
        print(f"FATAL: Firebase init failed: {e}")
        return 1

    now = datetime.now(timezone.utc)

    intersections = [
        {"id": "springfield_5th_adams", "lat": 39.7817, "lng": -89.6501, "road_name": "5th St", "cross_street": "Adams St", "signal_type": "coordinated_actuated", "speed_limit_mph": 30, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_5th_jefferson", "lat": 39.7830, "lng": -89.6501, "road_name": "5th St", "cross_street": "Jefferson St", "signal_type": "coordinated_actuated", "speed_limit_mph": 30, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_5th_monroe", "lat": 39.7843, "lng": -89.6501, "road_name": "5th St", "cross_street": "Monroe St", "signal_type": "pre_timed", "speed_limit_mph": 30, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_6th_adams", "lat": 39.7817, "lng": -89.6488, "road_name": "6th St", "cross_street": "Adams St", "signal_type": "coordinated_actuated", "speed_limit_mph": 30, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_6th_jefferson", "lat": 39.7830, "lng": -89.6488, "road_name": "6th St", "cross_street": "Jefferson St", "signal_type": "coordinated_actuated", "speed_limit_mph": 30, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_6th_monroe", "lat": 39.7843, "lng": -89.6488, "road_name": "6th St", "cross_street": "Monroe St", "signal_type": "pre_timed", "speed_limit_mph": 30, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_4th_adams", "lat": 39.7817, "lng": -89.6514, "road_name": "4th St", "cross_street": "Adams St", "signal_type": "fully_actuated", "speed_limit_mph": 25, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_4th_jefferson", "lat": 39.7830, "lng": -89.6514, "road_name": "4th St", "cross_street": "Jefferson St", "signal_type": "fully_actuated", "speed_limit_mph": 25, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_macarthur_dirksen", "lat": 39.7950, "lng": -89.6700, "road_name": "MacArthur Blvd", "cross_street": "Dirksen Pkwy", "signal_type": "coordinated_actuated", "speed_limit_mph": 45, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_macarthur_veterans", "lat": 39.7950, "lng": -89.6800, "road_name": "MacArthur Blvd", "cross_street": "Veterans Pkwy", "signal_type": "coordinated_actuated", "speed_limit_mph": 45, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_dirksen_5th", "lat": 39.7900, "lng": -89.6700, "road_name": "Dirksen Pkwy", "cross_street": "5th St", "signal_type": "pre_timed", "speed_limit_mph": 40, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_dirksen_6th", "lat": 39.7900, "lng": -89.6687, "road_name": "Dirksen Pkwy", "cross_street": "6th St", "signal_type": "pre_timed", "speed_limit_mph": 40, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_veterans_5th", "lat": 39.8000, "lng": -89.6800, "road_name": "Veterans Pkwy", "cross_street": "5th St", "signal_type": "coordinated_actuated", "speed_limit_mph": 45, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_veterans_6th", "lat": 39.8000, "lng": -89.6787, "road_name": "Veterans Pkwy", "cross_street": "6th St", "signal_type": "coordinated_actuated", "speed_limit_mph": 45, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_9th_cook", "lat": 39.7760, "lng": -89.6440, "road_name": "9th St", "cross_street": "Cook St", "signal_type": "fully_actuated", "speed_limit_mph": 25, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_9th_edwards", "lat": 39.7773, "lng": -89.6440, "road_name": "9th St", "cross_street": "Edwards St", "signal_type": "fully_actuated", "speed_limit_mph": 25, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_11th_madison", "lat": 39.7786, "lng": -89.6420, "road_name": "11th St", "cross_street": "Madison St", "signal_type": "pre_timed", "speed_limit_mph": 30, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_11th_jefferson", "lat": 39.7830, "lng": -89.6420, "road_name": "11th St", "cross_street": "Jefferson St", "signal_type": "pre_timed", "speed_limit_mph": 30, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_2nd_capital", "lat": 39.7850, "lng": -89.6530, "road_name": "2nd St", "cross_street": "Capital Ave", "signal_type": "coordinated_actuated", "speed_limit_mph": 30, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
        {"id": "springfield_2nd_monroe", "lat": 39.7843, "lng": -89.6530, "road_name": "2nd St", "cross_street": "Monroe St", "signal_type": "coordinated_actuated", "speed_limit_mph": 30, "phases": ["NB_through", "SB_through", "EB_through", "WB_through"], "confidence_status": "low", "last_updated": now},
    ]

    batch = db.batch()
    for intersection in intersections:
        ref = db.collection('intersections').document(intersection['id'])
        data = {k: v for k, v in intersection.items() if k != 'id'}
        batch.set(ref, data)

    batch.commit()
    print(f"Seeded {len(intersections)} intersections successfully.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
