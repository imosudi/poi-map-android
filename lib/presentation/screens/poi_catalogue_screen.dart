import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/catalogue_provider.dart';
import '../../application/state/catalogue_state.dart';
import '../../core/constants/app_assets.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/entities/point_of_interest.dart';
import '../widgets/catalogue_filter_chips.dart';
import '../widgets/poi_list_tile.dart';
import 'poi_detail_map_screen.dart';

/// Searchable, filterable, and refreshable Vienna POI catalogue screen.
class PoiCatalogueScreen extends ConsumerStatefulWidget {
  const PoiCatalogueScreen({
    super.key,
    this.onOpenMap,
    this.onSelectPlace,
    this.trailingBuilder,
  });

  final VoidCallback? onOpenMap;
  final ValueChanged<PointOfInterest>? onSelectPlace;
  final Widget Function(PointOfInterest place)? trailingBuilder;

  @override
  ConsumerState<PoiCatalogueScreen> createState() => _PoiCatalogueScreenState();
}

class _PoiCatalogueScreenState extends ConsumerState<PoiCatalogueScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(catalogueProvider).searchQuery;
    _searchController = TextEditingController(text: initialQuery);
    Future.microtask(() {
      ref.read(catalogueProvider.notifier).loadIfNeeded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogueProvider);
    final notifier = ref.read(catalogueProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Places'),
        actions: [
          if (widget.onOpenMap != null)
            IconButton(
              tooltip: 'Open interactive map',
              onPressed: widget.onOpenMap,
              icon: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  AppAssets.appIcon,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (state.isRefreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            )
          else
            IconButton(
              tooltip: 'Refresh places',
              onPressed: state.hasLoadedPlaces ? notifier.refresh : null,
              icon: Image.asset(
                AppAssets.refresh,
                width: 22,
                height: 22,
                fit: BoxFit.contain,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Name, address, or website',
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: const WidgetStatePropertyAll(AppPalette.surface),
              side: const WidgetStatePropertyAll(
                BorderSide(color: AppPalette.divider),
              ),
              leading: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Image.asset(
                  AppAssets.search,
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
              trailing: [
                if (state.searchQuery.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      notifier.setSearchQuery('');
                    },
                  ),
              ],
              onChanged: notifier.setSearchQuery,
            ),
          ),
          CatalogueFilterChips(
            selectedFilter: state.quickFilter,
            onSelected: notifier.setQuickFilter,
          ),
          if (state.refreshError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: MaterialBanner(
                backgroundColor: AppPalette.accentSoft,
                content: Text(
                  state.refreshError!,
                  style: const TextStyle(color: AppPalette.ink),
                ),
                actions: [
                  TextButton(
                    onPressed: notifier.clearRefreshError,
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody(context, state, notifier)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CatalogueState state,
    CatalogueNotifier notifier,
  ) {
    switch (state.status) {
      case CatalogueStatus.idle:
      case CatalogueStatus.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Loading Vienna places…'),
            ],
          ),
        );
      case CatalogueStatus.failed:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: AppPalette.accent,
                ),
                const SizedBox(height: 12),
                Text(
                  'Could not load places',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppPalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.errorMessage ?? 'Please check your network connection.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppPalette.inkSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: notifier.retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        );
      case CatalogueStatus.loaded:
        final filtered = state.filteredPlaces;
        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.search_off_outlined,
                    size: 48,
                    color: AppPalette.inkSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No matching places',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppPalette.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try adjusting your search or selected filter.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: notifier.refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const Divider(indent: 74),
            itemBuilder: (context, index) {
              final place = filtered[index];
              return PoiListTile(
                place: place,
                onTap: () {
                  if (widget.onSelectPlace != null) {
                    widget.onSelectPlace!(place);
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PoiDetailMapScreen(
                        selectedPlace: place,
                        allPlaces: state.places,
                      ),
                    ),
                  );
                },
                trailing: widget.trailingBuilder?.call(place),
              );
            },
          ),
        );
    }
  }
}
