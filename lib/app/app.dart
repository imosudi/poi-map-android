import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// Root Material 3 application widget for Vienna POI Explorer.
class ViennaPoiExplorerApp extends ConsumerWidget {
  const ViennaPoiExplorerApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);

    return MaterialApp(
      title: config.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: home,
      initialRoute: home == null ? AppRoutes.home : null,
      onGenerateRoute: home == null ? AppRouter.onGenerateRoute : null,
    );
  }
}
