import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_palette.dart';
import '../widgets/copyright_footer.dart';
import '../widgets/open_data_badge.dart';

/// Root shell for Vienna POI Explorer.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  AppAssets.headerBanner,
                  fit: BoxFit.cover,
                  semanticLabel:
                      'Vienna POI Explorer: Discover. Explore. Save.',
                ),
              ),
              const Spacer(),
              Text(
                'Vienna POI Explorer',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppPalette.ink,
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
      ),
    );
  }
}
