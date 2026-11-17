/// Lightweight, transport-agnostic cancellation token for async requests.
final class CancellationToken {
  bool _isCancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _isCancelled;

  /// Registers [listener] to run when [cancel] is called, or invokes it
  /// immediately if already cancelled. Returns a function to unregister.
  void Function() addListener(void Function() listener) {
    if (_isCancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Marks the token as cancelled and notifies registered listeners.
  void cancel() {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;
    final snapshot = List<void Function()>.of(_listeners);
    _listeners.clear();
    for (final listener in snapshot) {
      listener();
    }
  }
}
