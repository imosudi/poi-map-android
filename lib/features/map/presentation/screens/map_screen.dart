import 'package:flutter/material.dart';

import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/copyright_footer.dart';

/// Reserved destination for interactive Vienna map exploration.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Column(
        children: [
          Expanded(
            child: AppEmptyView(
              icon: Icons.map_outlined,
              title: 'Map',
              message: 'Interactive Vienna map view will appear here.',
            ),
          ),
          CopyrightFooter(),
        ],
      ),
    );
  }
}

