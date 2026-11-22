import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/copyright_footer.dart';
import '../../../poi/domain/entities/poi.dart';
import '../../../poi/presentation/widgets/poi_list_item.dart';
import '../../../visited/presentation/screens/visited_history_screen.dart';
import '../providers/favourites_provider.dart';

/// Displays the user's persistently saved Vienna places.
class FavouritesScreen extends ConsumerWidget {
  const FavouritesScreen({super.key});

  Future<void> _confirmAndRemove(
    BuildContext context,
    WidgetRef ref,
    Poi poi,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Image.asset(
          AppAssets.favouriteStar,
          width: 28,
          height: 28,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
        title: const Text('Remove saved place?'),
        content: Text(
          'Remove "${poi.name}" from your saved places? It will remain available in the catalogue and on the map.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(favouritesProvider.notifier).removePoi(poi);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final savedState = ref.watch(resolvedSavedPlacesProvider);
    final count = savedState.asData?.value.length;

    ref.listen<String?>(favouritesFeedbackProvider, (previous, next) {
      if (next != null && next != previous) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next)));
        ref.read(favouritesFeedbackProvider.notifier).clear();
      }
    });

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
                Tooltip(
                  message: 'Visited history',
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const VisitedHistoryScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text('Visited'),
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
                  final poi = items[index];
                  return PoiListItem(
                    poi: poi,
                    isSaved: true,
                    onRemove: () => _confirmAndRemove(context, ref, poi),
                  );
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
