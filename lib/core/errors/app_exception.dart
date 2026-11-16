/// Base application exception with a user-facing British English message.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Raised when fetching or parsing Vienna Open Government Data fails.
final class PoiDataException extends AppException {
  const PoiDataException(super.message);
}

/// Raised when reading or writing saved favourites fails.
final class SavedPlacesException extends AppException {
  const SavedPlacesException(super.message);
}

