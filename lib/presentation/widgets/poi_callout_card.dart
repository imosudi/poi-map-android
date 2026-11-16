import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/distance_calculator.dart';
import '../../domain/entities/geo_coordinate.dart';
import '../../domain/entities/poi_marker_style.dart';
import '../../domain/entities/point_of_interest.dart';

/// Floating card presenting details and actions for a selected POI.
class PoiCalloutCard extends StatelessWidget {
  const PoiCalloutCard({
    super.key,
    required this.place,
    this.userLocation,
    this.onClose,
    this.trailingAction,
  });

  final PointOfInterest place;
  final GeoCoordinate? userLocation;
  final VoidCallback? onClose;
  final Widget? trailingAction;

  Future<void> _openInformationUrl(BuildContext context) async {
    final uri = place.informationUrl;
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the information link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final distanceAway = DistanceCalculator.formatDistanceAway(
      userCoordinate: userLocation,
      poi: place,
    );
    final markerStyle = PoiMarkerStyle.fromPoi(place);

    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    place.name,
                    style: textTheme.titleMedium?.copyWith(
                      color: AppPalette.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailingAction != null) trailingAction!,
                if (onClose != null)
                  IconButton(
                    tooltip: 'Close details',
                    visualDensity: VisualDensity.compact,
                    onPressed: onClose,
                    icon: const Icon(Icons.close, size: 20),
                  ),
              ],
            ),
            if (place.address != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Image.asset(
                    AppAssets.mapPin,
                    width: 16,
                    height: 16,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      place.address!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppPalette.inkSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (distanceAway != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Image.asset(
                    AppAssets.navigationArrow,
                    width: 15,
                    height: 15,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    distanceAway,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppPalette.inkSecondary,
                    ),
                  ),
                ],
              ),
            ],
            if (place.thumbnailUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  place.thumbnailUrl.toString(),
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    markerStyle.accessibilityDescription,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppPalette.inkSecondary,
                    ),
                  ),
                  if (place.informationUrl != null)
                    TextButton.icon(
                      onPressed: () => _openInformationUrl(context),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('More information'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
