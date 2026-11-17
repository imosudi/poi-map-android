import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/copyright_footer.dart';
import '../../../../core/widgets/open_data_badge.dart';
import '../../domain/entities/poi.dart';
import '../providers/poi_catalogue_provider.dart';
import '../widgets/poi_list_item.dart';

/// Vienna POI catalogue view.
class PoiCatalogueScreen extends ConsumerWidget {
  const PoiCatalogueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogueState = ref.watch(poiCatalogueProvider);
    final controller = ref.read(poiCatalogueProvider.notifier);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: controller.refresh,
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
                child: _CatalogueHeader(
                  count: catalogueState.asData?.value.length,
                  isLoading: catalogueState.isLoading,
                  onRefresh: controller.refresh,
                ),
              ),
            ),
            ..._buildBodySlivers(context, catalogueState, controller.refresh),
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

  List<Widget> _buildBodySlivers(
    BuildContext context,
    AsyncValue<List<Poi>> state,
    VoidCallback onRetry,
  ) {
    final items = state.asData?.value;
    if (state.isLoading || state.hasError || items == null || items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AsyncValueView<List<Poi>>(
            value: state,
            isEmpty: (list) => list.isEmpty,
            loadingMessage: 'Loading Vienna sights...',
            emptyTitle: 'No places available',
            emptyMessage: 'No Vienna sights were found. Try refreshing.',
            onRetry: onRetry,
            builder: (_) => const SizedBox.shrink(),
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
            return PoiListItem(poi: items[index]);
          },
        ),
      ),
    ];
  }
}

class _CatalogueHeader extends StatelessWidget {
  const _CatalogueHeader({
    required this.count,
    required this.isLoading,
    required this.onRefresh,
  });

  final int? count;
  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = count == null
        ? 'Vienna sights & landmarks'
        : '$count sights in Vienna';

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
              onPressed: isLoading ? null : onRefresh,
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
