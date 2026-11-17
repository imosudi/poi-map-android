import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/copyright_footer.dart';
import '../../../../core/widgets/open_data_badge.dart';

/// Vienna POI catalogue view.
class PoiCatalogueScreen extends StatelessWidget {
  const PoiCatalogueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                AppAssets.headerBanner,
                fit: BoxFit.cover,
                semanticLabel: 'Vienna POI Explorer: Discover. Explore. Save.',
              ),
            ),
            const Spacer(),
            Text(
              'Vienna POI Explorer',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            const OpenDataBadge(),
            const SizedBox(height: 8),
            const CopyrightFooter(),
          ],
        ),
      ),
    );
  }
}
