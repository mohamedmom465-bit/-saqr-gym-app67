import 'dart:async';

/// Serializes destructive/consistency-sensitive operations such as save,
/// snapshot, restore and import. Non-sensitive work can continue normally.
class OperationLock {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final previous = _tail;
    final completer = Completer<T>();

    _tail = previous.catchError((_) {}).then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });

    return completer.future;
  }
}
