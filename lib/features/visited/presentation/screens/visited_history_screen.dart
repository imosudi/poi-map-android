import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../domain/entities/visited_place.dart';
import '../providers/visited_places_provider.dart';

/// Displays recorded visited Vienna POIs with timestamps and clear-history
/// controls.
class VisitedHistoryScreen extends ConsumerWidget {
  const VisitedHistoryScreen({super.key});

  Future<void> _confirmAndClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear visited history?'),
        content: const Text(
          'Remove all recorded visited places from your history? Saved places and the POI catalogue will remain untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(visitedPlacesProvider.notifier).clearHistory();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final visitedState = ref.watch(visitedPlacesProvider);
    final items = visitedState.asData?.value ?? const <VisitedPlace>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visited History'),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              onPressed: () => _confirmAndClear(context, ref),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: AsyncValueView<List<VisitedPlace>>(
        value: visitedState,
        isEmpty: (list) => list.isEmpty,
        loadingMessage: 'Loading visited places...',
        emptyTitle: 'No visited places yet',
        emptyMessage:
            'Spend a moment near a registered POI beacon while scanning to record a visit.',
        onRetry: () => ref.invalidate(visitedPlacesProvider),
        builder: (places) {
          if (places.isEmpty) {
            return const AppEmptyView(
              title: 'No visited places yet',
              message:
                  'Spend a moment near a registered POI beacon while scanning to record a visit.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: places.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final place = places[index];
              final timestampLabel = _formatTimestamp(
                place.lastVisitedAt.toLocal(),
              );
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppPalette.accentSoft,
                    foregroundColor: AppPalette.accent,
                    child: Icon(Icons.check_circle_outline_rounded),
                  ),
                  title: Text(
                    place.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (place.category != null && place.category!.isNotEmpty)
                        Text(
                          place.category!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppPalette.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      Text(
                        place.visitCount > 1
                            ? 'Last visited: $timestampLabel • ${place.visitCount} visits'
                            : 'Visited: $timestampLabel',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _formatTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}
