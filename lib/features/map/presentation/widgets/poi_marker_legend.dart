import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../mappers/poi_marker_style.dart';

/// Compact legend displaying the Vienna POI marker categories.
class PoiMarkerLegend extends StatelessWidget {
  const PoiMarkerLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [
            for (final category in PoiMarkerCategory.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    category.assetPath,
                    width: 18,
                    height: 22,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    category.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
