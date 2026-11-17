import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_exception.dart';

/// Shared asynchronous state representation for operations outside or alongside
/// Riverpod's [AsyncValue].
sealed class AsyncState<T> {
  const AsyncState();

  bool get isLoading => this is AsyncStateLoading<T>;
  bool get hasData => this is AsyncStateData<T>;
  bool get hasError => this is AsyncStateError<T>;
}

final class AsyncStateInitial<T> extends AsyncState<T> {
  const AsyncStateInitial();
}

final class AsyncStateLoading<T> extends AsyncState<T> {
  const AsyncStateLoading();
}

final class AsyncStateData<T> extends AsyncState<T> {
  const AsyncStateData(this.data);

  final T data;
}

final class AsyncStateError<T> extends AsyncState<T> {
  const AsyncStateError(this.exception);

  final AppException exception;
}

/// Convenience helpers on Riverpod [AsyncValue] for uniform UI handling.
extension AsyncValueStateX<T> on AsyncValue<T> {
  String? get errorMessage {
    final err = error;
    if (err == null) {
      return null;
    }
    if (err is AppException) {
      return err.message;
    }
    return 'Something went wrong. Please try again.';
  }
}
