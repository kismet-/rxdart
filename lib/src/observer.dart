part of rxdart;

typedef void OnNextFunction<T>(T data);
typedef void OnCompletedFunction();
void noopNext(ignore) {}
void noopError(ignoreError, [ignoreStackTrace]) {}
void noopCompleted() {}

/// The observer in ReactiveX.
/// See
/// http://reactivex.io/documentation/observable.html
abstract class Observer<T> {
  const Observer._();

  factory Observer(
          {OnNextFunction<T>? onNext,
          Function? onError,
          OnCompletedFunction? onCompleted}) =>
      _FunctionObserver(onNext, onError, onCompleted);

  ///   See http://reactivex.io/documentation/contract.html

  factory Observer.safe(
          {OnNextFunction<T>? onNext,
          Function? onError,
          OnCompletedFunction? onCompleted}) =>
      _SafeFunctionObserver(onNext, onError, onCompleted);

  /// Returns a safe observer (see Observer.safe) using the given [observer].
  static Observer<E> makeSafe<E>(Observer<E> observer) {
    assert(observer != null);
    return observer is _SafeObserver
        ? observer
        : _SafeDelegatingObserver<E>(observer);
  }

  /// Emits the [data] event to this observer.
  void sendNext(T data) {
    print("-----------------------$data");
    _sendNextInternal(data);
  }

  void _sendNextInternal(T data);

  void sendError(Object error, [StackTrace? stackTrace]) {
    assert(error != null);
    _sendErrorInternal(error, stackTrace!);
  }

  void _sendErrorInternal(Object error, [StackTrace stackTrace]);

  void sendCompleted() {
    _sendCompletedInternal();
  }

  void _sendCompletedInternal();
}

class _FunctionObserver<T> extends Observer<T> {
  OnNextFunction<T> _onNext;
  Function _onError;
  OnCompletedFunction _onCompleted;

  _FunctionObserver(OnNextFunction<T>? onNext, Function? onError,
      OnCompletedFunction? onCompleted)
      : _onNext = onNext ?? noopNext,
        _onError = onError ?? noopError,
        _onCompleted = onCompleted ?? noopCompleted,
        super._();

  @override
  void _sendNextInternal(T data) {
    _onNext(data);
  }

  @override
  void _sendErrorInternal(Object error, [StackTrace? stackTrace]) {
    _onError(error, stackTrace);
  }

  @override
  void _sendCompletedInternal() {
    _onCompleted();
  }
}

class _DelegatingObserver<T> extends Observer<T> {
  final Observer<T> _observer;

  const _DelegatingObserver(Observer<T> observer)
      : _observer = observer,
        super._();

  @override
  void _sendNextInternal(T data) {
    _observer?.sendNext(data);
  }

  @override
  void _sendErrorInternal(Object error, [StackTrace? stackTrace]) {
    _observer?.sendError(error, stackTrace);
  }

  @override
  void _sendCompletedInternal() {
    _observer?.sendCompleted();
  }
}

mixin _SafeObserver<T> implements Observer<T> {
  bool _done = false;

  @override
  void sendNext(T data) {
    if (_done) return;
    try {
      _sendNextInternal(data);
    } catch (e, st) {
      _logger.info(() => 'SafeObserver sendNext($data) catch error: $e - $st');
      _done = true;
      rethrow;
    }
  }

  @override
  void sendError(Object error, [StackTrace? stackTrace]) {
    if (_done) return;
    try {
      _sendErrorInternal(error, stackTrace!);
    } finally {
      _done = true;
    }
  }

  @override
  void sendCompleted() {
    if (_done) return;
    try {
      _sendCompletedInternal();
    } finally {
      _done = true;
    }
  }
}

class _SafeFunctionObserver<T> = _FunctionObserver<T> with _SafeObserver<T>;

class _SafeDelegatingObserver<T> = _DelegatingObserver<T> with _SafeObserver<T>;
