import 'package:flutter/material.dart';

import '../constants/app_assets.dart';

/// Displays the City of Vienna Open Government Data attribution badge.
class OpenDataBadge extends StatelessWidget {
  const OpenDataBadge({super.key, this.height = 44});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'City of Vienna Open Government Data',
      child: Image.asset(
        AppAssets.cityWienOpenDataBadge,
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }
}

