import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/copyright_footer.dart';
import '../../../poi/domain/entities/poi.dart';
import '../../../poi/presentation/providers/poi_catalogue_provider.dart';
import '../providers/map_providers.dart';
import '../widgets/poi_map_view.dart';

/// Interactive Vienna POI map screen.
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key, this.mapBuilder});

  final GoogleMapWidgetBuilder? mapBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final apiKeyState = ref.watch(mapApiKeyConfiguredProvider);
    final catalogueState = ref.watch(poiCatalogueProvider);
    final selectedPoi = ref.watch(selectedMapPoiProvider);
    final selectionController = ref.read(selectedPoiIdProvider.notifier);

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
                  AppAssets.viennaShield,
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Vienna Map',
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
            child: apiKeyState.when(
              loading: () => const AppLoadingView(
                message: 'Checking map configuration...',
              ),
              error: (_, __) => AppErrorView(
                title: 'Map unavailable',
                message: 'Unable to verify Google Maps configuration.',
                onRetry: () => ref.invalidate(mapApiKeyConfiguredProvider),
              ),
              data: (isConfigured) {
                if (!isConfigured) {
                  return AppErrorView(
                    title: 'Google Maps key missing',
                    message:
                        'Add MAPS_API_KEY to android/local.properties to enable the interactive map.',
                    onRetry: () => ref.invalidate(mapApiKeyConfiguredProvider),
                  );
                }
                return AsyncValueView<List<Poi>>(
                  value: catalogueState,
                  loadingMessage: 'Loading Vienna map...',
                  onRetry: () =>
                      ref.read(poiCatalogueProvider.notifier).refresh(),
                  builder: (pois) => PoiMapView(
                    pois: pois,
                    selectedPoi: selectedPoi,
                    onPoiSelected: (poi) => selectionController.select(poi.id),
                    onClearSelection: selectionController.clear,
                    mapBuilder: mapBuilder,
                  ),
                );
              },
            ),
          ),
          const CopyrightFooter(),
        ],
      ),
    );
  }
}
