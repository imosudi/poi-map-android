import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/copyright_footer.dart';
import '../../../../core/widgets/open_data_badge.dart';
import '../../../beacon/domain/beacon_proximity_models.dart';
import '../../../beacon/presentation/providers/beacon_proximity_provider.dart';
import '../../../beacon/presentation/providers/ble_scan_provider.dart';
import '../../../beacon/presentation/widgets/beacon_scan_status_bar.dart';
import '../../../favourites/presentation/providers/favourites_provider.dart';
import '../../domain/entities/poi.dart';
import '../../domain/services/poi_filter.dart';
import '../providers/poi_catalogue_provider.dart';
import '../widgets/poi_list_item.dart';

/// Vienna POI catalogue view.
class PoiCatalogueScreen extends ConsumerStatefulWidget {
  const PoiCatalogueScreen({super.key});

  @override
  ConsumerState<PoiCatalogueScreen> createState() => _PoiCatalogueScreenState();
}

class _PoiCatalogueScreenState extends ConsumerState<PoiCatalogueScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(poiFilterCriteriaProvider).query,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogueState = ref.watch(poiCatalogueProvider);
    final filteredState = ref.watch(filteredPoisProvider);
    final paginatedState = ref.watch(paginatedPoisProvider);
    final criteria = ref.watch(poiFilterCriteriaProvider);
    final categories = ref.watch(availablePoiCategoriesProvider);
    final refreshStatus = ref.watch(poiRefreshStatusProvider);
    final savedPoiIds = ref.watch(savedPoiIdsProvider);
    final bleScanState = ref.watch(bleScanControllerProvider);
    final nearbyMatches = ref.watch(nearbyBeaconPoisProvider);
    final nearbyStates = ref.watch(nearbyBeaconPoiStatesProvider);

    final catalogueController = ref.read(poiCatalogueProvider.notifier);
    final filterController = ref.read(poiFilterCriteriaProvider.notifier);
    final pageController = ref.read(cataloguePageProvider.notifier);
    final favouritesController = ref.read(favouritesProvider.notifier);
    final bleScanController = ref.read(bleScanControllerProvider.notifier);

    ref.listen<PoiFilterCriteria>(poiFilterCriteriaProvider, (_, next) {
      if (_searchController.text != next.query) {
        _searchController.value = TextEditingValue(
          text: next.query,
          selection: TextSelection.collapsed(offset: next.query.length),
        );
      }
    });

    ref.listen<PoiRefreshStatus>(poiRefreshStatusProvider, (previous, next) {
      final message = next.errorMessage;
      if (message != null && message != previous?.errorMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    ref.listen<String?>(favouritesFeedbackProvider, (previous, next) {
      if (next != null && next != previous) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next)));
        ref.read(favouritesFeedbackProvider.notifier).clear();
      }
    });

    final totalCount = catalogueState.asData?.value.length;
    final filteredCount = filteredState.asData?.value.length;
    final isBusy = catalogueState.isLoading || refreshStatus.isRefreshing;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: catalogueController.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CatalogueHeader(
                      totalCount: totalCount,
                      filteredCount: filteredCount,
                      hasActiveFilters: criteria.hasActiveFilters,
                      isBusy: isBusy,
                      onRefresh: catalogueController.refresh,
                    ),
                    if (refreshStatus.isRefreshing) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    _SearchField(
                      controller: _searchController,
                      hasQuery: criteria.query.isNotEmpty,
                      onChanged: filterController.setQuery,
                      onClear: filterController.clearQuery,
                    ),
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _CategoryFilterBar(
                        categories: categories,
                        selectedCategory: criteria.normalizedCategory,
                        onSelected: filterController.setCategory,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    BeaconScanStatusBar(
                      scanState: bleScanState,
                      nearbyPoiCount: nearbyMatches.length,
                      onStartScan: bleScanController.startScanning,
                      onStopScan: bleScanController.stopScanning,
                      onOpenSettings: bleScanController.openAppSettings,
                    ),
                    if (nearbyMatches.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Nearby via beacon',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final match in nearbyMatches) ...[
                        PoiListItem(
                          poi: match.poi,
                          isSaved: savedPoiIds.contains(match.poi.id),
                          proximityState: match.state,
                          onSave: () => favouritesController.savePoi(match.poi),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            ..._buildBodySlivers(
              state: paginatedState,
              totalCount: totalCount ?? 0,
              hasActiveFilters: criteria.hasActiveFilters,
              savedPoiIds: savedPoiIds,
              nearbyStates: nearbyStates,
              onSavePoi: favouritesController.savePoi,
              onLoadMore: pageController.loadNextPage,
              onRetry: catalogueController.refresh,
              onClearFilters: filterController.clearAll,
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    OpenDataBadge(),
                    SizedBox(height: AppSpacing.sm),
                    CopyrightFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBodySlivers({
    required AsyncValue<({List<Poi> items, int totalCount, bool hasMore})>
    state,
    required int totalCount,
    required bool hasActiveFilters,
    required Set<String> savedPoiIds,
    required Map<String, BeaconProximityState> nearbyStates,
    required ValueChanged<Poi> onSavePoi,
    required VoidCallback onLoadMore,
    required VoidCallback onRetry,
    required VoidCallback onClearFilters,
  }) {
    final pageData = state.asData?.value;
    if (state.isLoading || state.hasError || pageData == null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child:
              AsyncValueView<({List<Poi> items, int totalCount, bool hasMore})>(
                value: state,
                isEmpty: (data) => data.items.isEmpty,
                loadingMessage: 'Loading Vienna sights...',
                emptyTitle: 'No places available',
                emptyMessage: 'No Vienna sights were found. Try refreshing.',
                onRetry: onRetry,
                builder: (_) => const SizedBox.shrink(),
              ),
        ),
      ];
    }

    final items = pageData.items;
    if (items.isEmpty) {
      if (totalCount > 0 && hasActiveFilters) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyView(
              icon: Icons.search_off_rounded,
              title: 'No matching sights',
              message: 'Try adjusting your search or filter.',
              actionLabel: 'Clear filters',
              onAction: onClearFilters,
            ),
          ),
        ];
      }

      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyView(
            title: 'No places available',
            message: 'No Vienna sights were found. Try refreshing.',
            actionLabel: 'Refresh',
            onAction: onRetry,
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final poi = items[index];
            return PoiListItem(
              poi: poi,
              isSaved: savedPoiIds.contains(poi.id),
              proximityState: nearbyStates[poi.id],
              onSave: () => onSavePoi(poi),
            );
          },
        ),
      ),
      if (pageData.hasMore)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: OutlinedButton(
                onPressed: onLoadMore,
                child: Text(
                  'Load more (${items.length} of ${pageData.totalCount})',
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

class _CatalogueHeader extends StatelessWidget {
  const _CatalogueHeader({
    required this.totalCount,
    required this.filteredCount,
    required this.hasActiveFilters,
    required this.isBusy,
    required this.onRefresh,
  });

  final int? totalCount;
  final int? filteredCount;
  final bool hasActiveFilters;
  final bool isBusy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String subtitle;
    if (totalCount == null) {
      subtitle = 'Vienna sights & landmarks';
    } else if (hasActiveFilters && filteredCount != null) {
      subtitle = '$filteredCount of $totalCount sights';
    } else {
      subtitle = '$totalCount sights in Vienna';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.bannerRadius),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 140),
            child: SizedBox(
              width: double.infinity,
              child: Image.asset(
                AppAssets.headerBanner,
                fit: BoxFit.cover,
                semanticLabel: 'Vienna POI Explorer: Discover. Explore. Save.',
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vienna POI Explorer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: isBusy ? null : onRefresh,
              icon: Image.asset(
                AppAssets.refresh,
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search sights by name',
        filled: true,
        fillColor: AppPalette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            AppAssets.search,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
        suffixIcon: hasQuery
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.accent, width: 1.5),
        ),
      ),
    );
  }
}

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: const Text('All'),
              selected: selectedCategory == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(category),
                selected: selectedCategory == category,
                onSelected: (selected) =>
                    onSelected(selected ? category : null),
              ),
            ),
        ],
      ),
    );
  }
}
