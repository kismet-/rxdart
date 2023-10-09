part of rxdart;

typedef void DisposeFunction();

/// See the 'unsubscribing' section in ReactiveX:
/// http://reactivex.io/documentation/observable.html
/// See:
/// http://www.introtorx.com/Content/v1.0.10621.0/03_LifetimeManagement.html#IDisposable
class Disposable {
  /// Gets the singleton noop instance.
  static final Disposable noop = Disposable._().._disposed = true;
  bool _disposed = false;

  Disposable._();

  factory Disposable([DisposeFunction? dispose]) =>
      _FunctionDisposable(dispose!);

  void call() {
    dispose();
  }

  void dispose() {
    if (!_disposed) {
      _disposed = true;
      _disposeInternally();
    }
  }

  void _disposeInternally() {}
}

class CheckableDisposable extends Disposable {
  factory CheckableDisposable() {
    return CheckableDisposable();
  }

  bool get disposed => _disposed;
}

//class _CheckableDisposable = Disposable with CheckableDisposable;

/// Disposable implementation which uses DisposeFunction.
class _FunctionDisposable extends Disposable {
  DisposeFunction? _disposeFunction;

  _FunctionDisposable(DisposeFunction disposeFunction) : super._() {
    _disposeFunction = disposeFunction;
  }
  @override
  void _disposeInternally() {
    if (_disposeFunction != null) {
      _disposeFunction!.call();
      _disposeFunction = null;
    }
  }
}

abstract class DelegatingDisposable extends Disposable {
  Disposable? _disposable;

  DelegatingDisposable._() : super._();

  /// Returns the hold disposable.
  Disposable? get disposable => _disposable;

  set disposable(Disposable? disposable);

  void _checkOrSetDisposable(Disposable? disposable) {
    if (!_disposed) {
      _disposable = disposable;
    } else {
      disposable?.dispose();
    }
  }

  void _disposeAndResetDisposable() {
    var local = _disposable;
    _disposable = null;
    local?.dispose();
  }

  @override
  void _disposeInternally() {
    _disposeAndResetDisposable();
  }
}

class SingleAssignmentDisposable extends DelegatingDisposable {
  SingleAssignmentDisposable() : super._();

  @override
  set disposable(Disposable? disposable) {
    _checkOrSetDisposable(disposable);
  }
}

// @visibleForTesting
// class CheckableSingleAssignmentDisposable = SingleAssignmentDisposable
//     with CheckableDisposable;

class SerialDisposable extends DelegatingDisposable {
  SerialDisposable._() : super._();

  factory SerialDisposable([Disposable? disposable]) =>
      _SerialDisposable(disposable!);

  @override
  set disposable(Disposable? disposable) {
    if (!_disposed) _disposeAndResetDisposable();
    _checkOrSetDisposable(disposable);
  }
}

class _SerialDisposable extends SerialDisposable {
  _SerialDisposable(Disposable initialDisposable) : super._() {
    disposable = initialDisposable;
  }
}

@visibleForTesting
//class CheckableSerialDisposable = _SerialDisposable with CheckableDisposable;

class CompositeDisposable extends Disposable {
  List<Disposable> _disposables;

  CompositeDisposable._(this._disposables) : super._();

  factory CompositeDisposable(
          [List<Disposable> disposables = const <Disposable>[]]) =>
      _CompositeDisposable(disposables);

  @override
  void _disposeInternally() {
    var disposables = _disposables;
    _disposables = <Disposable>[];
    for (var disposable in disposables) {
      disposable.dispose();
    }
  }

  bool add(Disposable disposable) {
    if (!_disposed) {
      _disposables.add(disposable);
      return true;
    } else {
      disposable.dispose();
      return false;
    }
  }

  bool remove(Disposable disposable) => _disposables.remove(disposable);
}

class _CompositeDisposable extends CompositeDisposable {
  _CompositeDisposable(List<Disposable> disposables)
      : super._(List.from(disposables));
}

// @visibleForTesting
// class CheckableCompositeDisposable = _CompositeDisposable
//     with CheckableDisposable;
