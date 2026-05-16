/// SignalNav - Confidence Badge
///
/// Colorblind-safe badge showing prediction confidence.
/// Uses icon + text + color. Never relies on color alone.

import 'package:flutter/material.dart';
import '../../data/models/intersection.dart';

class ConfidenceBadge extends StatelessWidget {
  final ConfidenceStatus status;
  final bool showLabel;

  const ConfidenceBadge({
    super.key,
    required this.status,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _badgeData();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  (Color, IconData, String) _badgeData() {
    switch (status) {
      case ConfidenceStatus.high:
        return (Colors.green, Icons.check_circle, 'High Confidence');
      case ConfidenceStatus.medium:
        return (Colors.orange, Icons.warning, 'Medium Confidence');
      case ConfidenceStatus.low:
        return (Colors.red, Icons.error, 'Low Confidence');
    }
  }
}
