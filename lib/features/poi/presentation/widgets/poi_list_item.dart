import 'package:flutter/material.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_assets.dart';
import '../../domain/entities/poi.dart';

/// Reusable card representing a single Point of Interest in the catalogue.
class PoiListItem extends StatelessWidget {
  const PoiListItem({
    super.key,
    required this.poi,
    this.isSaved = false,
    this.onSave,
    this.onRemove,
    this.onTap,
  });

  final Poi poi;
  final bool isSaved;
  final VoidCallback? onSave;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
                    if (poi.address != null) ...[
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isSaved) ...[
                const SizedBox(width: AppSpacing.sm),
                Semantics(
                  label: 'Saved place',
                  child: Container(
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
                          'Saved',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppPalette.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (onRemove != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    tooltip: 'Remove saved place',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ] else if (onSave != null) ...[
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  tooltip: 'Save place',
                  onPressed: onSave,
                  icon: const Icon(Icons.star_outline_rounded),
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
