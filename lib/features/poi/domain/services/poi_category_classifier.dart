/// Derives a display category from a Vienna sight name when the source
/// dataset does not provide an explicit category field.
abstract final class PoiCategoryClassifier {
  static const String landmark = 'Landmark';
  static const String museum = 'Museum';
  static const String sacred = 'Sacred';
  static const String nature = 'Nature';
  static const String observatory = 'Observatory';

  static const List<String> _observatoryKeywords = [
    'sternwarte',
    'planetarium',
  ];

  static const List<String> _sacredKeywords = [
    'kirche',
    'dom',
    'synagoge',
    'moschee',
    'friedhof',
    'gruft',
  ];

  static const List<String> _natureKeywords = [
    'tiergarten',
    'schlosspark',
    'palmenhaus',
    'schmetterlinghaus',
    'haus des meeres',
    'irrgarten',
  ];

  static const List<String> _museumKeywords = [
    'museum',
    'albertina',
    'secession',
    'künstlerhaus',
    'kunsthaus',
    'haus der musik',
    'mozarthaus',
    'schatzkammer',
    'wagenburg',
  ];

  static String classify(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) {
      return landmark;
    }

    if (_matchesAny(normalized, _observatoryKeywords)) {
      return observatory;
    }
    if (_matchesAny(normalized, _sacredKeywords)) {
      return sacred;
    }
    if (_matchesAny(normalized, _natureKeywords)) {
      return nature;
    }
    if (_matchesAny(normalized, _museumKeywords)) {
      return museum;
    }
    return landmark;
  }

  static bool _matchesAny(String value, List<String> keywords) {
    for (final keyword in keywords) {
      if (value.contains(keyword)) {
        return true;
      }
    }
    return false;
  }
}

