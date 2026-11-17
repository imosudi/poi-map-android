import '../entities/poi.dart';

/// Immutable search and category filter criteria for the POI catalogue.
final class PoiFilterCriteria {
  const PoiFilterCriteria({this.query = '', this.category});

  final String query;
  final String? category;

  String get normalizedQuery => query.trim().toLowerCase();

  String? get normalizedCategory {
    final trimmed = category?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  bool get hasActiveFilters =>
      normalizedQuery.isNotEmpty || normalizedCategory != null;

  PoiFilterCriteria copyWith({
    String? query,
    String? category,
    bool clearCategory = false,
  }) {
    return PoiFilterCriteria(
      query: query ?? this.query,
      category: clearCategory ? null : (category ?? this.category),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PoiFilterCriteria &&
        other.query == query &&
        other.category == category;
  }

  @override
  int get hashCode => Object.hash(query, category);
}

/// Pure filtering and category-extraction logic for [Poi] collections.
abstract final class PoiFilter {
  /// Returns sorted distinct non-empty category labels present in [pois].
  static List<String> extractCategories(Iterable<Poi> pois) {
    final categories = <String>{};
    for (final poi in pois) {
      final category = poi.category?.trim();
      if (category != null && category.isNotEmpty) {
        categories.add(category);
      }
    }
    final sorted = categories.toList()..sort();
    return List.unmodifiable(sorted);
  }

  /// Filters [pois] by [criteria] without mutating the source list.
  static List<Poi> apply(List<Poi> pois, PoiFilterCriteria criteria) {
    final query = criteria.normalizedQuery;
    final category = criteria.normalizedCategory?.toLowerCase();

    if (query.isEmpty && category == null) {
      return pois;
    }

    final matches = <Poi>[];
    for (final poi in pois) {
      if (query.isNotEmpty && !poi.name.toLowerCase().contains(query)) {
        continue;
      }
      if (category != null && poi.category?.trim().toLowerCase() != category) {
        continue;
      }
      matches.add(poi);
    }
    return List.unmodifiable(matches);
  }
}
