import 'package:flutter/material.dart';

import '../widgets/copyright_footer.dart';
import 'all_places_map_screen.dart';
import 'explore_home_screen.dart';

/// Top-level navigation destinations for Vienna POI Explorer.
enum AppTab { explore, map, favourites }

/// Root navigation shell with Material 3 bottom navigation and back handling.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.exploreBuilder,
    this.mapBuilder,
    this.favouritesBuilder,
  });

  final Widget Function(VoidCallback onOpenMap, VoidCallback onOpenFavourites)?
  exploreBuilder;
  final WidgetBuilder? mapBuilder;
  final Widget Function(VoidCallback onBackToExplore)? favouritesBuilder;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppTab _currentTab = AppTab.explore;

  void _selectTab(AppTab tab) {
    if (_currentTab == tab) return;
    setState(() {
      _currentTab = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentTab == AppTab.explore,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentTab != AppTab.explore) {
          _selectTab(AppTab.explore);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentTab.index,
          children: [
            widget.exploreBuilder?.call(
                  () => _selectTab(AppTab.map),
                  () => _selectTab(AppTab.favourites),
                ) ??
                ExploreHomeScreen(
                  onOpenMap: () => _selectTab(AppTab.map),
                  onOpenFavourites: () => _selectTab(AppTab.favourites),
                ),
            widget.mapBuilder?.call(context) ?? const AllPlacesMapScreen(),
            widget.favouritesBuilder?.call(() => _selectTab(AppTab.explore)) ??
                const _PlaceholderPane(title: 'Favourites'),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CopyrightFooter(),
              NavigationBar(
                selectedIndex: _currentTab.index,
                onDestinationSelected: (index) =>
                    _selectTab(AppTab.values[index]),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.explore_outlined),
                    selectedIcon: Icon(Icons.explore),
                    label: 'Explore',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.map_outlined),
                    selectedIcon: Icon(Icons.map),
                    label: 'Map',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.favorite_outline),
                    selectedIcon: Icon(Icons.favorite),
                    label: 'Favourites',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderPane extends StatelessWidget {
  const _PlaceholderPane({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
