#!/usr/bin/env dart
/// SignalNav - Seed Intersections Tool
///
/// Run this script to populate Firestore with the Springfield test intersections.
///
/// Usage:
///   dart tools/seed_intersections.dart
///
/// Prerequisites:
///   - Firebase project configured
///   - GOOGLE_APPLICATION_CREDENTIALS environment variable set (for admin SDK)
///   OR run within a Flutter app context.

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  print('SignalNav - Seeding Intersections');
  print('==================================');

  try {
    await Firebase.initializeApp();
    final firestore = FirebaseFirestore.instance;

    final intersections = _getSpringfieldIntersections();
    final batch = firestore.batch();

    for (final intersection in intersections) {
      final ref = firestore.collection('intersections').doc(intersection['id']);
      final data = Map<String, dynamic>.from(intersection);
      data.remove('id');
      batch.set(ref, data);
    }

    await batch.commit();
    print('Successfully seeded ${intersections.length} intersections.');
    exit(0);
  } catch (e, stackTrace) {
    print('ERROR: Failed to seed intersections.');
    print(e);
    print(stackTrace);
    exit(1);
  }
}

List<Map<String, dynamic>> _getSpringfieldIntersections() {
  final now = DateTime.now().toUtc();
  return [
    {
      'id': 'springfield_5th_adams',
      'lat': 39.7817,
      'lng': -89.6501,
      'road_name': '5th St',
      'cross_street': 'Adams St',
      'signal_type': 'coordinated_actuated',
      'speed_limit_mph': 30,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_5th_jefferson',
      'lat': 39.7830,
      'lng': -89.6501,
      'road_name': '5th St',
      'cross_street': 'Jefferson St',
      'signal_type': 'coordinated_actuated',
      'speed_limit_mph': 30,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_5th_monroe',
      'lat': 39.7843,
      'lng': -89.6501,
      'road_name': '5th St',
      'cross_street': 'Monroe St',
      'signal_type': 'pre_timed',
      'speed_limit_mph': 30,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_6th_adams',
      'lat': 39.7817,
      'lng': -89.6488,
      'road_name': '6th St',
      'cross_street': 'Adams St',
      'signal_type': 'coordinated_actuated',
      'speed_limit_mph': 30,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_6th_jefferson',
      'lat': 39.7830,
      'lng': -89.6488,
      'road_name': '6th St',
      'cross_street': 'Jefferson St',
      'signal_type': 'coordinated_actuated',
      'speed_limit_mph': 30,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_6th_monroe',
      'lat': 39.7843,
      'lng': -89.6488,
      'road_name': '6th St',
      'cross_street': 'Monroe St',
      'signal_type': 'pre_timed',
      'speed_limit_mph': 30,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_4th_adams',
      'lat': 39.7817,
      'lng': -89.6514,
      'road_name': '4th St',
      'cross_street': 'Adams St',
      'signal_type': 'fully_actuated',
      'speed_limit_mph': 25,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_4th_jefferson',
      'lat': 39.7830,
      'lng': -89.6514,
      'road_name': '4th St',
      'cross_street': 'Jefferson St',
      'signal_type': 'fully_actuated',
      'speed_limit_mph': 25,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_macarthur_dirksen',
      'lat': 39.7950,
      'lng': -89.6700,
      'road_name': 'MacArthur Blvd',
      'cross_street': 'Dirksen Pkwy',
      'signal_type': 'coordinated_actuated',
      'speed_limit_mph': 45,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_macarthur_veterans',
      'lat': 39.7950,
      'lng': -89.6800,
      'road_name': 'MacArthur Blvd',
      'cross_street': 'Veterans Pkwy',
      'signal_type': 'coordinated_actuated',
      'speed_limit_mph': 45,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_dirksen_5th',
      'lat': 39.7900,
      'lng': -89.6700,
      'road_name': 'Dirksen Pkwy',
      'cross_street': '5th St',
      'signal_type': 'pre_timed',
      'speed_limit_mph': 40,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_dirksen_6th',
      'lat': 39.7900,
      'lng': -89.6687,
      'road_name': 'Dirksen Pkwy',
      'cross_street': '6th St',
      'signal_type': 'pre_timed',
      'speed_limit_mph': 40,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_veterans_5th',
      'lat': 39.8000,
      'lng': -89.6800,
      'road_name': 'Veterans Pkwy',
      'cross_street': '5th St',
      'signal_type': 'coordinated_actuated',
      'speed_limit_mph': 45,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_veterans_6th',
      'lat': 39.8000,
      'lng': -89.6787,
      'road_name': 'Veterans Pkwy',
      'cross_street': '6th St',
      'signal_type': 'coordinated_actuated',
      'speed_limit_mph': 45,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_9th_cook',
      'lat': 39.7760,
      'lng': -89.6440,
      'road_name': '9th St',
      'cross_street': 'Cook St',
      'signal_type': 'fully_actuated',
      'speed_limit_mph': 25,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_9th_edwards',
      'lat': 39.7773,
      'lng': -89.6440,
      'road_name': '9th St',
      'cross_street': 'Edwards St',
      'signal_type': 'fully_actuated',
      'speed_limit_mph': 25,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_11th_madison',
      'lat': 39.7786,
      'lng': -89.6420,
      'road_name': '11th St',
      'cross_street': 'Madison St',
      'signal_type': 'pre_timed',
      'speed_limit_mph': 30,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_11th_jefferson',
      'lat': 39.7830,
      'lng': -89.6420,
      'road_name': '11th St',
      'cross_street': 'Jefferson St',
      'signal_type': 'pre_timed',
      'speed_limit_mph': 30,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_2nd_capital',
      'lat': 39.7850,
      'lng': -89.6530,
      'road_name': '2nd St',
      'cross_street': 'Capital Ave',
      'signal_type': 'coordinated_actuated',
      'speed_limit_mph': 30,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
    {
      'id': 'springfield_2nd_monroe',
      'lat': 39.7843,
      'lng': -89.6530,
      'road_name': '2nd St',
      'cross_street': 'Monroe St',
      'signal_type': 'coordinated_actuated',
      'speed_limit_mph': 30,
      'phases': ['NB_through', 'SB_through', 'EB_through', 'WB_through'],
      'confidence_status': 'low',
      'last_updated': now,
    },
  ];
}
