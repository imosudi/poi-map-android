import '../../domain/entities/point_of_interest.dart';

/// Quick filter options supported by the Vienna OGD sights dataset.
enum QuickFilter {
  allPlaces('All places'),
  withAddress('With address'),
  withWebsite('With website');

  const QuickFilter(this.label);

  final String label;
}

/// Lifecycle state for loading the POI catalogue.
enum CatalogueStatus { idle, loading, loaded, failed }

/// Immutable state for the POI catalogue, search query, and active filter.
class CatalogueState {
  const CatalogueState({
    this.status = CatalogueStatus.idle,
    this.places = const [],
    this.errorMessage,
    this.isRefreshing = false,
    this.refreshError,
    this.searchQuery = '',
    this.quickFilter = QuickFilter.allPlaces,
  });

  final CatalogueStatus status;
  final List<PointOfInterest> places;
  final String? errorMessage;
  final bool isRefreshing;
  final String? refreshError;
  final String searchQuery;
  final QuickFilter quickFilter;

  bool get hasLoadedPlaces => status == CatalogueStatus.loaded;

  List<PointOfInterest> get filteredPlaces {
    if (status != CatalogueStatus.loaded) return const [];

    final query = searchQuery.trim().toLowerCase();
    return places
        .where((place) {
          final matchesFilter = switch (quickFilter) {
            QuickFilter.allPlaces => true,
            QuickFilter.withAddress => place.address != null,
            QuickFilter.withWebsite => place.informationUrl != null,
          };
          if (!matchesFilter) return false;
          if (query.isEmpty) return true;

          return place.name.toLowerCase().contains(query) ||
              (place.address?.toLowerCase().contains(query) ?? false) ||
              (place.informationUrl?.toString().toLowerCase().contains(query) ??
                  false);
        })
        .toList(growable: false);
  }

  CatalogueState copyWith({
    CatalogueStatus? status,
    List<PointOfInterest>? places,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isRefreshing,
    String? refreshError,
    bool clearRefreshError = false,
    String? searchQuery,
    QuickFilter? quickFilter,
  }) {
    return CatalogueState(
      status: status ?? this.status,
      places: places ?? this.places,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshError: clearRefreshError
          ? null
          : (refreshError ?? this.refreshError),
      searchQuery: searchQuery ?? this.searchQuery,
      quickFilter: quickFilter ?? this.quickFilter,
    );
  }
}
