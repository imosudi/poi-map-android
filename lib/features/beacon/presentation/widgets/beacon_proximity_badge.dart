import 'package:flutter/material.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/beacon_proximity_models.dart';

/// Qualitative proximity badge for POI cards and map selection details.
///
/// Uses qualitative radio-signal labels rather than exact distance estimates.
class BeaconProximityBadge extends StatelessWidget {
  const BeaconProximityBadge({super.key, required this.state});

  final BeaconProximityState state;

  @override
  Widget build(BuildContext context) {
    if (state != BeaconProximityState.inProximity &&
        state != BeaconProximityState.nearby) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isClose = state == BeaconProximityState.inProximity;
    final label = isClose ? 'In proximity (beacon)' : 'Nearby (beacon)';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isClose
            ? AppPalette.accentSoft
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bluetooth_searching_rounded,
            size: 13,
            color: isClose
                ? AppPalette.accent
                : theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isClose
                  ? AppPalette.accent
                  : theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
