import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// Displays the attribution footer at the bottom of primary views.
class CopyrightFooter extends StatelessWidget {
  const CopyrightFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppPalette.canvas,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Mosudi Isiaka O., FHTW © 2026',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppPalette.inkSecondary),
      ),
    );
  }
}

