import 'package:flutter/material.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../poi/domain/entities/poi.dart';

/// Compact, dismissible information card for the currently selected [Poi].
class SelectedPoiCard extends StatelessWidget {
  const SelectedPoiCard({
    super.key,
    required this.poi,
    required this.onDismiss,
    this.distanceLabel,
    this.isSaved = false,
    this.onSave,
    this.onRequestLocation,
  });

  final Poi poi;
  final VoidCallback onDismiss;
  final String? distanceLabel;
  final bool isSaved;
  final VoidCallback? onSave;
  final VoidCallback? onRequestLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppPalette.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                AppAssets.viennaShield,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poi.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (poi.category != null && poi.category!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      poi.category!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppPalette.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (poi.address != null && poi.address!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Image.asset(
                          AppAssets.mapPin,
                          width: 14,
                          height: 14,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            poi.address!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (distanceLabel != null && distanceLabel!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Image.asset(
                          AppAssets.navigationArrow,
                          width: 14,
                          height: 14,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            distanceLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Image.asset(
                          AppAssets.navigationArrow,
                          width: 14,
                          height: 14,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Grant location access for distance information.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (onRequestLocation != null)
                          TextButton(
                            onPressed: onRequestLocation,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Allow'),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  if (isSaved)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.accentSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            AppAssets.favouriteStar,
                            width: 14,
                            height: 14,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Saved to places',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppPalette.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (onSave != null)
                    OutlinedButton.icon(
                      onPressed: onSave,
                      icon: Image.asset(
                        AppAssets.favouriteStar,
                        width: 16,
                        height: 16,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                      label: const Text('Save place'),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
