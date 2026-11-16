import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/home_shell.dart';

/// Root Material 3 application widget for Vienna POI Explorer.
class ViennaPoiExplorerApp extends StatelessWidget {
  const ViennaPoiExplorerApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vienna POI Explorer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: home ?? const HomeShell(),
    );
  }
}

