part of rxdart;

/// The subject in ReactiveX.
/// Subject itself is both an [Observerable] and an [Observer].
/// Any implementation should take care of the contracts on both interfaces.
/// See [Subject in ReactiveX](http://reactivex.io/documentation/subject.html)
/// for more details.
abstract class Subject<T> implements Observable<T>, Observer<T> {
  /// Creates an instance of Subject.
  ///
  /// See `PublishSubject` in
  /// [Subject in ReactiveX](http://reactivex.io/documentation/subject.html).
  factory Subject() => _Subject();

  /// Creates an instance of Subject which can replay values.
  ///
  /// If [shouldReplayAll] is true, it will replay all previous emitted values.
  /// Otherwise it only replay [bufferSize] of latest values.
  ///
  /// The [initValues] will be fed to result subject no matter what
  /// the [bufferSize] is.
  ///
  /// See `ReplaySubject` and `BehaviorSubject` in
  /// [Subject in ReactiveX](http://reactivex.io/documentation/subject.html).
  factory Subject.replay(
          {bool shouldReplayAll = false,
          int bufferSize = 1,
          Iterable<T> initValues = const []}) =>
      _ReplaySubject(shouldReplayAll, bufferSize, initValues);
}

/// Implementation of Subject.
/// This subject will hold a list of observers and once it is fed by any event,
/// it will pass the event to all observers.
class _Subject<T> extends Observable<T>
    with _SafeObserver<T>
    implements Subject<T> {
  _ObserverDoubleLinkedList<T>? _observers = _ObserverDoubleLinkedList<T>();

  _Subject() : super.protected() {
    name = 'Subject';
  }
  // -------------------------------------------------------------------
  // Observable apis.
  // -------------------------------------------------------------------
  @override
  Disposable subscribeByObserver(Observer<T> observer) {
    if (_done) return Disposable.noop;
    final safeObserverEntry = _ObserverDoubleLinkedListEntry<T>()
      ..observer = Observer.makeSafe(observer);
    _observers?.append(safeObserverEntry);
    return Disposable(() {
      _observers?.remove(safeObserverEntry);
    });
  }

  // -------------------------------------------------------------------
  // Observer apis.
  // -------------------------------------------------------------------
  @override
  void _sendNextInternal(T data) {
    _observers?.forEach((Observer<T> observer) {
      observer.sendNext(data);
    });
  }

  @override
  void _sendErrorInternal(Object error, [StackTrace? stackTrace]) {
    assert(error != null);
    final copy = _observers;
    _observers = null;
    copy?.forEach((Observer<T> observer) {
      observer.sendError(error, stackTrace);
    });
  }

  @override
  void _sendCompletedInternal() {
    final copy = _observers;
    _observers = null;
    copy?.forEach((Observer<T> observer) {
      observer.sendCompleted();
    });
  }
}

/// Implementation of replay subject.
/// This subject will cache a count of last events and every time it is
/// subscribed, this subject will pass the cached events to the observer
/// at first, and then performs as the [_Subject].
class _ReplaySubject<T> extends _Subject<T> {
  final DoubleLinkedQueue<T> _cachedValues;
  final bool _shouldReplayAll;
  final int _bufferSize;
  bool _isCompleted = false;
  Object? _error;
  StackTrace? _stackTrace;

  _ReplaySubject(
      this._shouldReplayAll, this._bufferSize, Iterable<T> initValues)
      : _cachedValues = DoubleLinkedQueue.from(initValues),
        super() {
    name =
        'Subject(shouldReplayAll: $_shouldReplayAll, bufferSize: $_bufferSize, '
        'initValues: $initValues)';
  }
  // -------------------------------------------------------------------
  // Observable apis.
  // -------------------------------------------------------------------
  @override
  Disposable subscribeByObserver(Observer<T> observer) {
    var safeObserver = Observer.makeSafe(observer);
    _cachedValues.forEach(safeObserver.sendNext);
    if (_isCompleted) {
      safeObserver.sendCompleted();
      return Disposable.noop;
    }
    if (_error != null) {
      safeObserver.sendError(_error!, _stackTrace);
      return Disposable.noop;
    }
    return super.subscribeByObserver(safeObserver);
  }

  // -------------------------------------------------------------------
  // Observer apis.
  // -------------------------------------------------------------------
  @override
  void _sendNextInternal(T data) {
    _cachedValues.add(data);
    if (!_shouldReplayAll) {
      while (_cachedValues.length > _bufferSize) {
        _cachedValues.removeFirst();
      }
    }

    super._sendNextInternal(data);
  }

  @override
  void _sendErrorInternal(Object error, [StackTrace? stackTrace]) {
    assert(error != null);
    _error = error;
    _stackTrace = stackTrace!;

    super._sendErrorInternal(error, stackTrace);
  }

  @override
  void _sendCompletedInternal() {
    _isCompleted = true;
    super._sendCompletedInternal();
  }
}

/// Double linked list allows concurrent modification.
class _ObserverDoubleLinkedList<T> {
  _ObserverDoubleLinkedListEntry<T>? _head;
  _ObserverDoubleLinkedListEntry<T>? _tail;
  bool _isIterating = false;
  void append(_ObserverDoubleLinkedListEntry<T> entry) {
    entry.prev = _tail;
    if (_tail != null) _tail!.next = entry;
    _tail = entry;
    if (_head == null) _head = entry;
    entry.isConcurrentlyAdding = _isIterating;
  }

  void remove(_ObserverDoubleLinkedListEntry<T> entry) {
    if (!_isIterating) {
      _remove(entry);
    } else {
      entry.isConcurrentlyRemoving = true;
    }
  }

  void _remove(_ObserverDoubleLinkedListEntry<T> entry) {
    final prev = entry.prev;
    final next = entry.next;
    entry.observer = null;
    entry.prev = null;
    entry.next = null;
    if (_head == entry) _head = next;
    if (_tail == entry) _tail = prev;
    if (prev != null) prev.next = next;
    if (next != null) next.prev = prev;
  }

  /// Iterates this list using [doAction] on the observer of each entry.
  ///
  /// This method only goes through the snapshot of the entry list
  /// at the calling time. And this method allows concurrent modification,
  /// where concurrent modification means caller can add/remove entry in the
  /// [doAction] method.
  void forEach(void doAction(Observer<T> observer)) {
    _isIterating = true;
    var entry = _head;
    while (entry != null && !entry.isConcurrentlyAdding) {
      doAction(entry.observer!);
      entry = entry.next;
    }
    _isIterating = false;
    entry = _head;
    while (entry != null) {
      final next = entry.next;
      if (entry.isConcurrentlyAdding) entry.isConcurrentlyAdding = false;
      if (entry.isConcurrentlyRemoving) _remove(entry);
      entry = next;
    }
  }
}

class _ObserverDoubleLinkedListEntry<T> {
  _ObserverDoubleLinkedListEntry<T>? prev;
  _ObserverDoubleLinkedListEntry<T>? next;
  Observer<T>? observer;
  bool isConcurrentlyAdding = false;
  bool isConcurrentlyRemoving = false;
}
