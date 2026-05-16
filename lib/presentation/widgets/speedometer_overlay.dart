/// SignalNav - Speedometer Overlay
///
/// Large, high-contrast speed display for driver mode.
/// Colorblind-safe: uses text + icon, never red/green as sole indicator.

import 'package:flutter/material.dart';

class SpeedometerOverlay extends StatelessWidget {
  final double speedMph;
  final int? speedLimit;

  const SpeedometerOverlay({
    super.key,
    required this.speedMph,
    this.speedLimit,
  });

  @override
  Widget build(BuildContext context) {
    final isOverLimit = speedLimit != null && speedMph > speedLimit!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Speed digits - very large for glanceability
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              speedMph.round().toString(),
              style: TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.bold,
                color: isOverLimit ? Colors.orange : Colors.white,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                'mph',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white54,
                ),
              ),
            ),
          ],
        ),

        // Speed limit display
        if (speedLimit != null)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(8),
              color: isOverLimit ? Colors.orange.withOpacity(0.2) : Colors.transparent,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'LIMIT',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  speedLimit.toString(),
                  style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        // Over limit warning
        if (isOverLimit)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade900.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'SPEED LIMIT EXCEEDED',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
