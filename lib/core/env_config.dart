/// SignalNav - Environment Configuration
///
/// Loads API keys and runtime config from .env file.
/// Never commit .env to version control.

import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get osrmBaseUrl =>
      dotenv.env['OSRM_BASE_URL'] ?? 'http://localhost:5000';

  static String? get graphHopperApiKey =>
      dotenv.env['GRAPH_HOPPER_API_KEY'];

  static String get graphHopperBaseUrl =>
      'https://graphhopper.com/api/1';

  static String? get tomTomApiKey =>
      dotenv.env['TOMTOM_API_KEY'];

  static String get tomTomTrafficBaseUrl =>
      'https://api.tomtom.com/traffic/services/4';

  static bool get hasGraphHopperKey =>
      graphHopperApiKey != null && graphHopperApiKey != 'YOUR_GRAPH_HOPPER_KEY';

  static bool get hasTomTomKey =>
      tomTomApiKey != null && tomTomApiKey != 'YOUR_TOMTOM_KEY';

  /// Initialize environment. Call before app startup.
  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
  }
}
