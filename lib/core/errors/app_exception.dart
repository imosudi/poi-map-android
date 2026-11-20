/// Base application exception with a user-facing British English message.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Raised when network connectivity or an HTTP request fails.
final class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause});
}

/// Raised when fetching or parsing Vienna Open Government Data fails.
final class PoiDataException extends AppException {
  const PoiDataException(super.message, {super.cause});
}

/// Raised when reading or writing saved favourites fails.
final class SavedPlacesException extends AppException {
  const SavedPlacesException(super.message, {super.cause});
}

/// Raised when location permissions or positioning services fail.
final class LocationException extends AppException {
  const LocationException(super.message, {super.cause});
}

/// Raised when BLE permissions, adapter state, or scanning fail.
final class BleException extends AppException {
  const BleException(super.message, {super.cause});
}

/// Fallback exception for unexpected runtime errors.
final class UnexpectedException extends AppException {
  const UnexpectedException([
    super.message = 'Something went wrong. Please try again.',
    Object? cause,
  ]) : super(cause: cause);
}
