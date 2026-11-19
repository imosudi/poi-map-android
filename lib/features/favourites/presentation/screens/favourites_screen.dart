import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/copyright_footer.dart';
import '../../../poi/domain/entities/poi.dart';
import '../../../poi/presentation/widgets/poi_list_item.dart';
import '../providers/favourites_provider.dart';

/// Displays the user's persistently saved Vienna places.
class FavouritesScreen extends ConsumerWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final savedState = ref.watch(resolvedSavedPlacesProvider);
    final count = savedState.asData?.value.length;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Image.asset(
                  AppAssets.favouriteStar,
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    count == null ? 'Saved Places' : 'Saved Places ($count)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: AsyncValueView<List<Poi>>(
              value: savedState,
              isEmpty: (items) => items.isEmpty,
              loadingMessage: 'Loading saved places...',
              emptyTitle: 'No saved places yet',
              emptyMessage:
                  'Save a sight from the catalogue or map to keep it here.',
              onRetry: () => ref.read(favouritesProvider.notifier).refresh(),
              builder: (items) => ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  return PoiListItem(poi: items[index], isSaved: true);
                },
              ),
            ),
          ),
          const CopyrightFooter(),
        ],
      ),
    );
  }
}
