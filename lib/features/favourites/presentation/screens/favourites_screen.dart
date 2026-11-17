import 'package:flutter/material.dart';

import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/copyright_footer.dart';

/// Saved places view.
class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Column(
        children: [
          Expanded(
            child: AppEmptyView(
              icon: Icons.bookmark_border_rounded,
              title: 'Saved Places',
            ),
          ),
          CopyrightFooter(),
        ],
      ),
    );
  }
}
