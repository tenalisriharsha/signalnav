/// SignalNav - Audio Mode Indicator
///
/// Shows whether the app is in audio-first driver mode.
/// Minimal visual indicator - no animations.

import 'package:flutter/material.dart';

class AudioModeIndicator extends StatelessWidget {
  const AudioModeIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green, width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.volume_up, color: Colors.green, size: 18),
          SizedBox(width: 6),
          Text(
            'AUDIO MODE',
            style: TextStyle(
              color: Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
