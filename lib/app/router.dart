import 'package:flutter/material.dart';

import '../core/widgets/app_error_view.dart';
import '../features/favourites/presentation/screens/favourites_screen.dart';
import '../features/map/presentation/screens/map_screen.dart';
import '../features/poi/presentation/screens/poi_catalogue_screen.dart';

/// Named route identifiers used across the application.
abstract final class AppRoutes {
  static const String home = '/';
  static const String catalogue = '/catalogue';
  static const String map = '/map';
  static const String favourites = '/favourites';
}

/// Centralised route generator for named navigation.
abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? AppRoutes.home;
    return switch (name) {
      AppRoutes.home => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const AppShell(),
      ),
      AppRoutes.catalogue => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const AppShell(initialIndex: 0),
      ),
      AppRoutes.map => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const AppShell(initialIndex: 1),
      ),
      AppRoutes.favourites => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const AppShell(initialIndex: 2),
      ),
      _ => MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Page Not Found')),
          body: AppErrorView(
            title: 'Route not found',
            message: 'The requested page ($name) could not be opened.',
            retryLabel: 'Return home',
            onRetry: () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
          ),
        ),
      ),
    };
  }
}

/// Primary navigation shell hosting the top-level feature destinations.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _selectedIndex = widget.initialIndex.clamp(0, 2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const PoiCatalogueScreen(),
          MapScreen(isActive: _selectedIndex == 1),
          const FavouritesScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: 'Saved',
          ),
        ],
      ),
    );
  }
}
