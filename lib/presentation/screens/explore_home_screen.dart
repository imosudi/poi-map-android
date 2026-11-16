import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/catalogue_provider.dart';
import '../../core/constants/app_assets.dart';
import '../../core/theme/app_palette.dart';
import '../widgets/catalogue_filter_chips.dart';
import '../widgets/open_data_badge.dart';
import 'poi_catalogue_screen.dart';

/// Landing screen presenting Vienna POI branding, quick filters, and shortcuts.
class ExploreHomeScreen extends ConsumerStatefulWidget {
  const ExploreHomeScreen({
    super.key,
    required this.onOpenMap,
    required this.onOpenFavourites,
    this.onOpenCatalogue,
  });

  final VoidCallback onOpenMap;
  final VoidCallback onOpenFavourites;
  final VoidCallback? onOpenCatalogue;

  @override
  ConsumerState<ExploreHomeScreen> createState() => _ExploreHomeScreenState();
}

class _ExploreHomeScreenState extends ConsumerState<ExploreHomeScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(catalogueProvider).searchQuery,
    );
    Future.microtask(() {
      ref.read(catalogueProvider.notifier).loadIfNeeded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToCatalogue() {
    if (widget.onOpenCatalogue != null) {
      widget.onOpenCatalogue!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PoiCatalogueScreen(onOpenMap: widget.onOpenMap),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogueState = ref.watch(catalogueProvider);
    final notifier = ref.read(catalogueProvider.notifier);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              AppAssets.headerBanner,
              fit: BoxFit.cover,
              semanticLabel: 'Vienna POI Explorer: Discover. Explore. Save.',
            ),
          ),
          const SizedBox(height: 16),
          SearchBar(
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
            onChanged: notifier.setSearchQuery,
            onSubmitted: (_) => _navigateToCatalogue(),
          ),
          const SizedBox(height: 14),
          CatalogueFilterChips(
            selectedFilter: catalogueState.quickFilter,
            onSelected: (filter) {
              notifier.setQuickFilter(filter);
              _navigateToCatalogue();
            },
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _navigateToCatalogue,
            borderRadius: BorderRadius.circular(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                AppAssets.promoCard,
                fit: BoxFit.cover,
                semanticLabel: 'Find points of interest in Vienna',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 6,
              ),
              leading: const Icon(Icons.favorite, color: AppPalette.accent),
              title: Text(
                'Saved places',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppPalette.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppPalette.inkSecondary,
              ),
              onTap: widget.onOpenFavourites,
            ),
          ),
          const SizedBox(height: 24),
          const Center(child: OpenDataBadge()),
        ],
      ),
    );
  }
}

